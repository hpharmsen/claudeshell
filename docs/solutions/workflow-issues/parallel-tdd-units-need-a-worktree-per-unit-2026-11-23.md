---
title: Parallel TDD units in this Swift package need a worktree per unit
date: 2026-11-23
category: workflow-issues
module: build workflow
problem_type: workflow_issue
component: development_workflow
severity: medium
applies_when:
  - A plan has implementation units that its execution table marks as parallel
  - Each unit must land as a red test commit followed by the implementation
  - Subagents may not commit, only the orchestrating session does
tags: [swift-package, worktrees, subagents, tdd, red-commit, parallel-units]
---

# Parallel TDD units in this Swift package need a worktree per unit

## Context

The project strip was built from a plan with eight units, six of them in two parallel waves of three. Three rules pulled against each other:

- The units of a wave run in parallel, each by its own subagent.
- Every unit is test-first, and the test is committed red before the implementation.
- Subagents do not commit; only the orchestrating session does, otherwise they collide on `index.lock`.

The obvious setup, three subagents in the one feature worktree, does not work in this package. `Package.swift` has a single test target, `ClaudeshellCoreTests`, so `swift build --build-tests` compiles every test file at once. A test file of unit B that refers to a type that does not exist yet breaks the build for unit A too. No worker can run its own tests while a peer is half way, and parallel builds also wait on each other for the one `.build` folder.

## Guidance

Give every unit of a wave its own detached worktree, and let the orchestrator carry the files over.

1. Create one worktree per unit from the commit the wave starts on. `.worktrees/` is in `.gitignore`, so they stay out of the status.

   ```
   git worktree add --detach .worktrees/wave/u1 <base-sha>
   ```

2. Tell each subagent to work only in its own worktree, to run no git command that writes, to write the tests first and keep the failing build output, then to implement and run the full suite. Each worktree has its own `.build`, so the builds do not touch.

3. When a subagent is back, the orchestrator integrates that unit in the feature worktree, in two steps:
   - Copy only the test files in, run `swift build --build-tests`, see it fail on the missing types, and commit the tests. This is the red commit, with red evidence the orchestrator saw itself instead of took on trust.
   - Copy the source files in, run `swift test`, read the diff, and commit the implementation.

4. Remove the worktrees with `git worktree remove --force` once their files are compared with the feature tree, and create fresh ones on the new head for the next wave.

Units that the plan chains anyway (here the last two) can be written directly in the feature worktree. The red commit then comes from moving the new source files aside for a moment, building, committing the tests, and moving the files back.

Pin the interfaces between units of one wave in the prompts. A later unit builds against what the earlier wave committed, but units inside a wave cannot see each other, so a shared type such as the injected process runner belongs to exactly one unit and the others only get it in the next wave.

## Why This Matters

In Swift the red state of a new test is a build that fails on a missing type, not a failing assertion. With one test target that failure is global, so "each worker runs its own tests" silently assumes isolation the package does not give. A worktree per unit restores that isolation without letting subagents commit, and the copy-in order keeps the red commit honest.

The cost is a cold build per worktree, SwiftTerm included. That is small next to three units written at once.

## When to Apply

- A wave of two or more units from a plan in this repository, each with new test files.
- Not for a single unit or for units the plan chains: work in the feature worktree and use the move-aside step for the red commit.

## Examples

Shell details that cost time in this session, on this machine:

- `cp` and `rm` are interactive aliases. A plain `cp` over an existing file answers "not overwritten" and goes on. Use `/bin/cp -f`, and move files instead of deleting them.
- zsh does not split a variable on spaces. `C="a.swift b.swift"; git add $C` looks for one file with a space in its name. Use an array: `C=(a.swift b.swift)`.
- Commit with explicit paths (`git commit -m "..." -- <paths>`), so nothing else in the index rides along.

## Related

- `docs/plans/2026-11-23-003-feature-projectstrook-plan.md`: the plan whose execution table set the two waves.
