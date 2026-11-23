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

/// How a project came by its icon; a project without one has never been searched.
public enum IconState: String, Codable, Sendable {
    case searched, custom, removed
}

/// Kind of link of a project; the raw value is the key in the stored JSON object.
public enum LinkKind: String, Codable, CodingKeyRepresentable, CaseIterable, Sendable {
    case live, localhost, git
}

/// A project: a folder with a name and a tile color ('#RRGGBB').
public struct Project: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var path: String
    public var color: String
    public var website: String?
    public var iconState: IconState?
    /// Links the user set himself: a missing kind means 'use what the app finds', an empty text means 'cleared'.
    public var linkOverrides: [LinkKind: String]?

    public init(id: UUID = UUID(), name: String, path: String, color: String, website: String? = nil,
                iconState: IconState? = nil, linkOverrides: [LinkKind: String]? = nil) {
        self.id = id
        self.name = name
        self.path = path
        self.color = color
        self.website = website
        self.iconState = iconState
        self.linkOverrides = linkOverrides
    }

    /// Two letters for a tile without icon: of the first two words, or the first two of a single word.
    public var initials: String {
        let words = name.split { " .-_".contains($0) }
        guard words.count < 2 else { return words.prefix(2).map { $0.prefix(1).uppercased() }.joined() }
        let word = words.first ?? ""
        return word.prefix(1).uppercased() + word.dropFirst().prefix(1)
    }
}

/// Window frame for a first start: 3/4 of the visible screen, centered.
public func startFrame(in visible: CGRect) -> CGRect {
    let width = visible.width * 0.75, height = visible.height * 0.75
    return CGRect(x: visible.midX - width / 2, y: visible.midY - height / 2, width: width, height: height)
}
