import Foundation

/// The step of the hp workflow a project is in, with the document that step follows from.
public struct WorkflowStep: Equatable, Sendable {
    public enum Kind: Sendable { case requirements, plan, build, bugfix, handoff }

    public let kind: Kind
    /// The file name of the plan, requirements document or handoff, or the branch name of a worktree.
    public let document: String

    /// Runs git in the project folder; nil when git fails.
    private typealias Git = ([String]) async -> String?

    /// The first step that fits, in the order handoff, worktree, plan, requirements; nil without traces of the workflow.
    public static func detect(in folder: URL, run: ProcessRunner) async -> WorkflowStep? {
        let docs = folder.appendingPathComponent("docs")
        if hasOpenTask(text(of: docs.appendingPathComponent("handoff/README.md"))) {
            return WorkflowStep(kind: .handoff, document: "README.md")
        }
        func git(_ arguments: [String]) async -> String? { try? await run("/usr/bin/git", arguments, folder, nil, 10) }
        // Git failing here means the folder is no repository.
        let worktrees = await git(["worktree", "list", "--porcelain"])
        if let worktrees, let branch = await branchWithOwnCommits(worktrees, git) {
            return WorkflowStep(kind: branch.hasPrefix("fix/") ? .bugfix : .build, document: branch)
        }
        let plans = names(in: docs.appendingPathComponent("plans"), suffix: "-plan.md")
        let frontmatter = { (plan: String) in WorkflowStep.frontmatter(text(of: docs.appendingPathComponent("plans/\(plan)"))) }
        if let plan = plans.last {
            let status = (frontmatter(plan)["status"] ?? "").trimmingCharacters(in: .init(charactersIn: "\"' ")).lowercased()
            let finished = ["completed", "complete", "done", "uitgevoerd", "superseded"].contains(status)
            // Without a repository nobody can tell whether the plan is built, and then it gives no label.
            let built = finished ? true : worktrees == nil ? nil : await isBuilt("docs/plans/\(plan)", git)
            if built == false { return WorkflowStep(kind: .plan, document: plan) }
        }
        let requirements = names(in: docs.appendingPathComponent("brainstorms"), suffix: "-requirements.md")
        guard let date = requirements.last?.prefix(10) else { return nil }
        // Only the requirements of the newest date count; the highest name without a plan gets the label.
        let open = requirements.last { name in
            let topic = name.dropFirst(11).dropLast("-requirements.md".count)
            return name.hasPrefix(date) && !plans.contains { plan in
                !topic.isEmpty && plan.contains(topic) && plan.prefix(10) >= date || (frontmatter(plan)["origin"] ?? "").contains(name)
            }
        }
        return open.map { WorkflowStep(kind: .requirements, document: $0) }
    }

    /// Whether the task table of a handoff has a row whose status starts with `todo`, `doing` or `blocked`.
    private static func hasOpenTask(_ handoff: String) -> Bool {
        let rows = handoff.components(separatedBy: .newlines).map { line in
            line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        }
        // A line without a pipe is no table row, whatever it says.
        guard let header = rows.firstIndex(where: { $0.count > 1 && $0.contains("status") }),
              let column = rows[header].firstIndex(of: "status") else { return false }
        return rows[(header + 1)...].prefix { $0.count > 1 }.contains { row in
            guard row.count > column, let word = row[column].split(whereSeparator: { !$0.isLetter }).first else { return false }
            return ["todo", "doing", "blocked"].contains(String(word))
        }
    }

    /// The branch of the first extra worktree that has commits HEAD misses; reads `git worktree list --porcelain`.
    private static func branchWithOwnCommits(_ worktrees: String, _ git: Git) async -> String? {
        let prefix = "branch refs/heads/"
        // The first block is the main worktree; a worktree whose folder is gone is marked prunable.
        let branches = worktrees.components(separatedBy: "\n\n").dropFirst().compactMap { block -> Substring? in
            let lines = block.split(separator: "\n")
            return lines.contains { $0.hasPrefix("prunable") } ? nil : lines.first { $0.hasPrefix(prefix) }?.dropFirst(prefix.count)
        }
        guard !branches.isEmpty, let unmerged = await git(["branch", "--no-merged", "HEAD", "--format=%(refname)"]) else { return nil }
        let own = Set(unmerged.split(separator: "\n").map { $0.dropFirst("refs/heads/".count) })
        return branches.first(where: own.contains).map(String.init)
    }

    /// Whether a commit touches something outside `docs/` since the plan was added; nil when git ignores the plan.
    private static func isBuilt(_ plan: String, _ git: Git) async -> Bool? {
        let added = (await git(["log", "-1", "--diff-filter=A", "--format=%H", "--", plan]) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // `check-ignore` succeeds for an ignored file; a plan that is merely not committed yet is not built.
        guard !added.isEmpty else { return await git(["check-ignore", "-q", plan]) == nil ? false : nil }
        // `^@` names the parents of the commit, so the commit that added the plan counts too.
        let building = await git(["log", "-1", "--format=%H", "--invert-grep", "--grep=^publish", "HEAD", "--not", "\(added)^@",
                                  "--", ".", ":(exclude)docs"])
        return building?.isEmpty == false
    }

    /// The fields between the first two `---` lines of a document, when it starts with one.
    private static func frontmatter(_ document: String) -> [String: String] {
        let lines = document.components(separatedBy: .newlines)
        guard lines.first == "---" else { return [:] }
        let fields = lines.dropFirst().prefix { $0 != "---" }.compactMap { line -> (String, String)? in
            let parts = line.split(separator: ":", maxSplits: 1)
            return parts.count == 2 ? (String(parts[0]), parts[1].trimmingCharacters(in: .whitespaces)) : nil
        }
        return Dictionary(fields, uniquingKeysWith: { first, _ in first })
    }

    /// The text of a file, empty when it cannot be read.
    private static func text(of file: URL) -> String {
        (try? String(contentsOf: file, encoding: .utf8)) ?? ""
    }

    /// The file names in a folder with a suffix, sorted; the names start with a date, so the last is the newest.
    private static func names(in folder: URL, suffix: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(suffix) }.sorted()
    }
}
