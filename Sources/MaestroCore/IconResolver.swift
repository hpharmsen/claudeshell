import Foundation
import os

/// Finds the best icon for a project and stores it as a PNG.
public struct IconResolver: Sendable {
    private static let maxBytes = 2 * 1024 * 1024
    private static let log = Logger(subsystem: "Maestro", category: "Icons")

    private let iconsFolder: URL
    private let fetch: @Sendable (URL) async throws -> Data

    public init(iconsFolder: URL, fetch: @escaping @Sendable (URL) async throws -> Data) {
        self.iconsFolder = iconsFolder
        self.fetch = fetch
    }

    /// The file that holds the icon of a project; the project has an icon when it exists.
    public func iconURL(for id: Project.ID) -> URL {
        iconsFolder.appendingPathComponent("\(id.uuidString).png")
    }

    /// Runs one search round and returns whether an icon was found and written; an existing icon stays on a miss.
    public func resolve(_ project: Project) async -> Bool {
        guard project.iconState != .custom, project.iconState != .removed else { return false }
        if let png = await search(project), store(png, for: project.id) { return true }
        Self.log.info("No icon found for \(project.name, privacy: .public)")
        return false
    }

    /// Stores an image the user chose, whatever its shape, and returns whether that worked.
    @discardableResult public func storeCustom(imageAt file: URL, for id: Project.ID) -> Bool {
        guard let data = try? Data(contentsOf: file), let png = IconImage(data: data)?.pngData() else { return false }
        return store(png, for: id)
    }

    /// Deletes the stored icon of a project, if there is one.
    public func remove(_ id: Project.ID) {
        try? FileManager.default.removeItem(at: iconURL(for: id))
    }

    /// The PNG of the first usable image: the filled-in website, then the project folder, then a guessed domain.
    private func search(_ project: Project) async -> Data? {
        if let page = project.website.flatMap(URL.init(string:)), let png = await favicon(of: page) { return png }
        for path in IconFinder.candidates(in: project.path) {
            if let png = Self.usablePNG(try? Data(contentsOf: URL(fileURLWithPath: path))) { return png }
        }
        for domain in DomainGuesser.domains(for: project.path) {
            if let page = URL(string: "https://\(domain)/"), let png = await favicon(of: page) { return png }
        }
        return nil
    }

    /// The PNG of the first usable favicon of a web page.
    private func favicon(of page: URL) async -> Data? {
        guard Self.isWeb(page) else { return nil }
        // A page that fails to load counts as empty, which leaves the two fixed paths on its host.
        let html = await download(page).map { String(decoding: $0, as: UTF8.self) } ?? ""
        for candidate in FaviconLocator.candidates(html: html, pageURL: page) {
            if let png = Self.usablePNG(await download(candidate)) { return png }
        }
        return nil
    }

    /// Fetches a web URL; nil when it is not http or https, fails, or answers with more than 2 MB.
    private func download(_ url: URL) async -> Data? {
        guard Self.isWeb(url), let data = try? await fetch(url), data.count <= Self.maxBytes else { return nil }
        return data
    }

    private static func isWeb(_ url: URL) -> Bool {
        ["http", "https"].contains(url.scheme?.lowercased() ?? "")
    }

    /// The normalised PNG of image bytes, or nil when they are no image or the image is too wide.
    private static func usablePNG(_ data: Data?) -> Data? {
        guard let data, let image = IconImage(data: data), !image.isTooWide else { return nil }
        return image.pngData()
    }

    /// Writes a PNG as the icon of a project, creating the icons folder when needed.
    private func store(_ png: Data, for id: Project.ID) -> Bool {
        do {
            try FileManager.default.createDirectory(at: iconsFolder, withIntermediateDirectories: true)
            try png.write(to: iconURL(for: id), options: .atomic)
            return true
        } catch {
            Self.log.error("Could not write icon \(id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
