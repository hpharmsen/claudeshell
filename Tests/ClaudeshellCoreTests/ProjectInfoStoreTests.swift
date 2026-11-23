import Foundation
import os
import Testing
@testable import ClaudeshellCore

// MARK: - Helpers

private let goodText = "De strook toont de links. De samenvatting staat nog open."
private let timedOut = Result<String, SubprocessError>.failure(.timedOut)

/// The JSON that `claude -p --output-format json` prints.
private func claudeJSON(_ result: String) -> String {
    let fields: [String: Any] = ["type": "result", "subtype": "success", "is_error": false, "result": result]
    return String(decoding: try! JSONSerialization.data(withJSONObject: fields), as: UTF8.self)
}

/// Records every call and gives fixed answers; nothing real is started.
private final class RunStub: Sendable {
    typealias Call = (program: String, arguments: [String], directory: URL, input: String?)

    private struct State: Sendable {
        var calls: [Call] = []
        var answer = Result<String, SubprocessError>.success(claudeJSON(goodText))
        var shell = Result<String, SubprocessError>.failure(.failed(exitCode: 1, output: ""))
        var heads: [String: String] = [:]
        var duringClaude: (@Sendable () async -> Void)?
        var running = 0, mostRunning = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// What `claude` answers from now on.
    var answer: Result<String, SubprocessError> {
        get { state.withLock { $0.answer } }
        set { state.withLock { $0.answer = newValue } }
    }

    /// What the login shell answers when it is asked for the path of `claude`.
    var shell: Result<String, SubprocessError> {
        get { state.withLock { $0.shell } }
        set { state.withLock { $0.shell = newValue } }
    }

    /// Runs while a call of `claude` is under way.
    var duringClaude: (@Sendable () async -> Void)? {
        get { state.withLock { $0.duringClaude } }
        set { state.withLock { $0.duringClaude = newValue } }
    }

    var calls: [Call] { state.withLock { $0.calls } }
    var gitCalls: [Call] { calls.filter { $0.program == "/usr/bin/git" } }
    var shellCalls: [Call] { calls.filter { $0.program == "/bin/zsh" } }
    var claudeCalls: [Call] { calls.filter { !["/usr/bin/git", "/bin/zsh"].contains($0.program) } }
    /// The highest number of `claude` calls that ran at the same moment.
    var mostRunning: Int { state.withLock { $0.mostRunning } }
    /// The folder names of the projects `claude` was called for, in order; the branch in the input names the folder.
    var summarised: [String] {
        claudeCalls.compactMap { call in
            call.input?.split(separator: "\n").first { $0.hasPrefix("Branch ") }?.dropFirst(7).prefix { $0 != "," }
        }.map(String.init)
    }

    /// Gives the repository in a folder with this name a new commit.
    func commit(in folder: String) { state.withLock { $0.heads[folder] = UUID().uuidString } }

    var run: ProcessRunner {
        { program, arguments, directory, input, _ in
            self.state.withLock { $0.calls.append((program, arguments, directory, input)) }
            switch program {
            case "/usr/bin/git": return try self.git(arguments, in: directory.lastPathComponent)
            case "/bin/zsh": return try self.shell.get()
            default:
                self.state.withLock {
                    $0.running += 1
                    $0.mostRunning = max($0.mostRunning, $0.running)
                }
                // Gives a second call the chance to start, if the store would allow one.
                await Task.yield()
                await self.duringClaude?()
                self.state.withLock { $0.running -= 1 }
                return try self.answer.get()
            }
        }
    }

    /// Every folder is a repository on a branch named after it, with an origin; all other git commands fail.
    private func git(_ arguments: [String], in folder: String) throws -> String {
        if arguments.contains("status") {
            return "# branch.oid \(state.withLock { $0.heads[folder] } ?? "c0-\(folder)")\n# branch.head \(folder)\n1 .M voorbeeld.txt\n"
        }
        if arguments.first == "remote" { return "git@voorbeeld.nl:team/\(folder).git\n" }
        throw SubprocessError.failed(exitCode: 128, output: "")
    }
}

/// A project store and an info store on temp folders, with a stub instead of real processes.
@MainActor private struct Fixture {
    let root: URL
    let support: URL
    let transcripts: URL
    let stub = RunStub()
    let projects: ProjectStore
    let info: ProjectInfoStore

