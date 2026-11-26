import Foundation

/// The projects that wait for a summary, in order, and the one whose summary is being made.
public struct SummaryQueue: Equatable, Sendable {
    /// One project that wants a summary.
    public struct Request: Equatable, Sendable {
        public let id: Project.ID
        /// A forced request skips the fingerprint.
        public let force: Bool
        /// A request of the round at the start of the app is dropped when that round fails.
        public let inRound: Bool
    }

    public private(set) var waiting: [Request] = []
    public private(set) var current: Request?

    public init() {}

    /// Adds a project. One that already waits stays in once: forced if either request is, in the round only if both are.
    public mutating func add(_ id: Project.ID, force: Bool = false, front: Bool = false, inRound: Bool = false) {
        let index = waiting.firstIndex { $0.id == id }
        let old = index.map { waiting[$0] }
        let request = Request(id: id, force: force || old?.force == true, inRound: inRound && old?.inRound != false)
        if let index {
            guard front else { return waiting[index] = request }
            waiting.remove(at: index)
        }
        waiting.insert(request, at: front ? 0 : waiting.count)
    }

    /// Makes the first waiting request the current one; nil when nothing waits or a request is still current.
    public mutating func next() -> Request? {
        guard current == nil, !waiting.isEmpty else { return nil }
        current = waiting.removeFirst()
        return current
    }

    /// Ends the current request.
    public mutating func finish() { current = nil }

    /// Takes a waiting project out; a current one runs to its end.
    public mutating func remove(_ id: Project.ID) { waiting.removeAll { $0.id == id } }

    /// Takes out what still waits of the round at the start of the app.
    public mutating func dropRound() { waiting.removeAll(where: \.inRound) }
}
