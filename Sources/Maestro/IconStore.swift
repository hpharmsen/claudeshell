import AppKit
import MaestroCore
import os

/// The icons of the projects: the loaded images, and the search rounds that find them.
@MainActor @Observable final class IconStore {
    private static let log = Logger(subsystem: "Maestro", category: "Icons")

    /// The icon per project; a project without one shows its initials.
    private(set) var images: [Project.ID: NSImage] = [:]

    private let store: ProjectStore
    private let resolver: IconResolver
    /// The last search round per project.
    @ObservationIgnored private var rounds: [Project.ID: Task<Void, Never>] = [:]

    /// Loads the stored icons and searches for every project that was never searched, also the inactive ones (KTD5).
    init(store: ProjectStore, support: URL) {
        self.store = store
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        let session = URLSession(configuration: configuration)
        resolver = IconResolver(iconsFolder: support.appendingPathComponent("icons")) { try await session.data(from: $0).0 }
        for project in store.projects {
            load(project.id)
            search(project.id)
        }
    }

    /// Starts a search round for a project that was never searched; the round runs off the main actor.
    func search(_ id: Project.ID) {
        guard let project = store.project(id), project.iconState == nil else { return }
        rounds[id] = Task {
            let found = await resolver.resolve(project)
            // HP removed the project or its icon while the round ran.
            guard let state = store.project(id).map(\.iconState), state != .removed else { return forget(id) }
            if state != .custom { store.setIconState(.searched, for: id) }
            if found { load(id) }
        }
    }

    /// Searches again, also after the icon was removed; an image HP chose stays (KTD6).
    func searchAgain(_ id: Project.ID) {
        guard store.project(id)?.iconState != .custom else { return }
        store.setIconState(nil, for: id)
        search(id)
    }

    /// Makes an image HP chose the icon, whatever its shape.
    func setCustom(imageAt file: URL, for id: Project.ID) {
        Task {
            // A round that still runs would overwrite the chosen image.
            await rounds[id]?.value
            guard resolver.storeCustom(imageAt: file, for: id) else {
                return Self.log.error("Could not use \(file.path, privacy: .public) as icon")
            }
            store.setIconState(.custom, for: id)
            load(id)
        }
    }

    /// Takes the icon away; the app does not search again by itself.
    func remove(_ id: Project.ID) {
        forget(id)
        store.setIconState(.removed, for: id)
    }

    /// Deletes the icon file of a project, for example of a project that is removed.
    func forget(_ id: Project.ID) {
        resolver.remove(id)
        images[id] = nil
    }

    private func load(_ id: Project.ID) {
        let url = resolver.iconURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            images[id] = NSImage(data: try Data(contentsOf: url))
        } catch {
            Self.log.error("Could not read icon \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