    /// Without `claudeInstalled` the fixed path of `claude` does not exist, so the store asks the shell.
    init(claudeInstalled: Bool = true) throws {
        // Claude Code names the conversation folder after the real path, and the temp folder is a symlink.
        root = URL(fileURLWithPath: try #require(realpath(try makeTempDir().path, nil).map { pointer in
            defer { free(pointer) }
            return String(cString: pointer)
        }))
        support = root.appendingPathComponent("support")
        transcripts = root.appendingPathComponent("gesprekken")
        let claude = root.appendingPathComponent("claude")
        if claudeInstalled { try Data().write(to: claude) }
        projects = ProjectStore(fileURL: root.appendingPathComponent("projects.json"))
        info = ProjectInfoStore(store: projects, supportFolder: support, run: stub.run, stopDelay: .zero,
                                transcripts: TranscriptReader(root: transcripts), fixedClaudePath: claude.path)
    }

    /// Adds a project with its own folder; the folder name is the project name.
    func add(_ name: String) throws -> Project {
        let folder = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return projects.add(path: folder.path)
    }

    /// Writes a file in the folder of a project, creating its folder.
    func document(_ path: String, _ text: String, in project: Project) throws {
        let url = URL(fileURLWithPath: project.path).appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    /// Gives a project a conversation of one made-up turn.
    func converse(in project: Project) throws {
        let folder = transcripts.appendingPathComponent(TranscriptReader.folderName(for: root.appendingPathComponent(project.name).path))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let lines = """
            {"type":"user","message":{"role":"user","content":"zet de links in de strook"},"uuid":"id-1","timestamp":"2026-01-01T10:01:00.000Z","entrypoint":"cli"}
            {"type":"assistant","message":{"model":"claude-voorbeeld-1","role":"assistant","content":[{"type":"text","text":"De links staan in de strook."}]},"uuid":"id-2","timestamp":"2026-01-01T10:02:00.000Z","entrypoint":"cli"}

            """
        try Data(lines.utf8).write(to: folder.appendingPathComponent("a.jsonl"))
    }

    func stored(_ project: Project) -> ProjectSummary? { ProjectSummary.read(for: project.id, in: support) }
    func storedBytes(_ project: Project) -> Data? { try? Data(contentsOf: ProjectSummary.fileURL(for: project.id, in: support)) }
}

// MARK: - Open and closed

@MainActor @Test func closingTheStripCountsForThatProjectOnly() throws {
    let fixture = try Fixture()
    let a = try fixture.add("a"), b = try fixture.add("b")
    fixture.projects.select(a.id)
    #expect(fixture.info.isOpen)
    fixture.info.toggle()
    #expect(!fixture.info.isOpen)
    fixture.projects.select(b.id)
    #expect(fixture.info.isOpen)
    fixture.projects.select(a.id)
    #expect(!fixture.info.isOpen)
}

@MainActor @Test func toggleOpensAClosedStripAgain() throws {
    let fixture = try Fixture()
    fixture.projects.select(try fixture.add("a").id)
    fixture.info.toggle()
    fixture.info.toggle()
    #expect(fixture.info.isOpen)
}

@MainActor @Test func startedProjectHasAnOpenStripAgain() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a")
    fixture.projects.select(a.id)
    fixture.info.toggle()
    let work = fixture.info.started(a.id)
    // The strip is open before the summary is made.
    #expect(fixture.info.isOpen)
    await work.value
    #expect(fixture.info.isOpen)
}

@MainActor @Test func withoutSelectionTheStripIsClosedAndToggleDoesNothing() throws {
    let fixture = try Fixture()
    let a = try fixture.add("a")
    #expect(!fixture.info.isOpen)
    fixture.info.toggle()
    #expect(!fixture.info.isOpen)
    fixture.projects.select(a.id)
    #expect(fixture.info.isOpen)
}

