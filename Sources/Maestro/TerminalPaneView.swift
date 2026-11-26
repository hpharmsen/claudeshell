import AppKit
import MaestroCore
import SwiftTerm

/// One terminal pane: a shell or a Claude session in a project folder.
final class TerminalPaneView: LocalProcessTerminalView {
    private(set) var spec: LaunchSpec
    private(set) var startedAt = Date.distantPast
    /// Set while the process is gone; Enter in this pane then calls it to start a new one.
    var onRestart: (() -> Void)? {
        didSet {
            if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
            keyMonitor = onRestart.flatMap { restart in
                // SwiftTerm sends keys straight to the process, so a dead pane needs its own listener.
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    let isEnter = event.keyCode == 36 || event.keyCode == 76
                    guard isEnter, let self, window?.firstResponder === self else { return event }
                    restart()
                    return nil
                }
            }
        }
    }
    private var keyMonitor: Any?
    /// True once the shell reports its directory (OSC 7); SwiftTerm then resolves relative links itself.
    var reportsDirectory = false
    /// The shell of the same project; a clicked script lands on its prompt.
    weak var shellPane: TerminalPaneView?

    init(spec: LaunchSpec) {
        self.spec = spec
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        TerminalTheme.apply(to: self, kind: spec.kind)
        // A plain click opens a link, as in WezTerm.
        linkHighlightMode = .hover
        // Option composes characters as elsewhere on the Mac (Option+E, E gives é);
        // it stays Meta on keys without text, so Option+Left and Option+Enter keep working.
        optionAsMetaKey = false
        optionAsMetaKeyForFunctionalKeys = true
        // SwiftTerm takes no drops; a dropped file pastes its path, as in Terminal.app.
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                         options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        pasteText(DroppedFiles.pasteText(urls.map(\.path)))
        window?.makeFirstResponder(self)
        return true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Claude prints paths relative to the project folder and reports no directory (OSC 7),
    /// so SwiftTerm would look for them in the folder of the app.
    /// A slash command is no file: it goes to the prompt, without Enter, so it can still be edited.
    /// SwiftTerm refuses to open a file that can run; it goes to the prompt of the shell instead.
    override func requestOpenLink(source: TerminalView, request: TerminalLinkRequest) {
        if !request.isExplicit, let command = spec.slashCommand(request.link) { return send(txt: command) }
        if !request.isExplicit, let shellPane, let command = spec.executableCommand(request.link) {
            shellPane.send(txt: command)
            window?.makeFirstResponder(shellPane)
            return
        }
        let isRelativeToPane = !request.isExplicit && !reportsDirectory
        request.openDefault(isRelativeToPane ? spec.resolvedLink(request.link) : nil)
    }

    /// Starts the process of the spec; a new spec restarts the pane under a new pane id.
    func start(_ newSpec: LaunchSpec? = nil) {
        if let newSpec { spec = newSpec }
        onRestart = nil
        reportsDirectory = false
        startedAt = Date()
        startProcess(executable: spec.executable, args: spec.args, environment: spec.environment,
                     currentDirectory: spec.directory)
    }
}
