import AppKit
import MaestroCore
import os

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let log = Logger(subsystem: "Maestro", category: "App")

    private let tracker = AttentionTracker()
    private var eventLog: HookEventLog?
    private var eventSource: DispatchSourceFileSystemObject?
    private var sessions: SessionManager?
    private var info: ProjectInfoStore?
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // MAESTRO_SUPPORT points a test run at its own folder instead of the real projects.
        let support = ProcessInfo.processInfo.environment["MAESTRO_SUPPORT"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Maestro")
        let store = ProjectStore(fileURL: support.appendingPathComponent("projects.json"))
        if !store.fileExisted { importWezTermProjects(into: store) }

        let eventLog = HookEventLog(fileURL: support.appendingPathComponent("events"))
        eventLog.reset()
        self.eventLog = eventLog
        let settingsURL = support.appendingPathComponent("hooks.json")
        do {
            try HookSettings.json().write(to: settingsURL, options: .atomic)
        } catch {
            Self.log.error("Could not write the hook settings: \(error)")
        }
        watchEvents(at: eventLog.fileURL)

        let sessions = SessionManager(store: store, tracker: tracker, eventsPath: eventLog.fileURL.path,
                                      settingsPath: settingsURL.path)
        let info = ProjectInfoStore(store: store, supportFolder: support, run: Subprocess.run)
        let windowController = MainWindowController(store: store, tracker: tracker, sessions: sessions,
                                                    icons: IconStore(store: store, support: support), info: info)
        self.sessions = sessions
        self.info = info
        self.windowController = windowController
        NSApp.mainMenu = MainMenu.make(target: windowController)
        windowController.showWindow(nil)
        NSApp.activate()
        // Brings the summaries up to date in the background, also after a quit or crash with running projects.
        info.summariseBar()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        // Quitting and restarting never wait for a summary; a missed one is made at the next start (R59).
        info?.cancelAll()
        sessions?.stopAll()
    }

    /// Quits and opens the app again, for example to run a newly installed version.
    @objc func restart(_ sender: Any?) {
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Opens the app only after this process is gone, so the two never share the events file.
        relaunch.arguments = ["-c", "while kill -0 \"$0\" 2>/dev/null; do sleep 0.1; done; open \"$1\"",
                              String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath]
        do {
            try relaunch.run()
            NSApp.terminate(sender)
        } catch {
            Self.log.error("Could not restart: \(error)")
        }
    }

    /// First start: the WezTerm projects whose folder exists become active tiles (R22).
    private func importWezTermProjects(into store: ProjectStore) {
        let home = NSHomeDirectory()
        // No WezTerm config simply means nothing to import.
        let contents = (try? String(contentsOfFile: home + "/.wezterm.lua", encoding: .utf8)) ?? ""
        for project in WezTermImporter.parse(contents, home: home) {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: project.path, isDirectory: &isDirectory), isDirectory.boolValue {
                store.add(path: project.path, name: project.name)
            }
        }
        // Writes the file even without projects, so the import never runs twice.
        store.save()
    }

    /// Reads new hook lines whenever the events file grows.
    private func watchEvents(at url: URL) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return Self.log.error("Could not watch the events file") }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .extend],
                                                               queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.applyNewEvents() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        eventSource = source
    }

    private func applyNewEvents() {
        // The sound plays for every pane that starts waiting, also for the visible project (R15).
        for event in eventLog?.readNew() ?? [] where tracker.apply(event) {
            NSSound(named: "Glass")?.play()
        }
    }
}
