import Foundation
import Testing
@testable import ClaudeshellCore

private let busy = AttentionState.busy, waiting = AttentionState.waiting

/// A tracker with one registered Claude pane.
@MainActor private func makeTracker() -> (AttentionTracker, PaneID, Project.ID) {
    let tracker = AttentionTracker(), pane = PaneID(), project = UUID()
    tracker.register(pane, kind: .claude, project: project)
    return (tracker, pane, project)
}

@MainActor @Test func registeredPaneStartsIdle() {
    let (tracker, pane, project) = makeTracker()
    #expect(tracker.state(ofPane: pane) == .idle)
    #expect(tracker.state(of: project) == .idle)
}

@MainActor @Test func unknownPaneHasNoStateAndUnknownProjectIsIdle() {
    let tracker = AttentionTracker()
    #expect(tracker.state(ofPane: PaneID()) == nil)
    #expect(tracker.state(of: UUID()) == .idle)
}

@MainActor @Test func busyPutsIdlePaneOnBusy() {
    let (tracker, pane, project) = makeTracker()
    #expect(tracker.apply(HookEvent(pane: pane, state: busy)) == false)
    #expect(tracker.state(ofPane: pane) == .busy)
    #expect(tracker.state(of: project) == .busy)
}

@MainActor @Test func busyThenWaitingReportsOneTransition() {
    let (tracker, pane, project) = makeTracker()
    tracker.apply(HookEvent(pane: pane, state: busy))
    #expect(tracker.apply(HookEvent(pane: pane, state: waiting)) == true)
    #expect(tracker.state(ofPane: pane) == .waiting)
    #expect(tracker.state(of: project) == .waiting)
}

@MainActor @Test func busyPutsWaitingPaneOnBusy() {
    let (tracker, pane, _) = makeTracker()
    tracker.apply(HookEvent(pane: pane, state: busy))
    tracker.apply(HookEvent(pane: pane, state: waiting))
    #expect(tracker.apply(HookEvent(pane: pane, state: busy)) == false)
    #expect(tracker.state(ofPane: pane) == .busy)
}

@MainActor @Test func secondWaitingReportsNoTransition() {
    let (tracker, pane, _) = makeTracker()
    tracker.apply(HookEvent(pane: pane, state: busy))
    tracker.apply(HookEvent(pane: pane, state: waiting))
    #expect(tracker.apply(HookEvent(pane: pane, state: waiting)) == false)
    #expect(tracker.state(ofPane: pane) == .waiting)
}

@MainActor @Test func waitingOnIdlePaneLeavesItIdle() {
    let (tracker, pane, _) = makeTracker()
    #expect(tracker.apply(HookEvent(pane: pane, state: waiting)) == false)
    #expect(tracker.state(ofPane: pane) == .idle)
}

@MainActor @Test func leavingPutsWaitingPaneOnIdleAndLeavesBusyPaneBusy() {
    let (tracker, waitingPane, project) = makeTracker()
    let busyPane = PaneID()
    tracker.register(busyPane, kind: .claude, project: project)
    tracker.apply(HookEvent(pane: waitingPane, state: busy))
    tracker.apply(HookEvent(pane: waitingPane, state: waiting))
    tracker.apply(HookEvent(pane: busyPane, state: busy))
    tracker.leave(project)
    #expect(tracker.state(ofPane: waitingPane) == .idle)
    #expect(tracker.state(ofPane: busyPane) == .busy)
}

@MainActor @Test func leavingDoesNotTouchOtherProjects() {
    let (tracker, pane, _) = makeTracker()
    tracker.apply(HookEvent(pane: pane, state: busy))
    tracker.apply(HookEvent(pane: pane, state: waiting))
    tracker.leave(UUID())
    #expect(tracker.state(ofPane: pane) == .waiting)
}

@MainActor @Test func afterLeavingBusyThenWaitingReportsAgain() {
    let (tracker, pane, project) = makeTracker()
    tracker.apply(HookEvent(pane: pane, state: busy))
    tracker.apply(HookEvent(pane: pane, state: waiting))
    tracker.leave(project)
    tracker.apply(HookEvent(pane: pane, state: busy))
    #expect(tracker.apply(HookEvent(pane: pane, state: waiting)) == true)
    #expect(tracker.state(ofPane: pane) == .waiting)
}

@MainActor @Test func waitingRightAfterLeavingReportsNoTransition() {
    let (tracker, pane, project) = makeTracker()
    tracker.apply(HookEvent(pane: pane, state: busy))
    tracker.apply(HookEvent(pane: pane, state: waiting))
    tracker.leave(project)
    #expect(tracker.apply(HookEvent(pane: pane, state: waiting)) == false)
    #expect(tracker.state(ofPane: pane) == .idle)
}

@MainActor @Test func eventForUnregisteredPaneIsIgnored() {
    let (tracker, pane, project) = makeTracker()
    let earlier = PaneID()
    #expect(tracker.apply(HookEvent(pane: earlier, state: busy)) == false)
    #expect(tracker.state(ofPane: earlier) == nil)
    #expect(tracker.state(ofPane: pane) == .idle)
    #expect(tracker.state(of: project) == .idle)
}