/// Every bit of `combination` is one of the three conditions; only 7 has them all.
@MainActor @Test(arguments: 0..<8)
func loopRunsOnlyWithSelectionOpenStripAndAppInFront(combination: Int) {
    let selected = combination & 1 != 0, isOpen = combination & 2 != 0, appInFront = combination & 4 != 0
    let mayRun = ProjectInfoStore.loopMayRun(selected: selected ? UUID() : nil, isOpen: isOpen, appInFront: appInFront)
    #expect(mayRun == (selected && isOpen && appInFront))
}

// MARK: - Refresh and poll

private let openHandoff = "| Taak | Status |\n|---|---|\n| De strook bouwen | todo |\n"

@MainActor @Test func refreshSetsLinksGitStateStepAndStoredSummary() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a")
    fixture.projects.setWebsite("a.voorbeeld.nl", for: a.id)
    try fixture.document("docs/handoff/README.md", openHandoff, in: a)
    let summary = ProjectSummary(text: goodText, date: Date(timeIntervalSince1970: 1_750_000_000), fingerprint: SummaryFingerprint())
    summary.write(for: a.id, in: fixture.support)
    await fixture.info.refresh(a.id)
    let info = fixture.info.info(a.id)
    #expect(info.links[.live] == URL(string: "https://a.voorbeeld.nl"))
    #expect(info.links[.git] == URL(string: "https://voorbeeld.nl/team/a"))
    #expect(info.git == GitState(branch: "a", changedFiles: 1, unpushed: nil, head: "c0-a"))
    #expect(info.step == WorkflowStep(kind: .handoff, document: "README.md"))
    #expect(info.summary == summary)
    #expect(!info.summaryFailed)
    #expect(fixture.stub.claudeCalls.isEmpty)
}

@MainActor @Test func refreshForAnotherProjectThanTheSelectedOneLeavesTheSelectedOneAlone() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a"), b = try fixture.add("b")
    fixture.projects.select(b.id)
    await fixture.info.refresh(a.id)
    #expect(fixture.info.info(a.id).git?.branch == "a")
    #expect(fixture.info.info(a.id).links[.git] == URL(string: "https://voorbeeld.nl/team/a"))
    #expect(fixture.info.info(b.id) == ProjectInfo())
    #expect(fixture.stub.gitCalls.allSatisfy { $0.directory.lastPathComponent == "a" })
}

@MainActor @Test func pollFetchesOnlyGitStateAndStep() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a")
    try fixture.document("docs/handoff/README.md", openHandoff, in: a)
    ProjectSummary(text: goodText, date: Date(), fingerprint: SummaryFingerprint()).write(for: a.id, in: fixture.support)
    await fixture.info.poll(a.id)
    let info = fixture.info.info(a.id)
    #expect(info.git?.head == "c0-a")
    #expect(info.step?.kind == .handoff)
    #expect(info.links.isEmpty)
    #expect(info.summary == nil)
    #expect(!fixture.stub.gitCalls.contains { $0.arguments.first == "remote" })
}

@MainActor @Test func pollFollowsANewCommit() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a")
    await fixture.info.refresh(a.id)
    fixture.stub.commit(in: "a")
    await fixture.info.poll(a.id)
    #expect(fixture.info.info(a.id).git?.head != "c0-a")
    #expect(fixture.info.info(a.id).links[.git] != nil)
}

@MainActor @Test func refreshAndPollForAnUnknownProjectDoNothing() async throws {
    let fixture = try Fixture()
    let unknown = UUID()
    await fixture.info.refresh(unknown)
    await fixture.info.poll(unknown)
    #expect(fixture.info.info(unknown) == ProjectInfo())
    #expect(fixture.stub.calls.isEmpty)
}

@MainActor @Test func resultOfACancelledPollIsThrownAway() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a")
    let info = fixture.info
    let round = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        await info.poll(a.id)
    }
    await round.value
    #expect(info.info(a.id) == ProjectInfo())
}

// MARK: - The four entry points

