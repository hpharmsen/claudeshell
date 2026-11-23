import Foundation
import Testing
@testable import ClaudeshellCore

// MARK: - Helpers

/// A project folder in its own temp folder, optionally a repository with its own identity.
private struct Fixture {
    let root: URL
    var folder: URL { root.appendingPathComponent("project") }

    /// Runs git in the project folder, or in another folder.
    @discardableResult func git(_ arguments: String..., in other: URL? = nil) async throws -> String {
        try await Subprocess.run("/usr/bin/git", arguments, other ?? folder, nil, 10)
    }

    /// Writes a file with a path relative to the project folder, or to another folder.
    func write(_ path: String, _ text: String = "inhoud\n", in other: URL? = nil) throws {
        let file = (other ?? folder).appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: file)
    }

    /// Commits everything in the project folder, or in another worktree.
    func commit(_ message: String = "wijziging", in other: URL? = nil) async throws {
        try await git("add", "-A", in: other)
        try await git("commit", "-m", message, in: other)
    }

    /// Adds a second worktree on a new branch, with one commit of its own when asked.
    @discardableResult func addWorktree(_ branch: String, ownCommit: Bool) async throws -> URL {
        let worktree = root.appendingPathComponent(branch.replacingOccurrences(of: "/", with: "-"))
        try await git("worktree", "add", "-b", branch, worktree.path)
        if ownCommit {
            try write("src/nieuw.py", in: worktree)
            try await commit("werk op \(branch)", in: worktree)
        }
        return worktree
    }

    /// The step of the project folder, with real git.
    func step() async -> WorkflowStep? { await WorkflowStep.detect(in: folder, run: Subprocess.run) }
}

/// Runs a test on a fresh project folder and removes it afterwards; a repository starts with one commit.
private func withProject(repo: Bool = true, _ body: (Fixture) async throws -> Void) async throws {
    let fixture = Fixture(root: try makeTempDir())
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    try FileManager.default.createDirectory(at: fixture.folder, withIntermediateDirectories: true)
    if repo {
        try await fixture.git("init", "--initial-branch=main")
        try await fixture.git("config", "user.name", "Test Gebruiker")
        try await fixture.git("config", "user.email", "test@voorbeeld.nl")
        try await fixture.git("config", "commit.gpgsign", "false")
        try fixture.write("README.md")
        try await fixture.commit("begin")
    }
    try await body(fixture)
}

/// Passes every call on to real git and records the arguments.
private final class RunLog: @unchecked Sendable {
    private let lock = NSLock()
    private var log: [[String]] = []

    var calls: [[String]] { lock.withLock { log } }

    var run: ProcessRunner {
        { program, arguments, directory, input, timeout in
            self.lock.withLock { self.log.append(arguments) }
            return try await Subprocess.run(program, arguments, directory, input, timeout)
        }
    }
}

private let brainstorm = "docs/brainstorms/2026-01-05-voorbeeld-requirements.md"
private let plan = "docs/plans/2026-01-06-001-feature-voorbeeld-plan.md"
private let planName = "2026-01-06-001-feature-voorbeeld-plan.md"
private let completed = "---\nstatus: completed\n---\n# Plan\n"

/// The text of a handoff with one task row per status.
private func handoff(_ statuses: String..., task: String = "Strook bouwen") -> String {
    let rows = statuses.enumerated().map { "| \($0 + 1) | \(task) | \($1) | - | `src/app.py` |" }
    return (["# Handoff", "", "| # | Taak | Status | Hangt af van | Raakt |", "|---|------|--------|--------------|-------|"]
        + rows + ["", "Verder niets."]).joined(separator: "\n")
}

private let openHandoff = WorkflowStep(kind: .handoff, document: "README.md")
private let unbuiltPlan = WorkflowStep(kind: .plan, document: planName)

// MARK: - No traces

