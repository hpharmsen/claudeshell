import Foundation
import Observation
import os

/// Manages and persists the projects, with all rules for status and order.
@MainActor @Observable public final class ProjectStore {
    /// Whether the storage file existed when the store was created.
    public let fileExisted: Bool
    /// All projects, in the order they were added.
    public private(set) var projects: [Project] = []
    public private(set) var selectedID: Project.ID?

    private var statuses: [Project.ID: ProjectStatus] = [:]
    private let fileURL: URL

    /// One project as stored in the file: the project fields plus its status.
    private struct Record: Codable {
        let project: Project
        let status: ProjectStatus

        enum CodingKeys: CodingKey { case status }

        init(project: Project, status: ProjectStatus) {
            self.project = project
            self.status = status
        }

        init(from decoder: any Decoder) throws {
            project = try Project(from: decoder)
            status = try decoder.container(keyedBy: CodingKeys.self).decode(ProjectStatus.self, forKey: .status)
        }

        func encode(to encoder: any Encoder) throws {
            try project.encode(to: encoder)
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(status, forKey: .status)
        }
    }

    /// Loads the projects from the file; a corrupt file is set aside as 'projects.corrupt.json'.
    public init(fileURL: URL) {
        self.fileURL = fileURL
        fileExisted = FileManager.default.fileExists(atPath: fileURL.path)
        guard fileExisted else { return }
        do {
            let records = try JSONDecoder().decode([Record].self, from: Data(contentsOf: fileURL))
            projects = records.map(\.project)
            records.filter { $0.status == .inactive }.forEach { statuses[$0.project.id] = .inactive }
        } catch {
            Self.log.error("Unreadable \(fileURL.path, privacy: .public): \(error)")
            let corruptURL = fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")
            do {
                if FileManager.default.fileExists(atPath: corruptURL.path) {
                    try FileManager.default.removeItem(at: corruptURL)
                }
                try FileManager.default.moveItem(at: fileURL, to: corruptURL)
            } catch {
                Self.log.error("Could not set corrupt file aside: \(error)")
            }
        }
    }

    /// Running and active projects in bar order: alphabetical by name, same names by folder.
    public var barProjects: [Project] {
        projects.filter { status(of: $0.id) != .inactive }.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.path < $1.path : order == .orderedAscending
        }
    }

    public var inactiveProjects: [Project] { projects.filter { status(of: $0.id) == .inactive } }

    /// Status of a project; an unknown project is inactive.
    public func status(of id: Project.ID) -> ProjectStatus {
        statuses[id] ?? (index(of: id) == nil ? .inactive : .active)
    }

    public func project(_ id: Project.ID) -> Project? { projects.first { $0.id == id } }

    /// Adds a folder as project, or revives the existing project of that folder.
    @discardableResult public func add(path: String, name: String? = nil) -> Project {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        if let existing = projects.first(where: { $0.path == url.path }) {
            switch status(of: existing.id) {
            case .inactive: setStatus(.active, for: existing.id)
            case .running: select(existing.id)
            case .active: break
            }
            return existing
        }
        let project = Project(name: name ?? url.lastPathComponent, path: url.path,
                              color: ColorPalette.next(used: projects.map(\.color)))
        projects.append(project)
        save()
        return project
    }

    /// Sets the status; a project that becomes inactive leaves the bar and loses the selection.
    public func setStatus(_ status: ProjectStatus, for id: Project.ID) {
        guard index(of: id) != nil else { return }
        let old = self.status(of: id)
        guard status != old else { return }
        statuses[id] = status
        if status == .inactive || old == .inactive, selectedID == id { selectedID = nil }
        save()
    }

    /// Selects a project in the bar, or nothing.
    public func select(_ id: Project.ID?) {
        guard id.map({ status(of: $0) != .inactive }) ?? true else { return }
        selectedID = id
    }

    /// Renames a project; a blank name is refused.
    @discardableResult public func rename(_ id: Project.ID, to name: String) -> Bool {
        guard let index = index(of: id), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        projects[index].name = name
        save()
        return true
    }

    public func setColor(_ color: String, for id: Project.ID) {
        guard let index = index(of: id) else { return }
        projects[index].color = color
        save()
    }

    /// Sets the website; blank text clears it, a bare domain gets 'https://', text without a valid host is refused.
    @discardableResult public func setWebsite(_ text: String, for id: Project.ID) -> Bool {
        guard let index = index(of: id) else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var website: String?
        if !trimmed.isEmpty {
            guard let url = Self.normalizedURL(trimmed, localAllowed: false) else { return false }
            website = url
        }
        projects[index].website = website
        save()
        return true
    }

    /// Sets the user's own link of one kind; blank text stores 'cleared', text without a valid host is refused.
    @discardableResult public func setLink(_ text: String, kind: LinkKind, for id: Project.ID) -> Bool {
        guard let index = index(of: id) else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let link = trimmed.isEmpty ? "" : Self.normalizedURL(trimmed, localAllowed: true) else { return false }
        projects[index].linkOverrides = (projects[index].linkOverrides ?? [:]).merging([kind: link]) { $1 }
        save()
        return true
    }

    /// Forgets the user's own links, so the app finds them again.
    public func clearLinkOverrides(for id: Project.ID) {
        guard let index = index(of: id) else { return }
        projects[index].linkOverrides = nil
        save()
    }

    public func setIconState(_ state: IconState?, for id: Project.ID) {
        guard let index = index(of: id) else { return }
        projects[index].iconState = state
        save()
    }

    /// Removes the project from the app; the folder stays untouched.
    public func remove(_ id: Project.ID) {
        projects.removeAll { $0.id == id }
        statuses[id] = nil
        if selectedID == id { selectedID = nil }
        save()
    }

    /// Writes the file atomically; running is stored as active.
    public func save() {
        let records = projects.map { Record(project: $0, status: status(of: $0.id) == .inactive ? .inactive : .active) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(records).write(to: fileURL, options: .atomic)
        } catch {
            Self.log.error("Could not save \(self.fileURL.path, privacy: .public): \(error)")
        }
    }

    private static let log = Logger(subsystem: "Claudeshell", category: "ProjectStore")

    /// Trimmed text as URL, or nil without a valid host; no scheme gives 'https://', or 'http://' for an allowed local host.
    private static func normalizedURL(_ trimmed: String, localAllowed: Bool) -> String? {
        let lowered = trimmed.lowercased()
        let isLocal = localAllowed && ["localhost", "127.0.0.1"].contains(String(lowered.prefix { !":/".contains($0) }))
        let url = lowered.hasPrefix("http://") || lowered.hasPrefix("https://") ? trimmed
            : (isLocal ? "http://" : "https://") + trimmed
        guard !url.contains(" "), let host = URL(string: url)?.host?.lowercased(),
              host.contains(".") || localAllowed && host == "localhost" else { return nil }
        return url
    }

    private func index(of id: Project.ID) -> Int? { projects.firstIndex { $0.id == id } }
}
