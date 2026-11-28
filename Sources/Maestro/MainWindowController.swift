import AppKit
import MaestroCore
import SwiftUI
import UniformTypeIdentifiers

/// The window: tiles bar on top, the project strip below it, then the two panes of the selected project.
/// Also handles every user action.
final class MainWindowController: NSWindowController, NSSplitViewDelegate {
    private static let autosaveName = "MainWindow"

    private let store: ProjectStore
    private let tracker: AttentionTracker
    private let sessions: SessionManager
    private let icons: IconStore
    private let info: ProjectInfoStore
    private let commandKey = CommandKeyState()
    private let splitView = NSSplitView()
    private let slots = [NSView(), NSView()]
    private let hint = NSTextField(labelWithString: "Kies een project in de balk, of zoek er een met Cmd+P.")
    private var strip = NSView()
    /// The split starts below the strip or below the bar; exactly one of the two is active (KTD1).
    private var splitBelowStrip = NSLayoutConstraint()
    private var splitBelowBar = NSLayoutConstraint()
    /// The loop that keeps git state and workflow step of the selected project fresh (KTD9).
    private var loop: Task<Void, Never>?

    init(store: ProjectStore, tracker: AttentionTracker, sessions: SessionManager, icons: IconStore,
         info: ProjectInfoStore) {
        self.store = store
        self.tracker = tracker
        self.sessions = sessions
        self.icons = icons
        self.info = info
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Maestro"
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
        // The project that was in view at the last quit or restart starts again and is shown.
        if let id = store.lastShownID { select(id) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func buildLayout(in window: NSWindow) {
        // Passive, so the strip button in the bar leaves the typing in the terminal pane.
        let bar = PassiveHostingView(rootView: TilesBarView(store: store, tracker: tracker, icons: icons, info: info,
                                                             commandKey: commandKey, actions: self))
        let strip = PassiveHostingView(rootView: ProjectStripView(store: store, info: info, actions: self))
        // The height is fixed by a constraint; the content must not add size constraints of its own.
        strip.sizingOptions = []
        self.strip = strip
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        slots.forEach(splitView.addArrangedSubview)
        hint.textColor = .secondaryLabelColor
        guard let content = window.contentView else { return }
        for view in [bar, strip, splitView, hint] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: content.topAnchor),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: TilesBarView.height),
            strip.topAnchor.constraint(equalTo: bar.bottomAnchor),
            strip.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            strip.heightAnchor.constraint(equalToConstant: ProjectStripView.height),
            splitView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            hint.centerXAnchor.constraint(equalTo: splitView.centerXAnchor),
            hint.centerYAnchor.constraint(equalTo: splitView.centerYAnchor),
        ])
        splitBelowStrip = splitView.topAnchor.constraint(equalTo: strip.bottomAnchor)
        splitBelowBar = splitView.topAnchor.constraint(equalTo: bar.bottomAnchor)
        placeStrip()
    }

    /// The share of the width the shell pane takes, per project; without a saved one the shell gets 1/3 (R3).
    private static func dividerKey(_ id: Project.ID) -> String { "divider.\(id.uuidString)" }

    private func dividerFraction(of id: Project.ID) -> CGFloat {
        let saved = UserDefaults.standard.double(forKey: Self.dividerKey(id))
        return saved > 0 ? saved : 1.0 / 3
    }

    /// Saves the divider of the selected project, only when HP drags it; AppKit names the divider
    /// on layout passes too, and at launch those left the Claude pane 0 px wide.
    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard NSApp.currentEvent?.type == .leftMouseDragged, let id = store.selectedID,
              splitView.bounds.width > 0 else { return }
        UserDefaults.standard.set(slots[0].frame.width / splitView.bounds.width, forKey: Self.dividerKey(id))
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
        NotificationCenter.default.addObserver(self, selector: #selector(appCameToFront),
                                               name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func commandKeyReleased(_ notification: Notification) { commandKey.isDown = false }

    @objc private func appCameToFront(_ notification: Notification) { restartLoop() }

    /// Shows or hides the strip and gives the split its place, in one layout pass without animation (KTD4).
    /// Never touches the focus or the attention tracker, unlike `refresh` and `show` (KTD5).
    private func placeStrip() {
        let isOpen = info.isOpen
        strip.isHidden = !isOpen
        // Off before on: both at once would conflict.
        (isOpen ? splitBelowBar : splitBelowStrip).isActive = false
        (isOpen ? splitBelowStrip : splitBelowBar).isActive = true
        window?.contentView?.layoutSubtreeIfNeeded()
    }

    /// Starts the loop again with a round right away: first everything of the project, then every five seconds
    /// its git state and workflow step. It ends by itself without selection, with a closed strip or in the background.
    private func restartLoop() {
        loop?.cancel()
        loop = Task { [store, info] in
            var isFirstRound = true
            while !Task.isCancelled, let id = store.selectedID,
                  ProjectInfoStore.loopMayRun(selected: id, isOpen: info.isOpen, appInFront: NSApp.isActive) {
                if isFirstRound { await info.refresh(id) } else { await info.poll(id) }
                isFirstRound = false
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    /// Puts the panes of the selected project in the split, or shows the hint.
    private func refresh() {
        // The strip first, so the panes are placed in a split that already has its final height (KTD4).
        placeStrip()
        restartLoop()
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
        if let project, !views.isEmpty {
            splitView.setPosition(splitView.bounds.width * dividerFraction(of: project.id), ofDividerAt: 0)
        }
        window?.title = project?.name ?? "Maestro"
        window?.makeFirstResponder(views.first { $0.spec.kind == .claude })
    }

    // MARK: Actions

    /// Selects a project and starts it when nothing runs yet.
    func select(_ id: Project.ID) {
        if store.status(of: id) == .inactive { store.setStatus(.active, for: id) }
        if store.status(of: id) == .active {
            guard let project = store.project(id), sessions.start(project) else { return }
            // From active to running: the strip opens again and the summary is checked for missed work.
            info.started(id)
        }
        show(id)
    }

    func stop(_ id: Project.ID) {
        let next = successor(of: id)
        stopSessions(of: id)
        if store.selectedID == id { store.select(nil) }
        showOrRefresh(next)
    }

    /// Moves a project out of the bar; a running one is stopped first.
    func deactivate(_ id: Project.ID) {
        let next = successor(of: id)
        if store.status(of: id) == .running { stopSessions(of: id) }
        store.setStatus(.inactive, for: id)
        showOrRefresh(next)
    }

    /// The running project that takes over when the visible project goes away; asked before it leaves the bar.
    private func successor(of id: Project.ID) -> Project.ID? {
        store.selectedID == id ? store.nextRunning(after: id) : nil
    }

    private func showOrRefresh(_ next: Project.ID?) {
        if let next { show(next) } else { refresh() }
    }

    /// The one place where a running project stops; its summary follows in the background.
    private func stopSessions(of id: Project.ID) {
        sessions.stop(id)
        info.stopped(id)
    }

    func remove(_ id: Project.ID) {
        store.remove(id)
        UserDefaults.standard.removeObject(forKey: Self.dividerKey(id))
        icons.forget(id)
        info.forget(id)
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
            if store.setWebsite(website, for: id) { icons.searchAgain(id) } else { warnInvalidWebsite() }
        }
        refresh()
    }

    /// Sets, changes or clears one link of the strip; the app no longer overwrites it (R62).
    func editLink(_ kind: LinkKind, of id: Project.ID) {
        guard let project = store.project(id) else { return }
        let current = project.linkOverrides?[kind] ?? info.info(id).links[kind]?.absoluteString ?? ""
        guard let link = ask("\(kind.rawValue.capitalized)-link van \(project.name)", value: current) else { return }
        if store.setLink(link, kind: kind, for: id) { restartLoop() } else { warnInvalidWebsite() }
    }

    /// Forgets HP's own links, so a cleared link can be found again.
    func findLinksAgain(_ id: Project.ID) {
        store.clearLinkOverrides(for: id)
        restartLoop()
    }

    func refreshSummary(_ id: Project.ID) { info.refreshSummary(id) }

    /// Closes or opens the strip of the selected project (Cmd+I); without selection nothing happens.
    @objc func toggleStrip(_ sender: Any?) {
        info.toggle()
        placeStrip()
        restartLoop()
    }

    private func warnInvalidWebsite() {
        let alert = NSAlert()
        alert.messageText = "Dat is geen geldige website."
        alert.runModal()
    }

    func chooseIcon(_ id: Project.ID) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.directoryURL = store.project(id).map { URL(fileURLWithPath: $0.path) }
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