@Test func anEmptyFolderHasNoStep() async throws {
    try await withProject(repo: false) { #expect(await $0.step() == nil) }
}

@Test func aFolderThatDoesNotExistHasNoStep() async {
    #expect(await WorkflowStep.detect(in: URL(fileURLWithPath: "/bestaat/niet"), run: Subprocess.run) == nil)
}

@Test func aRepoWithoutDocsHasNoStep() async throws {
    try await withProject { #expect(await $0.step() == nil) }
}

@Test func aRepoWithoutCommitsHasNoStep() async throws {
    try await withProject(repo: false) { project in
        try await project.git("init", "--initial-branch=main")
        #expect(await project.step() == nil)
    }
}

// MARK: - Requirements

@Test func requirementsWithoutAPlan() async throws {
    try await withProject(repo: false) { project in
        try project.write(brainstorm)
        #expect(await project.step() == WorkflowStep(kind: .requirements, document: "2026-01-05-voorbeeld-requirements.md"))
    }
}

@Test func anUncommittedPlanWithItsOriginIsNotBuilt() async throws {
    try await withProject { project in
        try project.write(brainstorm)
        try project.write(plan, "---\norigin: \(brainstorm)\n---\n# Plan\n")
        #expect(await project.step() == unbuiltPlan)
    }
}

@Test func anOriginWithTwoFileNamesCoversBothRequirements() async throws {
    try await withProject(repo: false) { project in
        try project.write("docs/brainstorms/2026-01-05-appel-requirements.md")
        try project.write("docs/brainstorms/2026-01-05-peer-requirements.md")
        let origin = "docs/brainstorms/2026-01-05-appel-requirements.md, docs/brainstorms/2026-01-05-peer-requirements.md"
        try project.write("docs/plans/2026-01-06-001-feature-fruit-plan.md", "---\norigin: \(origin)\nstatus: completed\n---\n")
        #expect(await project.step() == nil)
    }
}

@Test func aPlanWithTheTopicInItsNameAndTheSameDateBelongsToTheRequirements() async throws {
    try await withProject(repo: false) { project in
        try project.write(brainstorm)
        try project.write("docs/plans/2026-01-05-001-feature-voorbeeld-plan.md", completed)
        #expect(await project.step() == nil)
    }
}

@Test func anOlderPlanWithTheTopicInItsNameDoesNotBelongToTheRequirements() async throws {
    try await withProject(repo: false) { project in
        try project.write(brainstorm)
        try project.write("docs/plans/2026-01-04-001-feature-voorbeeld-plan.md", completed)
        #expect(await project.step()?.kind == .requirements)
    }
}

@Test func anOlderPlanOnAnotherTopicLeavesTheRequirementsWithoutPlan() async throws {
    try await withProject(repo: false) { project in
        try project.write(brainstorm)
        try project.write("docs/plans/2026-01-02-001-feature-peer-plan.md", completed)
        #expect(await project.step() == WorkflowStep(kind: .requirements, document: "2026-01-05-voorbeeld-requirements.md"))
    }
}

@Test func ofTwoRequirementsOfOneDayTheOneWithoutPlanGetsTheLabel() async throws {
    try await withProject(repo: false) { project in
        try project.write("docs/brainstorms/2026-01-05-appel-requirements.md")
        try project.write("docs/brainstorms/2026-01-05-peer-requirements.md")
        try project.write("docs/plans/2026-01-06-001-feature-peer-plan.md", completed)
        #expect(await project.step() == WorkflowStep(kind: .requirements, document: "2026-01-05-appel-requirements.md"))
    }
}

@Test func olderRequirementsWithoutPlanDoNotCount() async throws {
    try await withProject(repo: false) { project in
        try project.write("docs/brainstorms/2026-01-03-appel-requirements.md")
        try project.write("docs/brainstorms/2026-01-05-peer-requirements.md")
        try project.write("docs/plans/2026-01-06-001-feature-peer-plan.md", completed)
        #expect(await project.step() == nil)
    }
}

@Test func otherFilesInBrainstormsAreNoRequirements() async throws {
    try await withProject(repo: false) { project in
        try project.write("docs/brainstorms/2026-01-05-voorbeeld-notities.md")
        #expect(await project.step() == nil)
    }
}

// MARK: - Plan

@Test func aCommittedPlanWithoutLaterCommitsIsNotBuilt() async throws {
    try await withProject { project in
        try project.write(plan)
        try await project.commit("docs: plan")
        #expect(await project.step() == unbuiltPlan)
    }
}

@Test func aLaterCommitInsideDocsDoesNotBuildThePlan() async throws {
    try await withProject { project in
        try project.write(plan)
        try await project.commit("docs: plan")
        try project.write("docs/architecture.md")
        try await project.commit("docs: architectuur")
        #expect(await project.step() == unbuiltPlan)
    }
}

@Test func aLaterCommitOutsideDocsBuildsThePlan() async throws {
    try await withProject { project in
        try project.write(plan)
        try await project.commit("docs: plan")
        try project.write("src/app.py")
        try await project.commit("feat: app")
        #expect(await project.step() == nil)
    }
}

@Test func aLaterPublishCommitDoesNotBuildThePlan() async throws {
    try await withProject { project in
        try project.write(plan)
        try await project.commit("docs: plan")
        try project.write("pyproject.toml")
        try await project.commit("publish ma 5 jan")
        #expect(await project.step() == unbuiltPlan)
    }
}

@Test func aPlanCommittedTogetherWithCodeIsBuilt() async throws {
    try await withProject { project in
        try project.write(plan)
        try project.write("src/app.py")
        try await project.commit("feat: plan en app")
        #expect(await project.step() == nil)
    }
}

@Test func aPlanInTheFirstCommitOfARepo() async throws {
    try await withProject(repo: false) { project in
        try await project.git("init", "--initial-branch=main")
        try await project.git("config", "user.name", "Test Gebruiker")
        try await project.git("config", "user.email", "test@voorbeeld.nl")
        try await project.git("config", "commit.gpgsign", "false")
        try project.write(plan)
        #expect(await project.step() == unbuiltPlan)
        try await project.commit("docs: plan")
        #expect(await project.step() == unbuiltPlan)
        try project.write("src/app.py")
        try await project.git("add", "-A")
        try await project.git("commit", "--amend", "-m", "feat: plan en app")
        #expect(await project.step() == nil)
    }
}

@Test func aCommitBeforeThePlanDoesNotBuildIt() async throws {
    try await withProject { project in
        try project.write("src/app.py")
        try await project.commit("feat: app")
        try project.write(plan)
        try await project.commit("docs: plan")
        #expect(await project.step() == unbuiltPlan)
    }
}

@Test func anUncommittedPlanWithACompletedStatusIsBuilt() async throws {
    try await withProject { project in
        try project.write(plan, completed)
        #expect(await project.step() == nil)
    }
}

@Test func everyFinishedStatusCountsAsBuilt() async throws {
    try await withProject { project in
        for status in ["complete", "done", "uitgevoerd", "superseded", "Completed", "\"done\""] {
            try project.write(plan, "---\ntitle: Voorbeeld\nstatus: \(status)\n---\n")
            #expect(await project.step() == nil, "status \(status)")
        }
        try project.write(plan, "---\nstatus: active\n---\n")
        #expect(await project.step() == unbuiltPlan)
    }
}

@Test func aStatusOutsideTheFrontmatterDoesNotCount() async throws {
    try await withProject { project in
        try project.write(plan, "# Plan\n\nstatus: completed\n")
        #expect(await project.step() == unbuiltPlan)
        try project.write(plan, "---\ntitle: Voorbeeld\n---\n\nstatus: completed\n")
        #expect(await project.step() == unbuiltPlan)
    }
}

@Test func onlyTheNewestPlanCounts() async throws {
    try await withProject { project in
        try project.write("docs/plans/2026-01-02-001-feature-appel-plan.md")
        try project.write(plan, completed)
        #expect(await project.step() == nil)
    }
}

@Test func theNewestPlanIsTheOneWithTheHighestNameNotTheLatestChange() async throws {
    try await withProject { project in
        try project.write(plan)
        try project.write("docs/plans/2026-01-02-001-feature-appel-plan.md", completed)
        let old = project.folder.appendingPathComponent(plan)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -86_400)], ofItemAtPath: old.path)
        #expect(await project.step() == unbuiltPlan)
    }
}

