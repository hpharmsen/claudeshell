import Foundation
import Observation

/// What the strip shows of one project.
public struct ProjectInfo: Equatable, Sendable {
    public var links: [LinkKind: URL] = [:]
    public var git: GitState?
    public var step: WorkflowStep?
    public var summary: ProjectSummary?
    /// Whether the last attempt to make a summary failed.
    public var summaryFailed = false
}

/// The memory of the strip: the data per project, open or closed, and the summaries at the right moments.
@MainActor @Observable public final class ProjectInfoStore {
    private var infos: [Project.ID: ProjectInfo] = [:]
    /// The projects whose strip HP closed; not stored, so every start of the app opens them all.
    private var closed: Set<Project.ID> = []
    /// The projects that wait for a summary and the one whose summary is being made.
    public private(set) var queue = SummaryQueue()

    private let store: ProjectStore
    private let supportFolder: URL
    private let run: ProcessRunner
    private let stopDelay: Duration
    private let transcripts: TranscriptReader
    private let fixedClaudePath: String
    /// Made at the first summary, when the path of `claude` is known.
    @ObservationIgnored private var writer: SummaryWriter?
    /// The task that empties the queue, while there is one.
    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var isCancelled = false

    /// `stopDelay` is the wait after a stop, `fixedClaudePath` where `claude` is expected before the shell is asked.
    public init(store: ProjectStore, supportFolder: URL, run: @escaping ProcessRunner, stopDelay: Duration = .seconds(2),
                transcripts: TranscriptReader = TranscriptReader(),
                fixedClaudePath: String = SummaryWriter.defaultClaudePath) {
        self.store = store
        self.supportFolder = supportFolder
        self.run = run
        self.stopDelay = stopDelay
        self.transcripts = transcripts
        self.fixedClaudePath = fixedClaudePath
    }

    // MARK: Data per project

    /// The data of a project; empty for a project that was never refreshed.
    public func info(_ id: Project.ID) -> ProjectInfo { infos[id] ?? ProjectInfo() }

    /// Whether the summary of a project is being made right now.
    public func isSummarising(_ id: Project.ID) -> Bool { queue.current?.id == id }

    /// Loads the stored summary and fetches links, git state and workflow step off the main actor.
    public func refresh(_ id: Project.ID) async {
        guard let project = store.project(id) else { return }
        infos[id, default: ProjectInfo()].summary = ProjectSummary.read(for: id, in: supportFolder)
        async let links = ProjectLinks.resolve(project, run: run)
        await poll(id)
        let found = await links
        guard isCurrent(id) else { return }
        infos[id, default: ProjectInfo()].links = found
    }

    /// Fetches git state and workflow step off the main actor; the result of a cancelled round is thrown away.
    public func poll(_ id: Project.ID) async {
        guard let project = store.project(id) else { return }
        let folder = URL(fileURLWithPath: project.path)
        async let git = GitState.fetch(in: folder, run: run)
        async let step = WorkflowStep.detect(in: folder, run: run)
        let found = await (git: git, step: step)
        guard isCurrent(id) else { return }
        infos[id, default: ProjectInfo()].git = found.git
        infos[id, default: ProjectInfo()].step = found.step
    }

    /// Whether a result that was awaited may still be stored: the task runs on and the project still exists.
    private func isCurrent(_ id: Project.ID) -> Bool { !Task.isCancelled && store.project(id) != nil }

    // MARK: Open and closed

    /// Whether the strip shows: a project is selected and HP did not close its strip.
    public var isOpen: Bool { store.selectedID.map { !closed.contains($0) } ?? false }

    /// Closes or opens the strip of the selected project; without selection nothing happens.
    public func toggle() {
        guard let id = store.selectedID else { return }
        if closed.remove(id) == nil { closed.insert(id) }
    }

    /// Whether the loop that polls git state and workflow step may run.
    public nonisolated static func loopMayRun(selected: Project.ID?, isOpen: Bool, appInFront: Bool) -> Bool {
        selected != nil && isOpen && appInFront
    }

    // MARK: Summaries

    /// A project went from running to active: after the wait its summary is brought up to date.
    @discardableResult public func stopped(_ id: Project.ID) -> Task<Void, Never> {
        Task {
            // The stopped Claude may still write in the conversation file for a moment.
            try? await Task.sleep(for: stopDelay)
            await request(id).value
        }
    }

    /// A project went from active to running: its strip opens and its summary goes to the front of the queue.
    @discardableResult public func started(_ id: Project.ID) -> Task<Void, Never> {
        closed.remove(id)
        return request(id, front: true)
    }

    /// The refresh button: a new summary at the front of the queue, whatever the fingerprint says.
    @discardableResult public func refreshSummary(_ id: Project.ID) -> Task<Void, Never> {
        request(id, force: true, front: true)
    }

    /// The round at the start of the app over the projects in the bar; it stops at the first failure.
    @discardableResult public func summariseBar() -> Task<Void, Never> {
        if !isCancelled { store.barProjects.forEach { queue.add($0.id, inRound: true) } }
        return process()
    }

    /// Deletes the stored summary of a removed project, its data and its place in the queue.
    public func forget(_ id: Project.ID) {
        ProjectSummary.delete(for: id, in: supportFolder)
        infos[id] = nil
        closed.remove(id)
        queue.remove(id)
    }

    /// Breaks off the running call and drops the queue without waiting; after this the store starts no new summary.
    public func cancelAll() {
        isCancelled = true
        worker?.cancel()
        queue = SummaryQueue()
    }

    /// Queues a project that exists; the returned task ends when the queue is empty.
    private func request(_ id: Project.ID, force: Bool = false, front: Bool = false) -> Task<Void, Never> {
        if !isCancelled, store.project(id) != nil { queue.add(id, force: force, front: front) }
        return process()
    }

    /// The task that makes the queued summaries one at a time; requests that come in meanwhile join the same task.
    private func process() -> Task<Void, Never> {
        if let worker { return worker }
        let task = Task {
            while let request = queue.next() {
                await summarise(request)
                // `cancelAll` already dropped the queue, and the store stays as it was.
                guard !Task.isCancelled else { return }
                queue.finish()
            }
            worker = nil
        }
        worker = task
        return task
    }

    /// Has one summary made and stores the outcome under its project.
    private func summarise(_ request: SummaryQueue.Request) async {
        let id = request.id
        guard let project = store.project(id) else { return }
        if writer == nil {
            writer = await SummaryWriter.claudePath(run: run, fixedPath: fixedClaudePath).map {
                SummaryWriter(supportFolder: supportFolder, claudePath: $0, run: run, transcripts: transcripts)
            }
        }
        // Without a path of `claude` the attempt fails; the next attempt looks for it again.
        let outcome = await writer?.update(project, force: request.force) ?? .failed
        guard !Task.isCancelled else { return }
        // HP removed the project while the call ran, and the call may just have written its file.
        guard store.project(id) != nil else { return forget(id) }
        if case .updated(let summary) = outcome { infos[id, default: ProjectInfo()].summary = summary }
        infos[id, default: ProjectInfo()].summaryFailed = outcome == .failed
        if outcome == .failed, request.inRound { queue.dropRound() }
    }
}
