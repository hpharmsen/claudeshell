import AppKit
import ClaudeshellCore
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

    init(spec: LaunchSpec) {
        self.spec = spec
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        TerminalTheme.apply(to: self, kind: spec.kind)
        // A plain click opens a link, as in WezTerm.
        linkHighlightMode = .hover
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Starts the process of the spec; a new spec restarts the pane under a new pane id.
    func start(_ newSpec: LaunchSpec? = nil) {
        if let newSpec { spec = newSpec }
        onRestart = nil
        startedAt = Date()
        startProcess(executable: spec.executable, args: spec.args, environment: spec.environment,
                     currentDirectory: spec.directory)
    }
}
