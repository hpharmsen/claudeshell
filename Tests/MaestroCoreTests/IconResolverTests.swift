import AppKit
import Foundation
import Testing
@testable import MaestroCore

// MARK: - Helpers

/// A network with fixed answers: unknown URLs throw, and every requested URL is recorded.
private final class FetchStub: @unchecked Sendable {
    private let lock = NSLock()
    private let responses: [String: Data]
    private var log: [String] = []

    /// `responses` maps an absolute URL string to the bytes it answers with.
    init(_ responses: [String: Data]) { self.responses = responses }

    /// The absolute strings of the requested URLs, in order.
    var requested: [String] { lock.withLock { log } }

    func respond(to url: URL) throws -> Data {
        lock.withLock { log.append(url.absoluteString) }
        guard let data = responses[url.absoluteString] else { throw URLError(.fileDoesNotExist) }
        return data
    }
}

/// A project folder, an icons folder that does not exist yet, and a resolver on a stubbed network.
private struct Fixture {
    let root: URL
    let project: Project
    let iconsFolder: URL
    let stub: FetchStub
    let resolver: IconResolver

    var iconURL: URL { resolver.iconURL(for: project.id) }
    var storedIcon: Data? { try? Data(contentsOf: iconURL) }

    /// Puts bytes where the icon of the project lives, as an earlier round would have.
    func writeExistingIcon(_ data: Data) throws {
        try FileManager.default.createDirectory(at: iconsFolder, withIntermediateDirectories: true)
        try data.write(to: iconURL)
    }

    func cleanUp() { try? FileManager.default.removeItem(at: root) }
}

/// Builds a project folder with `files` (relative path to contents) and a network answering with `responses`.
private func makeFixture(files: [String: Data] = [:], website: String? = nil, iconState: IconState? = nil,
                         responses: [String: Data] = [:]) throws -> Fixture {
    let root = try makeTempDir()
    let folder = root.appendingPathComponent("janitor")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for (relativePath, contents) in files {
        let file = folder.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: file)
    }
    let project = Project(name: "Janitor", path: folder.path, color: "#336699", website: website, iconState: iconState)
    let iconsFolder = root.appendingPathComponent("icons")
    let stub = FetchStub(responses)
    let resolver = IconResolver(iconsFolder: iconsFolder) { url in try stub.respond(to: url) }
    return Fixture(root: root, project: project, iconsFolder: iconsFolder, stub: stub, resolver: resolver)
}

private func html(_ head: String) -> Data {
    Data("<html><head>\(head)</head><body></body></html>".utf8)
}

/// A valid square PNG of more than 2 MB: noise does not compress.
private func makeOversizedPNG() throws -> Data {
    var state: UInt32 = 1
    let data = try makePNG(width: 1024, height: 1024) { index in
        state = state &* 1_664_525 &+ 1_013_904_223
        return index % 4 == 3 ? 255 : UInt8(state >> 24)
    }
    try #require(data.count > 2_000_000)
    return data
}

private let centre = IconImage.side / 2
private let garbage = Data("this is not an image".utf8)
private let cname = Data("voorbeeld.nl\n".utf8)

// MARK: - Where the icon lives (KTD2)

@Test func iconURLIsThePngNamedAfterTheProjectInTheIconsFolder() throws {
    let fixture = try makeFixture()
    defer { fixture.cleanUp() }
    let expected = fixture.iconsFolder.appendingPathComponent("\(fixture.project.id.uuidString).png")
    #expect(fixture.iconURL.standardizedFileURL.path == expected.standardizedFileURL.path)
}

@Test func missingIconsFolderIsCreatedByARound() async throws {
    let fixture = try makeFixture(files: ["favicon.png": try makePNG(width: 64, height: 64)])
    defer { fixture.cleanUp() }
    #expect(!FileManager.default.fileExists(atPath: fixture.iconsFolder.path))
    #expect(await fixture.resolver.resolve(fixture.project))
    #expect(FileManager.default.fileExists(atPath: fixture.iconURL.path))
}

// MARK: - Icons from the project folder (KTD4 step 2)

@Test func squareFaviconInFolderIsStoredWithoutFetching() async throws {
    let fixture = try makeFixture(files: ["static/favicon.png": try makePNG(width: 64, height: 64, tint: .green)])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project))
    #expect(pixelSize(of: fixture.storedIcon) == [128, 128])
    #expect(Tint.green.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
    #expect(fixture.stub.requested.isEmpty)
}

