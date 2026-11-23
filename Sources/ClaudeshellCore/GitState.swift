import Foundation

/// Where the repository of a project stands: branch, changed files, unpushed commits and the commit of HEAD.
public struct GitState: Sendable, Equatable {
    /// What git reports as branch when HEAD is detached.
    public static let detachedBranch = "(detached)"

    /// The name of the branch, or `detachedBranch`.
    public let branch: String
    /// The number of changed files, new ones included.
    public let changedFiles: Int
    /// The number of commits the upstream misses; nil when the branch has no upstream.
    public let unpushed: Int?
    /// The commit of HEAD; nil in a repository without commits.
    public let head: String?

    public init(branch: String, changedFiles: Int, unpushed: Int?, head: String?) {
        self.branch = branch
        self.changedFiles = changedFiles
        self.unpushed = unpushed
        self.head = head
    }

    /// The state of the repository in a folder; nil when git fails, which means the folder is no repository.
    public static func fetch(in folder: URL, run: ProcessRunner) async -> GitState? {
        // Without --no-optional-locks the status holds index.lock for a moment, and a commit at that moment fails.
        let arguments = ["--no-optional-locks", "status", "--porcelain=v2", "--branch"]
        return (try? await run("/usr/bin/git", arguments, folder, nil, 10)).map(parse)
    }

    /// Reads the output of `git status --porcelain=v2 --branch`.
    public static func parse(_ output: String) -> GitState {
        var headers: [Substring: Substring] = [:]
        var changedFiles = 0
        for line in output.split(separator: "\n") {
            guard line.hasPrefix("# ") else { changedFiles += 1; continue }
            let parts = line.dropFirst(2).split(separator: " ", maxSplits: 1)
            if parts.count == 2 { headers[parts[0]] = parts[1] }
        }
        // `branch.ab` reads `+2 -0`: two commits ahead of the upstream and none behind.
        let ahead = headers["branch.ab"]?.split(separator: " ").first { $0.hasPrefix("+") }
        let oid = headers["branch.oid"].map(String.init)
        return GitState(branch: String(headers["branch.head"] ?? ""), changedFiles: changedFiles,
                        unpushed: ahead.flatMap { Int($0.dropFirst()) }, head: oid == "(initial)" ? nil : oid)
    }

    /// The web page of a remote, without credentials and without `.git`.
    /// Nil for a remote with fewer than two path parts, such as those of Heroku and Dokku, and for a local path.
    public static func browsableURL(fromRemote remote: String) -> URL? {
        let remote = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        var web = URLComponents()
        web.scheme = "https"
        let path: String
        if remote.contains("://") {
            guard let parts = URLComponents(string: remote) else { return nil }
            web.host = parts.host
            // The port of an ssh remote says nothing about the website; that of a web remote does.
            if let scheme = parts.scheme?.lowercased(), ["http", "https"].contains(scheme) {
                web.scheme = scheme
                web.port = parts.port
            }
            path = parts.path
        } else {
            // The scp form: `git@host:gebruiker/repo.git`.
            let halves = remote.split(separator: ":", maxSplits: 1)
            guard halves.count == 2 else { return nil }
            web.host = halves[0].split(separator: "@").last.map(String.init)
            path = String(halves[1])
        }
        var names = path.split(separator: "/")
        guard web.host?.isEmpty == false, names.count >= 2, let last = names.last else { return nil }
        if last.hasSuffix(".git") { names[names.count - 1] = last.dropLast(4) }
        web.path = "/" + names.joined(separator: "/")
        return web.url
    }
}