@Test func aChangelogInThePlansFolderIsNoPlan() async throws {
    try await withProject { project in
        try project.write("docs/plans/2026-01-06-01-voorbeeld-dev-changelog.md")
        #expect(await project.step() == nil)
    }
}

@Test func aPlanInIgnoredDocsHasNoStep() async throws {
    try await withProject { project in
        try project.write(".gitignore", "docs/\n")
        try await project.commit("negeer docs")
        try project.write(plan)
        #expect(await project.step() == nil)
    }
}

@Test func aPlanOutsideARepoHasNoStep() async throws {
    try await withProject(repo: false) { project in
        try project.write(plan)
        #expect(await project.step() == nil)
    }
}

// MARK: - Worktrees

@Test func aWorktreeWithItsOwnCommitIsABuild() async throws {
    try await withProject { project in
        try await project.addWorktree("feat/voorbeeld", ownCommit: true)
        #expect(await project.step() == WorkflowStep(kind: .build, document: "feat/voorbeeld"))
    }
}

@Test func aWorktreeOnAFixBranchIsABugfix() async throws {
    try await withProject { project in
        try await project.addWorktree("fix/voorbeeld", ownCommit: true)
        #expect(await project.step() == WorkflowStep(kind: .bugfix, document: "fix/voorbeeld"))
    }
}

