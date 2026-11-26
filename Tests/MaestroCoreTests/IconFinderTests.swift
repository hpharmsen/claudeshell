import Foundation
import Testing
@testable import MaestroCore

/// Path with symlinks resolved, so `/var/...` and `/private/var/...` compare equal.
private func resolved(_ path: String) -> String {
    URL(fileURLWithPath: path).resolvingSymlinksInPath().path
}

/// Fresh temp folder holding the given empty files (paths relative to the folder).
private func makeFolder(_ files: [String]) throws -> String {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("maestro-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    for file in files {
        let url = root.appendingPathComponent(file)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: url)
    }
    return root.path
}

/// Candidates for a folder with the given files, as paths relative to that folder.
private func candidates(_ files: [String]) throws -> [String] {
    let root = try makeFolder(files)
    defer { try? FileManager.default.removeItem(atPath: root) }
    let found = IconFinder.candidates(in: root)
    // The API promises absolute paths.
    #expect(found.allSatisfy { $0.hasPrefix("/") })
    let prefix = resolved(root) + "/"
    return found.map { path in
        let full = resolved(path)
        return full.hasPrefix(prefix) ? String(full.dropFirst(prefix.count)) : path
    }
}

// MARK: Rank order

@Test func touchIconComesBeforeFaviconIco() throws {
    #expect(try candidates(["static/favicon.ico", "static/apple-touch-icon.png"])
        == ["static/apple-touch-icon.png", "static/favicon.ico"])
}

@Test func deepFaviconComesBeforeRootLogo() throws {
    #expect(try candidates(["logo.png", "assets/design/favicons/favicon-32x32.png"])
        == ["assets/design/favicons/favicon-32x32.png", "logo.png"])
}

@Test func icnsIsFoundAndComesAfterFaviconPng() throws {
    #expect(try candidates(["Support/AppIcon.icns", "web/img/favicon.png"])
        == ["web/img/favicon.png", "Support/AppIcon.icns"])
}

@Test func candidatesFollowTheFullRankOrder() throws {
    // One file per rank, highest first, all at the same depth.
    let ranked = [
        "apple-touch-icon-180x180.png",
        "favicon-mask.svg",
        "favicon-32x32.png",
        "android-chrome-192x192.png",
        "Sample.icns",
        "icon.svg",
        "icon.png",
        "favicon-old.ico",
        "logo.svg",
        "logo.png",
    ]
    #expect(try candidates(ranked.reversed()) == ranked)
}

// MARK: Ties within a rank

@Test func shallowestWinsWithinSameRank() throws {
    #expect(try candidates(["a/b/favicon.png", "z/favicon.png", "favicon.png"])
        == ["favicon.png", "z/favicon.png", "a/b/favicon.png"])
}

@Test func alphabeticalPathBreaksTieAtSameDepth() throws {
    #expect(try candidates(["web/favicon.png", "app/favicon.png", "app/favicon-16x16.png"])
        == ["app/favicon-16x16.png", "app/favicon.png", "web/favicon.png"])
}

// MARK: Matching names

@Test func fileNamesMatchCaseInsensitively() throws {
    #expect(try candidates(["FAVICON.PNG"]) == ["FAVICON.PNG"])
}

@Test func nonMatchingNamesAreNotFound() throws {
    // `Favicons` has no extension; the others only resemble a listed name.
    #expect(try candidates(["Favicons", "myicon.png", "icons.png", "logo-dark.png", "banner.png", "favicon.txt"]) == [])
}

// MARK: Skipped folders and depth

@Test func skippedFoldersAreNotSearched() throws {
    let files = [
        "node_modules/x/favicon.png",
        ".venv/favicon.png",
        ".git/favicon.png",
        "staticfiles/favicon.png",
        "venv/favicon.png",
        "build/favicon.png",
        "dist/favicon.png",
        "src/node_modules/favicon.png",
    ]
    #expect(try candidates(files) == [])
}

@Test func searchStopsAtFiveFoldersDeep() throws {
    #expect(try candidates(["a/b/c/d/e/favicon.png", "g/h/i/j/k/l/favicon.png"])
        == ["a/b/c/d/e/favicon.png"])
}

// MARK: Nothing to find

@Test func emptyFolderGivesNoCandidates() throws {
    #expect(try candidates([]) == [])
}

@Test func missingFolderGivesNoCandidates() {
    let missing = FileManager.default.temporaryDirectory
        .appendingPathComponent("maestro-tests-\(UUID().uuidString)").path
    #expect(IconFinder.candidates(in: missing) == [])
}
