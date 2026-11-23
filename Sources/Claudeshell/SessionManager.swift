import AppKit
import ClaudeshellCore
import SwiftTerm

/// Owns the terminal panes of every running project.
@MainActor final class SessionManager: LocalProcessTerminalViewDelegate {
    private let store: ProjectStore
    private let tracker: AttentionTracker
    private let eventsPath: String
    private let settingsPath: String
    private var panes: [Project.ID: [TerminalPaneView]] = [:]

    init(store: ProjectStore, tracker: AttentionTracker, eventsPath: String, settingsPath: String) {
        self.store = store
        self.tracker = tracker
        self.eventsPath = eventsPath
        self.settingsPath = settingsPath
    }

    func panes(of id: Project.ID) -> [TerminalPaneView] { panes[id] ?? [] }

    /// Starts the shell and Claude of a project; false when its folder is gone.
    func start(_ project: Project) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: project.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            let alert = NSAlert()
            alert.messageText = "De folder van \(project.name) bestaat niet"
            alert.informativeText = project.path
            alert.runModal()
            return false
        }
        panes[project.id] = [PaneKind.shell, .claude].map { kind in
            let view = TerminalPaneView(spec: spec(kind, project))
            view.processDelegate = self
            launch(view, in: project.id)
            return view
        }
        store.setStatus(.running, for: project.id)
        return true
    }

    /// Stops both sessions of a project and makes it active.
    func stop(_ id: Project.ID) {
        for view in panes.removeValue(forKey: id) ?? [] {
            tracker.unregister(view.spec.pane)
            guard view.process.running else { continue }
            let pid = view.process.shellPid
            // SIGHUP makes zsh clean up its own jobs; SIGKILL is the safety net.
            kill(pid, SIGHUP)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if view.process.running { kill(pid, SIGKILL) }
            }
        }
        store.setStatus(.active, for: id)
    }

    /// Stops every session when the app quits; blocks briefly so the processes can hang up.
    func stopAll() {
        let pids = panes.values.joined().filter(\.process.running).map(\.process.shellPid)
        panes.removeAll()
        pids.forEach { kill($0, SIGHUP) }
        guard !pids.isEmpty else { return }
        usleep(500_000)
        pids.forEach { kill($0, SIGKILL) }
    }

    private func spec(_ kind: PaneKind, _ project: Project) -> LaunchSpec {
        LaunchSpec(kind: kind, projectPath: project.path, eventsPath: eventsPath, settingsPath: settingsPath)
    }

    private func launch(_ view: TerminalPaneView, in project: Project.ID, spec: LaunchSpec? = nil) {
        view.start(spec)
        tracker.register(view.spec.pane, kind: view.spec.kind, project: project)
    }

    // MARK: LocalProcessTerminalViewDelegate

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        // A pane that is no longer listed was stopped on purpose.
        guard let view = source as? TerminalPaneView,
              let id = panes.first(where: { $0.value.contains { $0 === view } })?.key else { return }
        tracker.unregister(view.spec.pane)
        let kind = view.spec.kind
        let restart = { [weak self, weak view] in
            guard let self, let view, let project = store.project(id), panes(of: id).contains(where: { $0 === view })
            else { return }
            launch(view, in: id, spec: spec(kind, project))
        }
        // A shell that ends gets a successor; Claude, and anything that fails right away, waits for Enter
        // so its last output stays readable.
        if kind == .shell, Date().timeIntervalSince(view.startedAt) >= 2 {
            restart()
        } else {
            let name = kind == .claude ? "Claude" : "De shell"
            view.feed(text: "\r\n[\(name) is gestopt. Druk op Enter om opnieuw te starten.]\r\n")
            view.onRestart = restart
        }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        (source as? TerminalPaneView)?.reportsDirectory = directory != nil
    }
}