@Test func aWorktreeWithoutOwnCommitsHasNoStep() async throws {
    try await withProject { project in
        try await project.addWorktree("feat/voorbeeld", ownCommit: false)
        #expect(await project.step() == nil)
    }
}

@Test func aMergedWorktreeHasNoStep() async throws {
    try await withProject { project in
        try await project.addWorktree("feat/voorbeeld", ownCommit: true)
        try await project.git("merge", "--no-ff", "-m", "merge feat/voorbeeld", "feat/voorbeeld")
        #expect(await project.step() == nil)
    }
}

@Test func aFreshWorktreeFallsBackToTheUnbuiltPlan() async throws {
    try await withProject { project in
        try project.write(plan)
        try await project.commit("docs: plan")
        try await project.addWorktree("feat/voorbeeld", ownCommit: false)
        #expect(await project.step() == unbuiltPlan)
    }
}

@Test func aWorktreeWithOwnCommitsGoesBeforeAnUnbuiltPlan() async throws {
    try await withProject { project in
        try project.write(plan)
        try await project.commit("docs: plan")
        try await project.addWorktree("feat/voorbeeld", ownCommit: true)
        #expect(await project.step() == WorkflowStep(kind: .build, document: "feat/voorbeeld"))
    }
}

@Test func aDetachedWorktreeHasNoStep() async throws {
    try await withProject { project in
        let worktree = try await project.addWorktree("feat/voorbeeld", ownCommit: true)
        try await project.git("checkout", "--detach", in: worktree)
        #expect(await project.step() == nil)
    }
}

@Test func aBranchWithOwnCommitsButNoWorktreeHasNoStep() async throws {
    try await withProject { project in
        try await project.addWorktree("feat/appel", ownCommit: false)
        try await project.git("checkout", "-b", "feat/peer")
        try project.write("src/peer.py")
        try await project.commit("feat: peer")
        try await project.git("checkout", "main")
        #expect(await project.step() == nil)
    }
}