@Test func brokenFirstFolderCandidateFallsThroughToTheSecond() async throws {
    let fixture = try makeFixture(files: [
        "apple-touch-icon.png": garbage,
        "favicon.png": try makePNG(width: 64, height: 64, tint: .blue),
    ])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project))
    #expect(Tint.blue.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
}

@Test func wideFirstFolderCandidateFallsThroughToTheSecond() async throws {
    let fixture = try makeFixture(files: [
        "favicon.png": try makePNG(width: 300, height: 100, tint: .red),
        "logo.png": try makePNG(width: 100, height: 100, tint: .green),
    ])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project))
    #expect(Tint.green.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
    #expect(Tint.green.matches(pixel(of: fixture.storedIcon, x: centre, y: 10)))
}

@Test func wideLogoWithoutADomainFindsNothing() async throws {
    let fixture = try makeFixture(files: ["logo.png": try makePNG(width: 300, height: 100)])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project) == false)
    #expect(!FileManager.default.fileExists(atPath: fixture.iconURL.path))
    #expect(fixture.stub.requested.isEmpty)
}

@Test func emptyFolderFindsNothing() async throws {
    let fixture = try makeFixture()
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project) == false)
    #expect(!FileManager.default.fileExists(atPath: fixture.iconURL.path))
}

// MARK: - Favicon of a guessed domain (KTD4 step 3)

@Test func wideLogoIsSkippedForTheFaviconOfAGuessedDomain() async throws {
    let fixture = try makeFixture(
        files: ["logo.png": try makePNG(width: 300, height: 100, tint: .red), "CNAME": cname],
        responses: [
            "https://voorbeeld.nl/": html("<link rel=\"icon\" href=\"/img/fav.png\">"),
            "https://voorbeeld.nl/img/fav.png": try makePNG(width: 64, height: 64, tint: .green),
        ])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project))
    #expect(pixelSize(of: fixture.storedIcon) == [128, 128])
    #expect(Tint.green.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
    #expect(fixture.stub.requested.first == "https://voorbeeld.nl/")
}

@Test func squareFolderIconWinsOverAGuessedDomain() async throws {
    let fixture = try makeFixture(
        files: ["favicon.png": try makePNG(width: 64, height: 64, tint: .blue), "CNAME": cname],
        responses: [
            "https://voorbeeld.nl/": html(""),
            "https://voorbeeld.nl/favicon.ico": try makePNG(width: 64, height: 64, tint: .green),
        ])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project))
    #expect(Tint.blue.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
    #expect(fixture.stub.requested.isEmpty)
}

@Test func guessedDomainThatDoesNotAnswerFindsNothing() async throws {
    let fixture = try makeFixture(files: ["CNAME": cname])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project) == false)
    #expect(!FileManager.default.fileExists(atPath: fixture.iconURL.path))
}

// MARK: - Favicon of a filled-in website (KTD4 step 1)

@Test func websiteFaviconWinsOverFolderIcon() async throws {
    let fixture = try makeFixture(
        files: ["favicon.png": try makePNG(width: 64, height: 64, tint: .blue)],
        website: "https://www.voorbeeld.nl",
        responses: [
            "https://www.voorbeeld.nl": html("<link rel=\"icon\" href=\"/static/fav.png\">"),
            "https://www.voorbeeld.nl/static/fav.png": try makePNG(width: 64, height: 64, tint: .green),
        ])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project))
    #expect(Tint.green.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
    #expect(fixture.stub.requested.first == "https://www.voorbeeld.nl")
}

@Test func failingWebsiteFallsBackToTheFolder() async throws {
    let fixture = try makeFixture(
        files: ["favicon.png": try makePNG(width: 64, height: 64, tint: .blue)],
        website: "https://www.voorbeeld.nl")
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project))
    #expect(Tint.blue.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
    #expect(fixture.stub.requested.contains("https://www.voorbeeld.nl"))
}

@Test func touchIconThatFailsFallsBackToFaviconIco() async throws {
    let fixture = try makeFixture(
        website: "https://www.voorbeeld.nl",
        responses: [
            "https://www.voorbeeld.nl": html("<link rel=\"apple-touch-icon\" href=\"/touch.png\">"),
            "https://www.voorbeeld.nl/favicon.ico": try makePNG(width: 32, height: 32, tint: .green),
        ])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project))
    #expect(Tint.green.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
    #expect(fixture.stub.requested.contains("https://www.voorbeeld.nl/touch.png"))
}

