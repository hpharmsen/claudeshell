import Foundation
import Testing
@testable import MaestroCore

// MARK: - Helpers

/// Runs git in a folder and returns its output.
@discardableResult private func git(_ arguments: String..., in folder: URL) async throws -> String {
    try await Subprocess.run("/usr/bin/git", arguments, folder, nil, 10)
}

/// A new repository in a subfolder of `root`, with its own identity so the git config of the machine does not matter.
private func makeRepo(_ name: String = "repo", in root: URL, bare: Bool = false) async throws -> URL {
    let folder = root.appendingPathComponent(name)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    if bare {
        try await git("init", "--bare", "--initial-branch=main", in: folder)
    } else {
        try await git("init", "--initial-branch=main", in: folder)
    }
    try await git("config", "user.name", "Test Gebruiker", in: folder)
    try await git("config", "user.email", "test@voorbeeld.nl", in: folder)
    try await git("config", "commit.gpgsign", "false", in: folder)
    return folder
}

/// Writes a file and commits everything.
private func commit(_ file: String, in repo: URL) async throws {
    try Data(file.utf8).write(to: repo.appendingPathComponent(file))
    try await git("add", "-A", in: repo)
    try await git("commit", "-m", "voeg \(file) toe", in: repo)
}

/// Records every call and answers with a fixed text, or throws when there is none.
private final class RunStub: @unchecked Sendable {
    private let lock = NSLock()
    private let answer: String?
    private var log: [(program: String, arguments: [String], directory: URL)] = []

    init(answer: String?) { self.answer = answer }

    var calls: [(program: String, arguments: [String], directory: URL)] { lock.withLock { log } }

    var run: ProcessRunner {
        { program, arguments, directory, _, _ in
            self.lock.withLock { self.log.append((program, arguments, directory)) }
            guard let answer = self.answer else { throw SubprocessError.failed(exitCode: 128, output: "") }
            return answer
        }
    }
}

private let oid = "0123456789abcdef0123456789abcdef01234567"

// MARK: - Parser

@Test func parseReadsBranchChangedFilesAndUnpushedCommits() {
    let state = GitState.parse("""
        # branch.oid \(oid)
        # branch.head main
        # branch.upstream origin/main
        # branch.ab +2 -0
        1 .M N... 100644 100644 100644 \(oid) \(oid) README.md
        1 A. N... 000000 100644 100644 \(oid) \(oid) nieuw.txt
        ? los.txt

        """)
    #expect(state == GitState(branch: "main", changedFiles: 3, unpushed: 2, head: oid))
}

@Test func parseWithoutUpstreamHasNoUnpushedCount() {
    let state = GitState.parse("# branch.oid \(oid)\n# branch.head main\n")
    #expect(state == GitState(branch: "main", changedFiles: 0, unpushed: nil, head: oid))
}

@Test func parseWithAGoneUpstreamHasNoUnpushedCount() {
    // An upstream that was deleted on the remote is named, but git leaves out the counts.
    let state = GitState.parse("# branch.oid \(oid)\n# branch.head main\n# branch.upstream origin/main\n")
    #expect(state.unpushed == nil)
}

@Test func parseCountsOnlyTheCommitsAhead() {
    #expect(GitState.parse("# branch.head main\n# branch.ab +0 -4\n").unpushed == 0)
    #expect(GitState.parse("# branch.head main\n# branch.ab +12 -3\n").unpushed == 12)
}

@Test func parseOfADetachedHead() {
    let state = GitState.parse("# branch.oid \(oid)\n# branch.head (detached)\n")
    #expect(state.branch == "(detached)")
    #expect(state.head == oid)
    #expect(state.unpushed == nil)
}

@Test func parseOfAFreshRepoHasNoCommit() {
    let state = GitState.parse("# branch.oid (initial)\n# branch.head main\n? eerste.txt\n")
    #expect(state == GitState(branch: "main", changedFiles: 1, unpushed: nil, head: nil))
}

@Test func parseCountsEveryKindOfChangeOnce() {
    let state = GitState.parse("""
        # branch.oid \(oid)
        # branch.head main
        1 .M N... 100644 100644 100644 \(oid) \(oid) gewijzigd.txt
        2 R. N... 100644 100644 100644 \(oid) \(oid) R100 nieuw naam.txt\toud naam.txt
        u UU N... 100644 100644 100644 100644 \(oid) \(oid) \(oid) conflict.txt
        ? los.txt
        """)
    #expect(state.changedFiles == 4)
}

@Test func parseKeepsABranchNameWithASlash() {
    #expect(GitState.parse("# branch.head feature/project-strook\n").branch == "feature/project-strook")
}

@Test func parseOfEmptyOutput() {
    #expect(GitState.parse("") == GitState(branch: "", changedFiles: 0, unpushed: nil, head: nil))
}

// MARK: - Fetching through the injected runner

@Test func fetchCallsGitWithoutOptionalLocks() async {
    let stub = RunStub(answer: "# branch.oid \(oid)\n# branch.head main\n")
    let folder = URL(fileURLWithPath: "/tmp/project")
    let state = await GitState.fetch(in: folder, run: stub.run)
    #expect(state?.branch == "main")
    #expect(stub.calls.count == 1)
    #expect(stub.calls.first?.program == "/usr/bin/git")
    #expect(stub.calls.first?.arguments == ["--no-optional-locks", "status", "--porcelain=v2", "--branch"])
    #expect(stub.calls.first?.directory == folder)
}