@Test func ofTwoWorktreesTheOneWithOwnCommitsGetsTheLabel() async throws {
    try await withProject { project in
        try await project.addWorktree("feat/appel", ownCommit: false)
        try await project.addWorktree("fix/peer", ownCommit: true)
        #expect(await project.step() == WorkflowStep(kind: .bugfix, document: "fix/peer"))
    }
}

// MARK: - Handoff

@Test func aHandoffWithAnOpenTaskIsOpen() async throws {
    for status in ["doing", "doing: wacht op antwoord", "blocked", "todo", "Todo", "**doing**"] {
        try await withProject(repo: false) { project in
            try project.write("docs/handoff/README.md", handoff("done", status))
            #expect(await project.step() == openHandoff, "status \(status)")
        }
    }
}

@Test func aDoneTaskWithTodoInItsNameIsNotOpen() async throws {
    try await withProject(repo: false) { project in
        try project.write("docs/handoff/README.md", handoff("done", task: "todo-lijst opschonen"))
        #expect(await project.step() == nil)
    }
}

@Test func aHandoffWithOnlyDoneTasksLetsTheNextStepsDecide() async throws {
    try await withProject { project in
        try project.write("docs/handoff/README.md", handoff("done", "done: gemerged"))
        #expect(await project.step() == nil)
        try project.write(plan)
        #expect(await project.step() == unbuiltPlan)
    }
}

@Test func theStatusColumnIsFoundByItsHeader() async throws {
    try await withProject(repo: false) { project in
        let table = "| Status | Taak |\n|---|---|\n| done | todo |\n"
        try project.write("docs/handoff/README.md", table)
        #expect(await project.step() == nil)
        try project.write("docs/handoff/README.md", table + "| blocked | wachten |\n")
        #expect(await project.step() == openHandoff)
    }
}

@Test func aHandoffWithoutATableIsNotOpen() async throws {
    try await withProject(repo: false) { project in
        try project.write("docs/handoff/README.md", "# Handoff\n\nStatus: todo\n\nNog doing en blocked.\n")
        #expect(await project.step() == nil)
    }
}

@Test func anOpenHandoffGoesBeforeAnUnbuiltPlan() async throws {
    try await withProject { project in
        try project.write(plan)
        try project.write("docs/handoff/README.md", handoff("doing"))
        #expect(await project.step() == openHandoff)
    }
}

@Test func anOpenHandoffGoesBeforeAWorktreeWithOwnCommits() async throws {
    try await withProject { project in
        try await project.addWorktree("feat/voorbeeld", ownCommit: true)
        try project.write("docs/handoff/README.md", handoff("todo"))
        #expect(await project.step() == openHandoff)
    }
}

// MARK: - The number of git calls

@Test func anOpenHandoffNeedsNoGit() async throws {
    try await withProject { project in
        try project.write("docs/handoff/README.md", handoff("doing"))
        let log = RunLog()
        #expect(await WorkflowStep.detect(in: project.folder, run: log.run) == openHandoff)
        #expect(log.calls.isEmpty)
    }
}

@Test func aRepoWithoutPlanAndWorktreesNeedsOneGitCall() async throws {
    try await withProject { project in
        try project.write(brainstorm)
        let log = RunLog()
        #expect(await WorkflowStep.detect(in: project.folder, run: log.run)?.kind == .requirements)
        #expect(log.calls == [["worktree", "list", "--porcelain"]])
    }
}

@Test func aBuiltPlanNeedsThreeGitCalls() async throws {
    try await withProject { project in
        try project.write(plan)
        try project.write("src/app.py")
        try await project.commit("feat: plan en app")
        let log = RunLog()
        #expect(await WorkflowStep.detect(in: project.folder, run: log.run) == nil)
        #expect(log.calls.count == 3)
    }
}
