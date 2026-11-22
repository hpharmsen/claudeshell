import CoreGraphics
import Foundation

/// Lifecycle status of a project.
public enum ProjectStatus: String, Codable, Sendable {
    case running, active, inactive
}

/// Kind of terminal pane.
public enum PaneKind: String, Codable, Sendable {
    case shell, claude
}

/// Attention state of a pane, or the aggregate of a project.
public enum AttentionState: String, Sendable {
    case idle, busy, waiting
}

/// Identity of one started pane; every start gets a new one.
public struct PaneID: Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init() { rawValue = UUID().uuidString }
    public init(_ rawValue: String) { self.rawValue = rawValue }

    public var description: String { rawValue }
}

/// A project: a folder with a name and a tile color ('#RRGGBB').
public struct Project: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var path: String
    public var color: String

    public init(id: UUID = UUID(), name: String, path: String, color: String) {
        self.id = id
        self.name = name
        self.path = path
        self.color = color
    }
}

/// Window frame for a first start: 3/4 of the visible screen, centered.
public func startFrame(in visible: CGRect) -> CGRect {
    let width = visible.width * 0.75, height = visible.height * 0.75
    return CGRect(x: visible.midX - width / 2, y: visible.midY - height / 2, width: width, height: height)
}
