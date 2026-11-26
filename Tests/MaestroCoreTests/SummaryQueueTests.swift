import Foundation
import Testing
@testable import MaestroCore

private let a = UUID(), b = UUID(), c = UUID()

private func ids(_ queue: SummaryQueue) -> [Project.ID] { queue.waiting.map(\.id) }

@Test func emptyQueueHasNothingNext() {
    var queue = SummaryQueue()
    #expect(queue.next() == nil)
    #expect(queue.current == nil)
}

@Test func projectThatAlreadyWaitsIsNotAddedAgain() {
    var queue = SummaryQueue()
    queue.add(a)
    queue.add(b)
    queue.add(a)
    #expect(ids(queue) == [a, b])
}

@Test func forcedRequestMakesAWaitingPlainRequestForced() {
    var queue = SummaryQueue()
    queue.add(a)
    queue.add(a, force: true)
    #expect(queue.waiting == [SummaryQueue.Request(id: a, force: true, inRound: false)])
}

@Test func plainRequestLeavesAWaitingForcedRequestForced() {
    var queue = SummaryQueue()
    queue.add(a, force: true)
    queue.add(a)
    #expect(queue.waiting.map(\.force) == [true])
}

@Test func requestAtTheFrontComesBeforeTheWaitingOnes() {
    var queue = SummaryQueue()
    queue.add(a)
    queue.add(b)
    queue.add(c, front: true)
    #expect(ids(queue) == [c, a, b])
}

@Test func requestAtTheFrontMovesAWaitingProjectAndKeepsItForced() {
    var queue = SummaryQueue()
    queue.add(a)
    queue.add(b, force: true)
    queue.add(b, front: true)
    #expect(ids(queue) == [b, a])
    #expect(queue.waiting.first?.force == true)
}

@Test func removeTakesAWaitingProjectOut() {
    var queue = SummaryQueue()
    queue.add(a)
    queue.add(b)
    queue.remove(a)
    queue.remove(c)
    #expect(ids(queue) == [b])
}

@Test func nextHandsOutTheRequestsInOrder() {
    var queue = SummaryQueue()
    queue.add(a)
    queue.add(b, force: true)
    #expect(queue.next() == SummaryQueue.Request(id: a, force: false, inRound: false))
    #expect(queue.current?.id == a)
    queue.finish()
    #expect(queue.next() == SummaryQueue.Request(id: b, force: true, inRound: false))
    queue.finish()
    #expect(queue.next() == nil)
    #expect(queue.current == nil)
}

@Test func requestForTheCurrentProjectGivesExactlyOneMoreRound() {
    var queue = SummaryQueue()
    queue.add(a)
    _ = queue.next()
    queue.add(a)
    queue.add(a)
    #expect(ids(queue) == [a])
    queue.finish()
    #expect(queue.next()?.id == a)
    queue.finish()
    #expect(queue.next() == nil)
}

@Test func thereIsNeverMoreThanOneCurrentProject() {
    var queue = SummaryQueue()
    queue.add(a)
    queue.add(b)
    #expect(queue.next()?.id == a)
    #expect(queue.next() == nil)
    #expect(queue.current?.id == a)
    #expect(ids(queue) == [b])
}

@Test func dropRoundTakesOutOnlyTheRequestsOfTheRound() {
    var queue = SummaryQueue()
    queue.add(a, inRound: true)
    queue.add(b)
    queue.add(c, inRound: true)
    queue.dropRound()
    #expect(ids(queue) == [b])
}

@Test func roundRequestThatIsAskedAgainOutsideTheRoundSurvivesTheDrop() {
    var queue = SummaryQueue()
    queue.add(a, inRound: true)
    queue.add(b, inRound: true)
    queue.add(b, front: true)
    queue.add(a, inRound: true)
    queue.dropRound()
    #expect(ids(queue) == [b])
}

@Test func requestOfTheRoundLeavesAWaitingPlainRequestOutsideTheRound() {
    var queue = SummaryQueue()
    queue.add(a)
    queue.add(a, inRound: true)
    queue.dropRound()
    #expect(ids(queue) == [a])
}
