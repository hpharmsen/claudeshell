# Architecture

Claudeshell is a native Mac app that shows every Claude Code project as a coloured tile. A tile shows whether Claude is busy or waits for HP, and a click or shortcut opens the project with a shell on the left and Claude on the right.

## Two targets

The project is a Swift package (`Package.swift`, swift-tools 6.2, Swift 6 language mode, macOS 14+). There is no Xcode project.

| Target | Role | Tests |
|---|---|---|
| `ClaudeshellCore` | All logic without UI | `swift test`, Swift Testing |
| `Claudeshell` | The AppKit and SwiftUI app, on top of SwiftTerm `1.99.3` (exact pin) | Checked by hand in the built app |

`scripts/build-app.sh` builds the release binary, puts it with `Support/Info.plist` and `Support/Fonts/` in `build/Claudeshell.app` and signs it ad hoc. `./runlocal.sh` builds and opens the app. `scripts/install-app.sh` builds and copies the app to `/Applications/Claudeshell.app`, which is what the Dock icon starts.

The icon is drawn by `scripts/make-icon.swift`; `Support/AppIcon.icns` is its output in all icon sizes.

### ClaudeshellCore

| File | What it holds |
|---|---|
| `Project.swift` | Shared types: `Project`, `ProjectStatus`, `PaneID`, `PaneKind`, `AttentionState`, and the start frame of the window |
| `ProjectStore.swift` | The ordered project list, status per project, selection, and storage |
| `ColorPalette.swift` | 16 fixed pastel tile colours and the choice of the next free one |
| `WezTermImporter.swift` | Parser for the `projects` and `simple_projects` tables in `~/.wezterm.lua` |
| `HookSettings.swift` | Generates the Claude Code settings file with the hooks |
| `HookEventLog.swift` | Reads new lines from the events file |
| `Attention.swift` | `AttentionTracker`: state per pane, aggregate per project, next waiting project |
| `LaunchSpec.swift` | Program, arguments, environment and folder for a shell or Claude pane |
| `FuzzyMatcher.swift` | Scoring for the Cmd+P finder |

### Claudeshell

| File | What it holds |
|---|---|
| `main.swift`, `AppDelegate.swift` | Start-up: store, first-start import, hook settings, events watcher, sound |
| `MainWindowController.swift` | The window, the split with two slots, and every user action |
| `TilesBarView.swift` | SwiftUI tiles bar with context menu, drag and drop, inactive dropdown and + |
| `SessionManager.swift` | Starts, stops and restarts the panes of running projects |
| `TerminalPaneView.swift`, `TerminalTheme.swift` | A SwiftTerm view per pane with the bundled fonts; the shell pane has the dark WezTerm colours, the Claude pane a light palette |
| `QuickOpenPanel.swift` | The Cmd+P finder as a sheet |
| `MainMenu.swift` | All shortcuts as menu items |

## From hook to tile

```mermaid
flowchart LR
    Claude[claude in a pane] -- hook appends a line --> File[(events file)]
    File -- DispatchSource --> Log[HookEventLog] --> Tracker[AttentionTracker] --> Bar[TilesBarView]
    Tracker -- busy to waiting --> Sound[system sound]
```

1. `SessionManager` starts Claude through `zsh -lic` with the command in `LaunchSpec.claudeCommand`. The environment carries `CLAUDESHELL_PANE` (a new id for every start), `CLAUDESHELL_EVENTS` and `CLAUDESHELL_SETTINGS`.
2. Claude reads the hooks from `--settings "$CLAUDESHELL_SETTINGS"`. These are merged with the hooks in `~/.claude/settings.json`, which stays untouched.
3. Every hook is `echo "$CLAUDESHELL_PANE <state>" >> "$CLAUDESHELL_EVENTS"`.
4. `AppDelegate` watches the events file with a `DispatchSource` on the main queue and hands new lines to `AttentionTracker`.
5. The tracker is `@Observable`; the tiles bar redraws by itself. A pane that goes from busy to waiting plays the Glass sound.

A line with a pane id the tracker does not know is ignored. That covers late hooks of a stopped session.