@Test func touchIconThatIsNoImageFallsBackToFaviconIco() async throws {
    let fixture = try makeFixture(
        website: "https://www.voorbeeld.nl",
        responses: [
            "https://www.voorbeeld.nl": html("<link rel=\"apple-touch-icon\" href=\"/touch.png\">"),
            "https://www.voorbeeld.nl/touch.png": garbage,
            "https://www.voorbeeld.nl/favicon.ico": try makePNG(width: 32, height: 32, tint: .green),
        ])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project))
    #expect(Tint.green.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
}

// MARK: - Limits on what comes in (KTD10)

@Test func responseOverTwoMegabytesIsSkipped() async throws {
    let fixture = try makeFixture(
        website: "https://www.voorbeeld.nl",
        responses: [
            "https://www.voorbeeld.nl": html("<link rel=\"apple-touch-icon\" href=\"/huge.png\">"),
            "https://www.voorbeeld.nl/huge.png": try makeOversizedPNG(),
            "https://www.voorbeeld.nl/favicon.ico": try makePNG(width: 32, height: 32, tint: .green),
        ])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project))
    #expect(Tint.green.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
}

@Test func onlyAResponseOverTwoMegabytesFindsNothing() async throws {
    let fixture = try makeFixture(
        website: "https://www.voorbeeld.nl",
        responses: [
            "https://www.voorbeeld.nl": html(""),
            "https://www.voorbeeld.nl/favicon.ico": try makeOversizedPNG(),
        ])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project) == false)
    #expect(!FileManager.default.fileExists(atPath: fixture.iconURL.path))
}

@Test func faviconWithFileSchemeIsNotFetched() async throws {
    let local = "file:///private/var/voorbeeld/icon.png"
    let fixture = try makeFixture(
        website: "https://www.voorbeeld.nl",
        responses: [
            "https://www.voorbeeld.nl": html("<link rel=\"apple-touch-icon\" href=\"\(local)\">"),
            local: try makePNG(width: 64, height: 64, tint: .red),
            "https://www.voorbeeld.nl/favicon.ico": try makePNG(width: 32, height: 32, tint: .green),
        ])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project))
    #expect(Tint.green.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
    #expect(fixture.stub.requested.allSatisfy { $0.hasPrefix("https://") })
}

@Test func websiteWithFileSchemeIsNotFetched() async throws {
    let page = "file:///private/var/voorbeeld/index.html"
    let fixture = try makeFixture(
        website: page,
        responses: [
            page: html("<link rel=\"icon\" href=\"icon.png\">"),
            "file:///private/var/voorbeeld/icon.png": try makePNG(width: 64, height: 64),
            "file:///favicon.ico": try makePNG(width: 64, height: 64),
            "file:///apple-touch-icon.png": try makePNG(width: 64, height: 64),
        ])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project) == false)
    #expect(fixture.stub.requested.isEmpty)
    #expect(!FileManager.default.fileExists(atPath: fixture.iconURL.path))
}

// MARK: - Replacing only on a hit (KTD3)

@Test func existingIconSurvivesARoundWithoutResult() async throws {
    let fixture = try makeFixture()
    defer { fixture.cleanUp() }
    let existing = try makePNG(width: 128, height: 128, tint: .red)
    try fixture.writeExistingIcon(existing)
    #expect(await fixture.resolver.resolve(fixture.project) == false)
    #expect(fixture.storedIcon == existing)
}

@Test func existingIconIsReplacedByANewFind() async throws {
    let fixture = try makeFixture(files: ["favicon.png": try makePNG(width: 64, height: 64, tint: .green)])
    defer { fixture.cleanUp() }
    try fixture.writeExistingIcon(try makePNG(width: 128, height: 128, tint: .red))
    #expect(await fixture.resolver.resolve(fixture.project))
    #expect(pixelSize(of: fixture.storedIcon) == [128, 128])
    #expect(Tint.green.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
}

// MARK: - Projects that are not searched (KTD4)