@MainActor @Test func stoppedProjectWithANewMessageGetsAStoredSummary() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a")
    try fixture.converse(in: a)
    await fixture.info.stopped(a.id).value
    let stored = try #require(fixture.stored(a))
    #expect(stored.text == goodText)
    #expect(stored.fingerprint.lastMessageUUID == "id-2")
    #expect(fixture.info.info(a.id).summary == stored)
    #expect(!fixture.info.info(a.id).summaryFailed)
    #expect(fixture.stub.claudeCalls.first?.input?.contains("zet de links in de strook") == true)
}

@MainActor @Test func stoppedProjectWithoutNewsMakesNoCall() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a")
    await fixture.info.stopped(a.id).value
    let bytes = try #require(fixture.storedBytes(a))
    await fixture.info.stopped(a.id).value
    #expect(fixture.stub.claudeCalls.count == 1)
    #expect(fixture.storedBytes(a) == bytes)
    #expect(!fixture.info.info(a.id).summaryFailed)
}

@MainActor @Test func startedProjectWithANewCommitGetsANewSummary() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a")
    await fixture.info.started(a.id).value
    await fixture.info.started(a.id).value
    #expect(fixture.stub.claudeCalls.count == 1)
    fixture.stub.commit(in: "a")
    fixture.stub.answer = .success(claudeJSON("De strook is klaar."))
    await fixture.info.started(a.id).value
    #expect(fixture.stub.claudeCalls.count == 2)
    #expect(fixture.info.info(a.id).summary?.text == "De strook is klaar.")
}

@MainActor @Test func refreshButtonCallsClaudeWithTheSameFingerprint() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a")
    await fixture.info.stopped(a.id).value
    await fixture.info.refreshSummary(a.id).value
    #expect(fixture.stub.claudeCalls.count == 2)
}

@MainActor @Test func entryPointsForAnUnknownProjectMakeNoCall() async throws {
    let fixture = try Fixture()
    let unknown = UUID()
    await fixture.info.stopped(unknown).value
    await fixture.info.started(unknown).value
    await fixture.info.refreshSummary(unknown).value
    #expect(fixture.stub.calls.isEmpty)
    #expect(fixture.info.queue == SummaryQueue())
}

@MainActor @Test func busyFlagIsOnWhileTheSummaryIsMadeAndOffAfterwards() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a"), b = try fixture.add("b")
    let info = fixture.info
    let seen = OSAllocatedUnfairLock(initialState: [Bool]())
    fixture.stub.duringClaude = {
        let flags = await MainActor.run { [info.isSummarising(a.id), info.isSummarising(b.id)] }
        seen.withLock { $0 = flags }
    }
    #expect(!info.isSummarising(a.id))
    await info.stopped(a.id).value
    #expect(seen.withLock { $0 } == [true, false])
    #expect(!info.isSummarising(a.id))
}

@MainActor @Test func failedAttemptSetsTheFlagAndKeepsTheOldSummaryUntilTheNextSuccess() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a")
    await fixture.info.stopped(a.id).value
    let old = try #require(fixture.info.info(a.id).summary)
    fixture.stub.answer = timedOut
    await fixture.info.refreshSummary(a.id).value
    #expect(fixture.info.info(a.id).summaryFailed)
    #expect(fixture.info.info(a.id).summary == old)
    #expect(fixture.stored(a) == old)
    fixture.stub.answer = .success(claudeJSON("De strook is klaar."))
    await fixture.info.refreshSummary(a.id).value
    #expect(!fixture.info.info(a.id).summaryFailed)
    #expect(fixture.info.info(a.id).summary?.text == "De strook is klaar.")
}

@MainActor @Test func attemptWithNothingToDoTakesTheFailedFlagAway() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a")
    await fixture.info.stopped(a.id).value
    fixture.stub.answer = timedOut
    await fixture.info.refreshSummary(a.id).value
    #expect(fixture.info.info(a.id).summaryFailed)
    await fixture.info.stopped(a.id).value
    #expect(!fixture.info.info(a.id).summaryFailed)
    #expect(fixture.stub.claudeCalls.count == 2)
}

