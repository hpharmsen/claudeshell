import Foundation
import Testing
@testable import ClaudeshellCore

/// Records every call and answers with a fixed remote, or throws when there is none.
private final class RemoteStub: @unchecked Sendable {
    private let lock = NSLock()
    private let remote: String?
    private var log: [(program: String, arguments: [String], directory: URL)] = []

    init(remote: String?) { self.remote = remote }

    var calls: [(program: String, arguments: [String], directory: URL)] { lock.withLock { log } }

    var run: ProcessRunner {
        { program, arguments, directory, _, _ in
            self.lock.withLock { self.log.append((program, arguments, directory)) }
            guard let remote = self.remote else { throw SubprocessError.failed(exitCode: 2, output: "") }
            return remote
        }
    }
}

/// Builds a project folder with the given files and returns its links as text, plus the stub that saw the calls.
private func links(folder: String = "voorbeeld", files: [String: String] = [:], website: String? = nil,
                   overrides: [LinkKind: String]? = nil, remote: String? = nil) async throws -> ([LinkKind: String], RemoteStub) {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let folder = root.appendingPathComponent(folder)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    for (name, contents) in files {
        try contents.write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    let project = Project(name: "Voorbeeld", path: folder.path, color: "#336699", website: website, linkOverrides: overrides)
    let stub = RemoteStub(remote: remote)
    return (await ProjectLinks.resolve(project, run: stub.run).mapValues(\.absoluteString), stub)
}

private let githubRemote = "git@github.com:gebruiker/repo.git\n"
private let runserver = "python manage.py runserver 8082\n"

// MARK: - Found links

@Test func projectWithoutAnySourceHasNoLinks() async throws {
    #expect(try await links().0.isEmpty)
}

@Test func websiteIsTheLiveLink() async throws {
    let found = try await links(files: ["CNAME": "www.voorbeeld.nl\n"], website: "https://voorbeeld.nl").0
    #expect(found == [.live: "https://voorbeeld.nl"])
}

@Test func firstGuessedDomainIsTheLiveLinkWithoutWebsite() async throws {
    #expect(try await links(files: ["CNAME": "www.voorbeeld.nl\n"]).0 == [.live: "https://www.voorbeeld.nl"])
}

@Test func folderNamedLikeADomainIsTheLiveLink() async throws {
    #expect(try await links(folder: "voorbeeld.nl").0 == [.live: "https://voorbeeld.nl"])
}

@Test func runlocalScriptYieldsTheLocalhostLink() async throws {
    #expect(try await links(files: ["runlocal.sh": runserver]).0 == [.localhost: "http://localhost:8082"])
}

@Test func githubRemoteYieldsTheGitLinkInHttpsForm() async throws {
    let (found, stub) = try await links(remote: githubRemote)
    #expect(found == [.git: "https://github.com/gebruiker/repo"])
    #expect(stub.calls.count == 1)
    #expect(stub.calls.first?.program == "/usr/bin/git")
    #expect(stub.calls.first?.arguments == ["remote", "get-url", "origin"])
    #expect(stub.calls.first?.directory.lastPathComponent == "voorbeeld")
}

@Test func deployRemoteYieldsNoGitLink() async throws {
    #expect(try await links(remote: "dokku@voorbeeld.nl:app\n").0.isEmpty)
}

@Test func allThreeLinksAreFoundTogether() async throws {
    let found = try await links(files: ["runlocal.sh": runserver], website: "https://voorbeeld.nl", remote: githubRemote).0
    #expect(found == [.live: "https://voorbeeld.nl", .localhost: "http://localhost:8082",
                      .git: "https://github.com/gebruiker/repo"])
}

// MARK: - Own links

@Test func ownLiveLinkWinsFromWebsite() async throws {
    let found = try await links(website: "https://voorbeeld.nl", overrides: [.live: "https://app.voorbeeld.nl/start"]).0
    #expect(found == [.live: "https://app.voorbeeld.nl/start"])
}

@Test func clearedLocalhostLinkYieldsNoLinkDespiteScript() async throws {
    #expect(try await links(files: ["runlocal.sh": runserver], overrides: [.localhost: ""]).0.isEmpty)
}

@Test func clearedLiveLinkYieldsNoLinkDespiteWebsite() async throws {
    #expect(try await links(website: "https://voorbeeld.nl", overrides: [.live: ""]).0.isEmpty)
}

@Test func ownGitLinkWinsFromRemoteWithoutAskingGit() async throws {
    let (found, stub) = try await links(overrides: [.git: "https://gitlab.com/gebruiker/ander"], remote: githubRemote)
    #expect(found == [.git: "https://gitlab.com/gebruiker/ander"])
    #expect(stub.calls.isEmpty)
}

@Test func clearedGitLinkYieldsNoLinkDespiteRemote() async throws {
    #expect(try await links(overrides: [.git: ""], remote: githubRemote).0.isEmpty)
}

@Test func ownLinkOfOneKindLeavesTheOthersFound() async throws {
    let found = try await links(files: ["runlocal.sh": runserver], overrides: [.live: "https://voorbeeld.nl"],
                                remote: githubRemote).0
    #expect(found == [.live: "https://voorbeeld.nl", .localhost: "http://localhost:8082",
                      .git: "https://github.com/gebruiker/repo"])
}