### States

A registered pane starts idle. `busy` counts from any state. `waiting` counts only from busy. When HP leaves a project, its waiting panes become idle. A project shows waiting if one pane waits, otherwise busy if one is busy, otherwise idle.

### Hooks, as observed with Claude Code 2.1.319

| Hook | Matcher | State |
|---|---|---|
| `UserPromptSubmit` | none | busy |
| `PostToolUse` | none | busy |
| `Stop` | none | waiting |
| `PreToolUse` | `AskUserQuestion` | waiting |
| `PermissionRequest` | none | waiting |
| `Notification` | `idle_prompt\|agent_needs_input\|elicitation_dialog\|permission_prompt` | waiting |

What the check in a real interactive session showed:

- A plain prompt gives `UserPromptSubmit` and then `Stop`. `idle_prompt` follows 60 seconds after a `Stop`, never in a session that has had no prompt yet.
- `AskUserQuestion` gives `PreToolUse` and `PermissionRequest` at once, also with `--dangerously-skip-permissions`. Answering gives `PostToolUse`, which puts the pane back on busy.
- Plan approval (`ExitPlanMode`) gives `PermissionRequest` at once; the `permission_prompt` notification only comes 6 seconds later. That is why `PermissionRequest` is in the table.
- A background task that wakes Claude gives a new `UserPromptSubmit` and later a `Stop`.
- Tool calls of a background subagent also give `PostToolUse`, so the tile shows busy while the subagent works after the main turn ended.
- `/cost` and `/help` fire nothing. A prompt-type slash command fires `UserPromptSubmit`.
- `agent_needs_input` and `elicitation_dialog` are documented but were not observed.

Known gaps:

- **Escape during a turn fires no hook at all**, not even `idle_prompt` later. The tile stays busy until the next prompt in that pane.
- `/compact` fires `PreCompact` and `PostCompact` but none of the hooks above, so the tile does not show busy while compacting.
- The trust dialog of a folder Claude has not seen before fires no hooks.

### Resuming the last conversation

`claude --continue` exits with `No conversation found to continue` when the folder has no conversation yet. The command therefore falls back: `claude ... --continue ... || exec claude ...`. The fallback also runs when a resumed Claude exits with an error code.

## Panes and sessions

- A project has a list of panes; version 1 always starts two (shell, Claude). `PaneID`, the tracker and `LaunchSpec` do not assume that number. Only `MainWindowController` has exactly two slots.
- Views of projects that are not selected stay alive, so output and scrollback continue.
- Stopping sends SIGHUP to the shell of the pane and SIGKILL after one second if it is still there. Quitting the app does the same for all panes.
- A shell that ends after more than two seconds gets a new shell in the same pane. Claude, and any process that ends within two seconds, leaves a line in the pane; Enter starts it again.
- SwiftTerm sends keys straight to the process, so that Enter is caught with a local key monitor in `TerminalPaneView`.

## Files on disk

| Path | Content |
|---|---|
| `~/Library/Application Support/Claudeshell/projects.json` | Projects in bar order, inactive ones last, with `status` active or inactive. Running and the selection are never stored. |
| `~/Library/Application Support/Claudeshell/projects.corrupt.json` | An unreadable `projects.json`, set aside |
| `~/Library/Application Support/Claudeshell/hooks.json` | The generated hook settings, rewritten at every start |
| `~/Library/Application Support/Claudeshell/events` | The events file, emptied at every start; `tail -f` shows the hooks live |
| User defaults `nl.harmsen.claudeshell` | Window frame and divider position (AppKit autosave) |

The environment variable `CLAUDESHELL_SUPPORT` points the app at another folder instead of `~/Library/Application Support/Claudeshell`, for a test run that must not touch the real projects.

The first start (no `projects.json`) imports the projects from `~/.wezterm.lua` whose folder exists, as active tiles. After that the file always exists, so the import runs once.

## Logging

Errors go to `os.Logger` with subsystem `Claudeshell`. Read them with `log stream --predicate 'subsystem == "Claudeshell"'`.
