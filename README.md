<img src="docs/icon.png" width="96" alt="Claudeshell icon">

# Claudeshell

A native Mac terminal app for working on many Claude Code projects at once. Every project is a coloured tile in a bar. The tile shows whether Claude is busy or waiting for you, and one click or shortcut puts you in that project with a shell on the left and Claude on the right.

It was built to replace a WezTerm setup with one workspace per project, where a finished or waiting Claude session went unnoticed.

## What it does

- **Tiles bar.** One tile per project, in alphabetical order: its icon with the name below. A project without an icon shows its initials on a pastel colour. Hold Cmd to see the key that selects each tile.
- **Two panes per project.** A zsh login shell (dark) on the left third and Claude Code (light) on the right, with a draggable divider. Claude resumes the last conversation in that folder.
- **Attention.** A running tile shows a spinner while Claude works and a red dot when Claude has finished its turn or asks a question. A short sound plays when a project starts waiting.
- **Fast switching.** Cmd+1 to Cmd+0 select tile 1 to 10, Cmd+Option+1 to Cmd+Option+0 tile 11 to 20. Cmd+§ jumps to the next waiting project. Cmd+P opens a fuzzy finder over all projects.
- **Three states.** Running (sessions active), active (in the bar, nothing runs) and inactive (parked in a dropdown). Right-click a tile to stop, park, remove, rename or recolour it.
- **Nothing starts by itself.** After a restart every project is active; a click starts it.

## Good to know before you run it

- Claude is started as `claude --dangerously-skip-permissions`. That is how the author works; change `LaunchSpec.claudeCommand` if you do not want that.
- The status comes from Claude Code hooks, passed with `--settings`. Your own `~/.claude/settings.json` is not touched.
- On the first start the app imports the project list from `~/.wezterm.lua`, if that file has `projects` and `simple_projects` tables in the shape the author uses. Without it you start with an empty bar and add folders with the + button.
- Set Claude Code to a light theme with `/theme`, because the Claude pane has a white background.
- This is a personal tool: it is not notarised and is signed ad hoc, so macOS asks again for folder permissions after every rebuild.

## Requirements

- macOS 14 or newer
- Xcode with Swift 6.2 or newer
- Claude Code (`claude`) on the `PATH` of a zsh login shell

## Build and run

```sh
./runlocal.sh             # build and open build/Claudeshell.app
scripts/install-app.sh    # build and install in /Applications
swift test                # run the tests of the logic
```

## How it is put together

A Swift package with two targets: `ClaudeshellCore` holds all logic and is covered by tests, `Claudeshell` is the AppKit and SwiftUI app on top of [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm). See [docs/architecture.md](docs/architecture.md) for the chain from hook to tile, the hook behaviour that was observed, and the files the app keeps on disk. The plan and requirements in `docs/` are in Dutch.

## License

MIT, see [LICENSE](LICENSE). The bundled fonts have their own licences: JetBrains Mono (`Support/Fonts/JetBrainsMono-OFL.txt`) and Symbols Nerd Font (`Support/Fonts/NerdFonts-LICENSE`).
