import Foundation
import Observation

/// Tracks the attention state of every registered pane and aggregates it per project.
@MainActor @Observable public final class AttentionTracker {
    private struct Pane {
        let kind: PaneKind
        let project: Project.ID
        var state = AttentionState.idle
    }

    private var panes: [PaneID: Pane] = [:]

    public init() {}

    /// Adds a pane; it starts idle.
    public func register(_ pane: PaneID, kind: PaneKind, project: Project.ID) {
        panes[pane] = Pane(kind: kind, project: project)
    }

    /// Removes a pane whose process stopped.
    public func unregister(_ pane: PaneID) {
        panes[pane] = nil
    }

    /// Applies a hook event; true exactly when the pane went from busy to waiting.
    @discardableResult public func apply(_ event: HookEvent) -> Bool {
        guard let pane = panes[event.pane], pane.kind == .claude else { return false }
        switch (pane.state, event.state) {
        case (_, .busy): panes[event.pane]?.state = .busy
        case (.busy, .waiting):
            panes[event.pane]?.state = .waiting
            return true
        default: break
        }
        return false
    }

    /// HP left the project: its waiting panes become idle.
    public func leave(_ project: Project.ID) {
        for (id, pane) in panes where pane.project == project && pane.state == .waiting {
            panes[id]?.state = .idle
        }
    }

    /// Aggregate of a project: waiting before busy before idle.
    public func state(of project: Project.ID) -> AttentionState {
        let states = Set(panes.values.lazy.filter { $0.project == project }.map(\.state))
        return states.contains(.waiting) ? .waiting : states.contains(.busy) ? .busy : .idle
    }

    /// State of one pane; nil when it is not registered.
    public func state(ofPane pane: PaneID) -> AttentionState? {
        panes[pane]?.state
    }

    /// The first waiting project after the current one in the bar.
    public func nextWaiting(in barOrder: [Project.ID], after current: Project.ID?) -> Project.ID? {
        let waiting = Set(panes.values.lazy.filter { $0.state == .waiting }.map(\.project))
        return Self.nextWaiting(in: barOrder, after: current, waiting: waiting)
    }

    /// The first waiting project after the current one, wrapping around; never the current one.
    public nonisolated static func nextWaiting(
        in barOrder: [Project.ID], after current: Project.ID?, waiting: Set<Project.ID>
    ) -> Project.ID? {
        guard let index = current.flatMap(barOrder.firstIndex(of:)) else { return barOrder.first(where: waiting.contains) }
        return (barOrder[(index + 1)...] + barOrder[..<index]).first(where: waiting.contains)
    }
}
