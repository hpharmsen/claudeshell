import AppKit
import ClaudeshellCore
import SwiftUI
import UniformTypeIdentifiers

/// The window: tiles bar on top, the two panes of the selected project below. Also handles every user action.
final class MainWindowController: NSWindowController {
    private static let autosaveName = "MainWindow"
    private static let splitAutosaveName = "MainSplit"

    private let store: ProjectStore
    private let tracker: AttentionTracker
    private let sessions: SessionManager
    private let icons: IconStore
    private let commandKey = CommandKeyState()
    private let splitView = NSSplitView()
    private let slots = [NSView(), NSView()]
    private let hint = NSTextField(labelWithString: "Kies een project in de balk, of zoek er een met Cmd+P.")

    init(store: ProjectStore, tracker: AttentionTracker, sessions: SessionManager, icons: IconStore) {
        self.store = store
        self.tracker = tracker
        self.sessions = sessions
        self.icons = icons
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Claudeshell"
        window.minSize = NSSize(width: 480, height: 240)
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = TerminalTheme.background
        super.init(window: window)
        // Without a saved frame: 3/4 of the visible screen, centered (R1).
        if !window.setFrameUsingName(Self.autosaveName), let screen = NSScreen.main {
            window.setFrame(startFrame(in: screen.visibleFrame), display: false)
        }
        window.setFrameAutosaveName(Self.autosaveName)
        buildLayout(in: window)
        trackCommandKey()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func buildLayout(in window: NSWindow) {
        let bar = NSHostingView(rootView: TilesBarView(store: store, tracker: tracker, icons: icons, commandKey: commandKey,
                                                        actions: self))
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        slots.forEach(splitView.addArrangedSubview)
        hint.textColor = .secondaryLabelColor
        guard let content = window.contentView else { return }
        for view in [bar, splitView, hint] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: content.topAnchor),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: TilesBarView.height),
            splitView.topAnchor.constraint(equalTo: bar.bottomAnchor),
            splitView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            hint.centerXAnchor.constraint(equalTo: splitView.centerXAnchor),
            hint.centerYAnchor.constraint(equalTo: splitView.centerYAnchor),
        ])
        content.layoutSubtreeIfNeeded()
        // Without a saved divider position the shell gets 1/3 (R3); the autosave name restores a saved one.
        splitView.setPosition(splitView.bounds.width / 3, ofDividerAt: 0)
        splitView.autosaveName = Self.splitAutosaveName
    }

    /// Follows Cmd with a local monitor, which also sees the key when a terminal pane has the focus (KTD14).
    private func trackCommandKey() {
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [commandKey] event in
            commandKey.isDown = event.modifierFlags.contains(.command)
            return event
        }
        // Cmd+Tab releases the key in another app, so no event tells us.
        NotificationCenter.default.addObserver(self, selector: #selector(commandKeyReleased),
                                               name: NSApplication.didResignActiveNotification, object: nil)
    }

    @objc private func commandKeyReleased(_ notification: Notification) { commandKey.isDown = false }

    /// Puts the panes of the selected project in the split, or shows the hint.
    private func refresh() {
        let project = store.selectedID.flatMap(store.project)
        let views = project.map { sessions.panes(of: $0.id) } ?? []
        for (index, slot) in slots.enumerated() {
            slot.subviews.forEach { $0.removeFromSuperview() }
            guard index < views.count else { continue }
            views[index].frame = slot.bounds
            views[index].autoresizingMask = [.width, .height]
            slot.addSubview(views[index])
        }
        splitView.isHidden = views.isEmpty
        hint.isHidden = !views.isEmpty
        window?.title = project?.name ?? "Claudeshell"
        window?.makeFirstResponder(views.first { $0.spec.kind == .claude })
    }

    // MARK: Actions

    /// Selects a project and starts it when nothing runs yet.
    func select(_ id: Project.ID) {
        if store.status(of: id) == .inactive { store.setStatus(.active, for: id) }
        if store.status(of: id) == .active {
            guard let project = store.project(id), sessions.start(project) else { return }
        }
        show(id)
    }

    func stop(_ id: Project.ID) {
        sessions.stop(id)
        if store.selectedID == id { store.select(nil) }
        refresh()
    }

    /// Moves a project out of the bar; a running one is stopped first.
    func deactivate(_ id: Project.ID) {
        if store.status(of: id) == .running { sessions.stop(id) }
        store.setStatus(.inactive, for: id)
        refresh()
    }

    func remove(_ id: Project.ID) {
        store.remove(id)
        icons.forget(id)
        refresh()
    }

    func rename(_ id: Project.ID) {
        guard let project = store.project(id) else { return }
        if let name = ask("Naam wijzigen", value: project.name) { store.rename(id, to: name) }
        refresh()
    }

    /// Sets the website whose favicon is the icon; an accepted one starts a search round.
    func editWebsite(_ id: Project.ID) {
        guard let project = store.project(id) else { return }
        if let website = ask("Website van \(project.name)", value: project.website ?? "") {
            if store.setWebsite(website, for: id) {
                icons.searchAgain(id)
            } else {
                let alert = NSAlert()
                alert.messageText = "Dat is geen geldige website."
                alert.runModal()
            }
        }
        refresh()
    }

    func chooseIcon(_ id: Project.ID) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.prompt = "Kies"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        icons.setCustom(imageAt: url, for: id)
    }

    func addProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Voeg toe"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // The folder of a running project selects that project.
        let project = store.add(path: url.path)
        if store.status(of: project.id) == .running { show(project.id) }
        icons.search(project.id)
    }

    @objc func selectTile(_ sender: NSMenuItem) {
        let bar = store.barProjects
        if sender.tag < bar.count { select(bar[sender.tag].id) }
    }

    @objc func jumpToWaiting(_ sender: Any?) {
        if let id = tracker.nextWaiting(in: store.barProjects.map(\.id), after: store.selectedID) { select(id) }
    }

    @objc func showQuickOpen(_ sender: Any?) {
        guard let window, window.attachedSheet == nil else { return }
        QuickOpenPanel.present(on: window, projects: store.barProjects + store.inactiveProjects) { [weak self] in self?.select($0) }
    }

    /// Makes a running project the visible one. Leaving the previous one clears its waiting state, and so
    /// does selecting the project that is already visible: HP has seen it (R13).
    private func show(_ id: Project.ID) {
        if let previous = store.selectedID { tracker.leave(previous) }
        store.select(id)
        refresh()
    }

    /// Asks for one line of text; nil when HP cancels.
    private func ask(_ title: String, value: String) -> String? {
        let field = NSTextField(string: value)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        let alert = NSAlert()
        alert.messageText = title
        alert.accessoryView = field
        alert.addButton(withTitle: "Bewaar")
        alert.addButton(withTitle: "Annuleer")
        alert.window.initialFirstResponder = field
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }
}