@MainActor @Test func roundAtStartQueuesTheBarProjectsAndNotTheInactiveOnes() async throws {
    let fixture = try Fixture()
    let c = try fixture.add("c"), a = try fixture.add("a"), b = try fixture.add("b"), d = try fixture.add("d")
    fixture.projects.setStatus(.inactive, for: b.id)
    fixture.projects.setStatus(.running, for: c.id)
    let round = fixture.info.summariseBar()
    #expect(fixture.info.queue.waiting.map(\.id) == [a.id, c.id, d.id])
    #expect(fixture.info.queue.waiting.allSatisfy { $0.inRound && !$0.force })
    await round.value
    #expect(fixture.stub.summarised == ["a", "c", "d"])
    #expect(fixture.stored(b) == nil)
    #expect(fixture.info.queue == SummaryQueue())
}

@MainActor @Test func roundAtStartStopsAtTheFirstFailure() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a"), b = try fixture.add("b"), c = try fixture.add("c")
    fixture.stub.answer = timedOut
    await fixture.info.summariseBar().value
    #expect(fixture.stub.claudeCalls.count == 1)
    #expect(fixture.info.info(a.id).summaryFailed)
    #expect(!fixture.info.info(b.id).summaryFailed)
    #expect(!fixture.info.info(c.id).summaryFailed)
    #expect(fixture.info.queue == SummaryQueue())
}

@MainActor @Test func failedRoundAtStartLeavesAStartedProjectInTheQueue() async throws {
    let fixture = try Fixture()
    _ = try fixture.add("a")
    _ = try fixture.add("b")
    let c = try fixture.add("c")
    fixture.stub.answer = timedOut
    let round = fixture.info.summariseBar()
    // Project c is started while the round waits: it goes to the front and no longer belongs to the round.
    fixture.info.started(c.id)
    await round.value
    #expect(fixture.stub.summarised == ["c", "a"])
    #expect(fixture.info.info(c.id).summaryFailed)
}

@MainActor @Test func failureAfterAStopDoesNotStopTheRestOfTheQueue() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a"), b = try fixture.add("b")
    fixture.stub.answer = timedOut
    let first = fixture.info.stopped(a.id), second = fixture.info.stopped(b.id)
    await first.value
    await second.value
    #expect(fixture.stub.claudeCalls.count == 2)
    #expect(fixture.info.info(a.id).summaryFailed)
    #expect(fixture.info.info(b.id).summaryFailed)
}

@MainActor @Test func startedProjectAndRefreshButtonGoToTheFront() async throws {
    let fixture = try Fixture()
    _ = try fixture.add("a")
    let b = try fixture.add("b"), c = try fixture.add("c")
    let round = fixture.info.summariseBar()
    fixture.info.started(b.id)
    fixture.info.refreshSummary(c.id)
    #expect(fixture.info.queue.waiting.map(\.id).first == c.id)
    #expect(fixture.info.queue.waiting.first?.force == true)
    await round.value
    #expect(fixture.stub.summarised == ["c", "b", "a"])
}

@MainActor @Test func onlyOneSummaryIsMadeAtATime() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a"), b = try fixture.add("b"), c = try fixture.add("c")
    let work = [fixture.info.refreshSummary(a.id), fixture.info.refreshSummary(b.id), fixture.info.stopped(c.id)]
    for task in work { await task.value }
    #expect(fixture.stub.claudeCalls.count == 3)
    #expect(fixture.stub.mostRunning == 1)
}

@MainActor @Test func requestForTheProjectThatIsBeingSummarisedGivesOneMoreRound() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a")
    let info = fixture.info
    fixture.stub.duringClaude = {
        await MainActor.run {
            // Only the first call asks again, twice; a second round that asked again would never end.
            guard info.info(a.id).summary == nil else { return }
            info.refreshSummary(a.id)
            info.refreshSummary(a.id)
        }
    }
    await info.stopped(a.id).value
    #expect(fixture.stub.claudeCalls.count == 2)
    #expect(info.queue == SummaryQueue())
}

// MARK: - Forgetting and cancelling