@Test func fetchReturnsNilWhenGitFails() async {
    #expect(await GitState.fetch(in: URL(fileURLWithPath: "/tmp/project"), run: RunStub(answer: nil).run) == nil)
}

// MARK: - Real repositories

@Test func aFolderThatIsNoRepoHasNoState() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    #expect(await GitState.fetch(in: root, run: Subprocess.run) == nil)
}

@Test func aFolderThatDoesNotExistHasNoState() async {
    #expect(await GitState.fetch(in: URL(fileURLWithPath: "/bestaat/niet"), run: Subprocess.run) == nil)
}

@Test func aFreshRepoHasABranchAndNoCommit() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let repo = try await makeRepo(in: root)
    #expect(await GitState.fetch(in: repo, run: Subprocess.run) == GitState(branch: "main", changedFiles: 0, unpushed: nil, head: nil))
}

@Test func aNewFileCountsUntilItIsCommitted() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let repo = try await makeRepo(in: root)
    try await commit("eerste.txt", in: repo)

    try Data("nieuw".utf8).write(to: repo.appendingPathComponent("nieuw.txt"))
    let dirty = try #require(await GitState.fetch(in: repo, run: Subprocess.run))
    #expect(dirty.changedFiles == 1)
    #expect(dirty.branch == "main")

    try await git("add", "-A", in: repo)
    try await git("commit", "-m", "nieuw bestand", in: repo)
    let clean = try #require(await GitState.fetch(in: repo, run: Subprocess.run))
    #expect(clean.changedFiles == 0)
    #expect(clean.head == (try await git("rev-parse", "HEAD", in: repo)).trimmingCharacters(in: .newlines))
    #expect(clean.head != dirty.head)
}

@Test func aModifiedAndAStagedFileBothCount() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let repo = try await makeRepo(in: root)
    try await commit("eerste.txt", in: repo)
    try Data("anders".utf8).write(to: repo.appendingPathComponent("eerste.txt"))
    try Data("klaar".utf8).write(to: repo.appendingPathComponent("tweede.txt"))
    try await git("add", "tweede.txt", in: repo)
    #expect(await GitState.fetch(in: repo, run: Subprocess.run)?.changedFiles == 2)
}

@Test func aRepoWithoutRemoteHasNoUpstream() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let repo = try await makeRepo(in: root)
    try await commit("eerste.txt", in: repo)
    let state = try #require(await GitState.fetch(in: repo, run: Subprocess.run))
    #expect(state.unpushed == nil)
}

@Test func aLocalCommitOnTopOfOriginIsUnpushed() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let origin = try await makeRepo("origin.git", in: root, bare: true)
    let repo = try await makeRepo(in: root)
    try await commit("eerste.txt", in: repo)
    try await git("remote", "add", "origin", origin.path, in: repo)
    try await git("push", "--set-upstream", "origin", "main", in: repo)
    #expect(await GitState.fetch(in: repo, run: Subprocess.run)?.unpushed == 0)

    try await commit("tweede.txt", in: repo)
    #expect(await GitState.fetch(in: repo, run: Subprocess.run)?.unpushed == 1)
}

@Test func aDetachedHeadInARealRepo() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let repo = try await makeRepo(in: root)
    try await commit("eerste.txt", in: repo)
    try await git("checkout", "--detach", in: repo)
    let state = try #require(await GitState.fetch(in: repo, run: Subprocess.run))
    #expect(state.branch == GitState.detachedBranch)
    #expect(state.head != nil)
}

@Test func fetchingDoesNotLeaveAnIndexLock() async throws {
    let root = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: root) }
    let repo = try await makeRepo(in: root)
    try await commit("eerste.txt", in: repo)
    _ = await GitState.fetch(in: repo, run: Subprocess.run)
    #expect(!FileManager.default.fileExists(atPath: repo.appendingPathComponent(".git/index.lock").path))
}

// MARK: - Browsable URL

@Test func browsableURLOfRemotes() {
    let cases: [(remote: String, expected: String?)] = [
        ("git@github.com:gebruiker/repo.git", "https://github.com/gebruiker/repo"),
        ("git@github.com:gebruiker/repo", "https://github.com/gebruiker/repo"),
        ("https://naam:geheim@github.com/gebruiker/repo.git", "https://github.com/gebruiker/repo"),
        ("https://github.com/gebruiker/repo", "https://github.com/gebruiker/repo"),
        ("https://github.com/gebruiker/repo/", "https://github.com/gebruiker/repo"),
        ("ssh://git@voorbeeld.nl:2222/gebruiker/repo.git", "https://voorbeeld.nl/gebruiker/repo"),
        ("git://voorbeeld.nl/gebruiker/repo.git", "https://voorbeeld.nl/gebruiker/repo"),
        ("git@gitlab.com:groep/sub/repo.git", "https://gitlab.com/groep/sub/repo"),
        ("git@github.com:gebruiker/repo.git\n", "https://github.com/gebruiker/repo"),
        ("https://git.heroku.com/app.git", nil),
        ("dokku@voorbeeld.nl:app", nil),
        ("ssh://dokku@voorbeeld.nl:22/app", nil),
        ("/Users/gebruiker/repos/repo.git", nil),
        ("file:///Users/gebruiker/repos/repo.git", nil),
        ("", nil),
        ("  \n", nil),
    ]
    for (remote, expected) in cases {
        #expect(GitState.browsableURL(fromRemote: remote)?.absoluteString == expected, "remote: \(remote)")
    }
}