@MainActor @Test func unregisteredPaneDisappearsFromAggregate() {
    let (tracker, pane, project) = makeTracker()
    tracker.apply(HookEvent(pane: pane, state: busy))
    tracker.apply(HookEvent(pane: pane, state: waiting))
    tracker.unregister(pane)
    #expect(tracker.state(ofPane: pane) == nil)
    #expect(tracker.state(of: project) == .idle)
}

@MainActor @Test func lateEventAfterUnregisterIsIgnored() {
    let (tracker, pane, project) = makeTracker()
    tracker.apply(HookEvent(pane: pane, state: busy))
    tracker.unregister(pane)
    #expect(tracker.apply(HookEvent(pane: pane, state: waiting)) == false)
    #expect(tracker.state(of: project) == .idle)
}

@MainActor @Test func projectWithOneWaitingAndOneBusyPaneShowsWaiting() {
    let (tracker, first, project) = makeTracker()
    let second = PaneID()
    tracker.register(second, kind: .claude, project: project)
    tracker.apply(HookEvent(pane: first, state: busy))
    tracker.apply(HookEvent(pane: first, state: waiting))
    tracker.apply(HookEvent(pane: second, state: busy))
    #expect(tracker.state(of: project) == .waiting)
}

@MainActor @Test func projectWithOneBusyAndOneIdlePaneShowsBusy() {
    let (tracker, first, project) = makeTracker()
    tracker.register(PaneID(), kind: .claude, project: project)
    tracker.apply(HookEvent(pane: first, state: busy))
    #expect(tracker.state(of: project) == .busy)
}

@MainActor @Test func projectWithShellPaneAndIdleClaudePaneShowsIdle() {
    let (tracker, _, project) = makeTracker()
    let shell = PaneID()
    tracker.register(shell, kind: .shell, project: project)
    #expect(tracker.state(ofPane: shell) == .idle)
    #expect(tracker.state(of: project) == .idle)
}

@MainActor @Test func aggregateOnlyCountsPanesOfThatProject() {
    let (tracker, pane, _) = makeTracker()
    let other = UUID()
    tracker.register(PaneID(), kind: .claude, project: other)
    tracker.apply(HookEvent(pane: pane, state: busy))
    #expect(tracker.state(of: other) == .idle)
}

// MARK: next waiting project

private let bar = (0..<6).map { _ in UUID() }

@Test func withoutWaitingProjectsJumpReturnsNothing() {
    #expect(AttentionTracker.nextWaiting(in: bar, after: bar[2], waiting: []) == nil)
}

@Test func jumpGoesToNextWaitingAfterCurrent() {
    #expect(AttentionTracker.nextWaiting(in: bar, after: bar[2], waiting: [bar[1], bar[4]]) == bar[4])
}

@Test func jumpWrapsAroundToStart() {
    #expect(AttentionTracker.nextWaiting(in: bar, after: bar[4], waiting: [bar[1], bar[4]]) == bar[1])
}

@Test func withoutCurrentJumpGivesFirstWaitingInBar() {
    #expect(AttentionTracker.nextWaiting(in: bar, after: nil, waiting: [bar[4], bar[1]]) == bar[1])
}

@Test func currentAsOnlyWaitingProjectReturnsNothing() {
    #expect(AttentionTracker.nextWaiting(in: bar, after: bar[2], waiting: [bar[2]]) == nil)
}

@Test func emptyBarOrderReturnsNothing() {
    let id = UUID()
    #expect(AttentionTracker.nextWaiting(in: [], after: nil, waiting: [id]) == nil)
    #expect(AttentionTracker.nextWaiting(in: [], after: id, waiting: [id]) == nil)
}

@Test func currentNotInBarGivesFirstWaitingInBar() {
    #expect(AttentionTracker.nextWaiting(in: bar, after: UUID(), waiting: [bar[3], bar[5]]) == bar[3])
}

@Test func waitingProjectOutsideBarIsNeverReturned() {
    #expect(AttentionTracker.nextWaiting(in: bar, after: bar[0], waiting: [UUID()]) == nil)
}

@MainActor @Test func trackerJumpsToWaitingProjectFromItsOwnStates() {
    let tracker = AttentionTracker(), pane = PaneID()
    tracker.register(pane, kind: .claude, project: bar[4])
    tracker.register(PaneID(), kind: .claude, project: bar[1])
    tracker.apply(HookEvent(pane: pane, state: busy))
    tracker.apply(HookEvent(pane: pane, state: waiting))
    #expect(tracker.nextWaiting(in: bar, after: bar[0]) == bar[4])
}

@MainActor @Test func currentOnlyWaitingProjectStillReportedTransition() {
    let (tracker, pane, project) = makeTracker()
    tracker.apply(HookEvent(pane: pane, state: busy))
    #expect(tracker.apply(HookEvent(pane: pane, state: waiting)) == true)
    #expect(tracker.nextWaiting(in: [UUID(), project, UUID()], after: project) == nil)
}
