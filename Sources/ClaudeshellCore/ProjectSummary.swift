import Foundation
import os

/// What a summary was made from: the conversation file, its last real message and the commit of HEAD.
public struct SummaryFingerprint: Codable, Equatable, Sendable {
    public var conversationFile: String?
    public var lastMessageUUID: String?
    public var headCommit: String?

    public init(conversationFile: String? = nil, lastMessageUUID: String? = nil, headCommit: String? = nil) {
        self.conversationFile = conversationFile
        self.lastMessageUUID = lastMessageUUID
        self.headCommit = headCommit
    }
}

/// The AI summary of a project, stored as 'summaries/<project-id>.json' in the support folder.
public struct ProjectSummary: Codable, Equatable, Sendable {
    private static let log = Logger(subsystem: "Claudeshell", category: "ProjectSummary")

    public var text: String
    /// The moment the summary was made.
    public var date: Date
    public var fingerprint: SummaryFingerprint

    public init(text: String, date: Date, fingerprint: SummaryFingerprint) {
        self.text = text
        self.date = date
        self.fingerprint = fingerprint
    }

    /// The file that holds the summary of a project.
    public static func fileURL(for id: Project.ID, in supportFolder: URL) -> URL {
        supportFolder.appendingPathComponent("summaries").appendingPathComponent("\(id.uuidString).json")
    }

    /// The stored summary of a project; a missing or unreadable file counts as no summary.
    public static func read(for id: Project.ID, in supportFolder: URL) -> ProjectSummary? {
        let url = fileURL(for: id, in: supportFolder)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try JSONDecoder().decode(ProjectSummary.self, from: Data(contentsOf: url))
        } catch {
            log.error("Unreadable \(url.path, privacy: .public): \(error)")
            return nil
        }
    }

    /// Writes the summary atomically, creating the folder when it is missing.
    public func write(for id: Project.ID, in supportFolder: URL) {
        let url = Self.fileURL(for: id, in: supportFolder)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(self).write(to: url, options: .atomic)
        } catch {
            Self.log.error("Could not save \(url.path, privacy: .public): \(error)")
        }
    }

    /// Deletes the stored summary of a project, if there is one.
    public static func delete(for id: Project.ID, in supportFolder: URL) {
        let url = fileURL(for: id, in: supportFolder)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            log.error("Could not delete \(url.path, privacy: .public): \(error)")
        }
    }
}