@MainActor @Test func forgetDuringTheCallLeavesNoFileAndNoData() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a"), b = try fixture.add("b")
    let info = fixture.info, projects = fixture.projects
    fixture.stub.duringClaude = {
        await MainActor.run {
            projects.remove(a.id)
            info.forget(a.id)
        }
    }
    let first = info.stopped(a.id), second = info.stopped(b.id)
    await first.value
    await second.value
    #expect(!FileManager.default.fileExists(atPath: ProjectSummary.fileURL(for: a.id, in: fixture.support).path))
    #expect(info.info(a.id) == ProjectInfo())
    #expect(!info.isSummarising(a.id))
    // The queue goes on with the next project.
    #expect(fixture.stored(b) != nil)
}

@MainActor @Test func forgetDeletesTheFileTheDataThePlaceInTheQueueAndTheClosedStrip() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a"), b = try fixture.add("b")
    await fixture.info.stopped(a.id).value
    await fixture.info.refresh(a.id)
    fixture.projects.select(a.id)
    fixture.info.toggle()
    let round = fixture.info.summariseBar()
    fixture.info.refreshSummary(a.id)
    fixture.info.forget(a.id)
    #expect(fixture.info.queue.waiting.map(\.id) == [b.id])
    #expect(fixture.info.info(a.id) == ProjectInfo())
    #expect(fixture.storedBytes(a) == nil)
    #expect(fixture.info.isOpen)
    await round.value
    #expect(fixture.stub.summarised == ["a", "b"])
}

@MainActor @Test func cancelAllDropsTheQueueAndTheResultOfTheRunningCall() async throws {
    let fixture = try Fixture()
    let a = try fixture.add("a"), b = try fixture.add("b")
    let info = fixture.info
    fixture.stub.duringClaude = { await MainActor.run { info.cancelAll() } }
    await info.summariseBar().value
    #expect(fixture.stub.claudeCalls.count == 1)
    #expect(info.info(a.id) == ProjectInfo())
    #expect(info.queue == SummaryQueue())
    #expect(!info.isSummarising(a.id))
    // After the cancel the store starts nothing new.
    await info.started(b.id).value
    await info.stopped(b.id).value
    await info.summariseBar().value
    #expect(fixture.stub.claudeCalls.count == 1)
}

// MARK: - The path of claude

@MainActor @Test func pathOfClaudeIsDeterminedOnceForThreeSummaries() async throws {
    let fixture = try Fixture(claudeInstalled: false)
    fixture.stub.shell = .success("Voorbeeld van een welkomstregel\n/voorbeeld/elders/claude\n")
    let a = try fixture.add("a"), b = try fixture.add("b")
    #expect(fixture.stub.shellCalls.isEmpty)
    await fixture.info.stopped(a.id).value
    await fixture.info.stopped(b.id).value
    await fixture.info.refreshSummary(a.id).value
    #expect(fixture.stub.shellCalls.count == 1)
    #expect(fixture.stub.claudeCalls.map(\.program) == Array(repeating: "/voorbeeld/elders/claude", count: 3))
}

@MainActor @Test func installedClaudeNeedsNoShell() async throws {
    let fixture = try Fixture()
    await fixture.info.stopped(try fixture.add("a").id).value
    #expect(fixture.stub.shellCalls.isEmpty)
    #expect(fixture.stub.claudeCalls.first?.program == fixture.root.appendingPathComponent("claude").path)
}

@MainActor @Test func withoutAPathOfClaudeTheAttemptFailsAndWritesNoFile() async throws {
    let fixture = try Fixture(claudeInstalled: false)
    let a = try fixture.add("a")
    await fixture.info.stopped(a.id).value
    #expect(fixture.info.info(a.id).summaryFailed)
    #expect(fixture.storedBytes(a) == nil)
    #expect(fixture.stub.claudeCalls.isEmpty)
}

@MainActor @Test func pathThatWasNotFoundIsAskedAgainAtTheNextSummary() async throws {
    let fixture = try Fixture(claudeInstalled: false)
    let a = try fixture.add("a")
    await fixture.info.stopped(a.id).value
    fixture.stub.shell = .success("/voorbeeld/elders/claude\n")
    await fixture.info.stopped(a.id).value
    #expect(fixture.stub.shellCalls.count == 2)
    #expect(!fixture.info.info(a.id).summaryFailed)
    #expect(fixture.stored(a)?.text == goodText)
}