@Test(arguments: [IconState.custom, .removed])
func customAndRemovedProjectsAreNotSearched(state: IconState) async throws {
    let fixture = try makeFixture(
        files: ["favicon.png": try makePNG(width: 64, height: 64), "CNAME": cname],
        website: "https://www.voorbeeld.nl",
        iconState: state,
        responses: [
            "https://www.voorbeeld.nl": html(""),
            "https://www.voorbeeld.nl/favicon.ico": try makePNG(width: 32, height: 32),
        ])
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project) == false)
    #expect(!FileManager.default.fileExists(atPath: fixture.iconURL.path))
    #expect(fixture.stub.requested.isEmpty)
}

@Test func customIconIsLeftAloneByARound() async throws {
    let fixture = try makeFixture(
        files: ["favicon.png": try makePNG(width: 64, height: 64, tint: .green)], iconState: .custom)
    defer { fixture.cleanUp() }
    let existing = try makePNG(width: 128, height: 128, tint: .red)
    try fixture.writeExistingIcon(existing)
    #expect(await fixture.resolver.resolve(fixture.project) == false)
    #expect(fixture.storedIcon == existing)
}

@Test func searchedProjectIsSearchedAgain() async throws {
    let fixture = try makeFixture(
        files: ["favicon.png": try makePNG(width: 64, height: 64, tint: .green)], iconState: .searched)
    defer { fixture.cleanUp() }
    #expect(await fixture.resolver.resolve(fixture.project))
    #expect(Tint.green.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
}

// MARK: - An image HP chose (KTD8)

@Test func chosenWideImageIsStoredFittedAndCentred() throws {
    let fixture = try makeFixture()
    defer { fixture.cleanUp() }
    let chosen = fixture.root.appendingPathComponent("banner.png")
    try makePNG(width: 300, height: 100, tint: .blue).write(to: chosen)
    #expect(fixture.resolver.storeCustom(imageAt: chosen, for: fixture.project.id))
    #expect(pixelSize(of: fixture.storedIcon) == [128, 128])
    #expect(Tint.blue.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
    #expect(isTransparent(pixel(of: fixture.storedIcon, x: centre, y: 10)))
    #expect(isTransparent(pixel(of: fixture.storedIcon, x: centre, y: 117)))
}

@Test func chosenImageReplacesTheExistingIcon() throws {
    let fixture = try makeFixture()
    defer { fixture.cleanUp() }
    try fixture.writeExistingIcon(try makePNG(width: 128, height: 128, tint: .red))
    let chosen = fixture.root.appendingPathComponent("chosen.png")
    try makePNG(width: 64, height: 64, tint: .green).write(to: chosen)
    #expect(fixture.resolver.storeCustom(imageAt: chosen, for: fixture.project.id))
    #expect(Tint.green.matches(pixel(of: fixture.storedIcon, x: centre, y: centre)))
}

@Test func chosenFileThatIsNoImageIsRefusedAndKeepsTheExistingIcon() throws {
    let fixture = try makeFixture()
    defer { fixture.cleanUp() }
    let existing = try makePNG(width: 128, height: 128, tint: .red)
    try fixture.writeExistingIcon(existing)
    let chosen = fixture.root.appendingPathComponent("notes.png")
    try garbage.write(to: chosen)
    #expect(fixture.resolver.storeCustom(imageAt: chosen, for: fixture.project.id) == false)
    #expect(fixture.storedIcon == existing)
}

@Test func chosenFileThatDoesNotExistIsRefused() throws {
    let fixture = try makeFixture()
    defer { fixture.cleanUp() }
    let missing = fixture.root.appendingPathComponent("missing.png")
    #expect(fixture.resolver.storeCustom(imageAt: missing, for: fixture.project.id) == false)
    #expect(!FileManager.default.fileExists(atPath: fixture.iconURL.path))
}

// MARK: - Removing the icon (KTD3)

@Test func removeDeletesTheStoredIcon() throws {
    let fixture = try makeFixture()
    defer { fixture.cleanUp() }
    try fixture.writeExistingIcon(try makePNG(width: 128, height: 128))
    fixture.resolver.remove(fixture.project.id)
    #expect(!FileManager.default.fileExists(atPath: fixture.iconURL.path))
}

@Test func removeWithoutAStoredIconDoesNothing() throws {
    let fixture = try makeFixture()
    defer { fixture.cleanUp() }
    fixture.resolver.remove(fixture.project.id)
    #expect(!FileManager.default.fileExists(atPath: fixture.iconURL.path))
}
