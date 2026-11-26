import Foundation
import Testing
@testable import MaestroCore

private let base = ["HOME": "/Users/hp", "USER": "hp", "SHELL": "/bin/zsh"]

private func spec(_ kind: PaneKind, path: String = "/Users/hp/proj/justai",
                  settings: String = "/Users/hp/Library/Application Support/Maestro/hooks.json",
                  base: [String: String] = base) -> LaunchSpec {
    LaunchSpec(kind: kind, projectPath: path, eventsPath: "/tmp/events", settingsPath: settings, base: base)
}

private func env(_ spec: LaunchSpec) -> [String: String] {
    Dictionary(uniqueKeysWithValues: spec.environment.map { entry in
        let parts = entry.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        return (String(parts[0]), String(parts[1]))
    })
}

@Test func shellSpecStartsLoginZshInProjectFolder() {
    let shell = spec(.shell)
    #expect(shell.executable == "/bin/zsh")
    #expect(shell.args == ["-l"])
    #expect(shell.directory == "/Users/hp/proj/justai")
}

@Test func shellSpecUsesShellFromEnvironment() {
    #expect(spec(.shell, base: ["SHELL": "/opt/homebrew/bin/zsh"]).executable == "/opt/homebrew/bin/zsh")
}

@Test func claudeSpecIsTheFixedCommand() {
    let claude = spec(.claude)
    #expect(claude.executable == "/bin/zsh")
    #expect(claude.args == ["-lic", LaunchSpec.claudeCommand])
    #expect(claude.directory == "/Users/hp/proj/justai")
}

@Test func claudeCommandResumesAndFallsBackToFresh() {
    let flags = "claude --dangerously-skip-permissions"
    let settings = "--settings \"$MAESTRO_SETTINGS\""
    #expect(LaunchSpec.claudeCommand == "\(flags) --continue \(settings) || exec \(flags) \(settings)")
}

@Test func claudeCommandDoesNotDependOnSettingsPath() {
    let odd = spec(.claude, settings: "/tmp/it's \"odd\"/hooks.json")
    #expect(odd.args == spec(.claude).args)
    #expect(env(odd)["MAESTRO_SETTINGS"] == "/tmp/it's \"odd\"/hooks.json")
}

@Test func projectPathWithSpacesStaysIntact() {
    let path = "/Users/hp/proj/elevate/Curriculum Design Tool"
    #expect(spec(.shell, path: path).directory == path)
    #expect(spec(.claude, path: path).directory == path)
}

@Test func bothSpecsCarryTheirPaneAndTheSameEventsFile() {
    let shell = spec(.shell), claude = spec(.claude)
    #expect(env(shell)["MAESTRO_PANE"] == shell.pane.rawValue)
    #expect(env(claude)["MAESTRO_PANE"] == claude.pane.rawValue)
    #expect(env(shell)["MAESTRO_EVENTS"] == "/tmp/events")
    #expect(env(claude)["MAESTRO_EVENTS"] == "/tmp/events")
}

@Test func everySpecGetsANewPaneID() {
    #expect(spec(.claude).pane != spec(.claude).pane)
}

@Test func languageAndTerminalAreAlwaysSet() {
    let environment = env(spec(.shell, base: [:]))
    #expect(environment["LANG"] == "en_US.UTF-8")
    #expect(environment["TERM"] == "xterm-256color")
    #expect(environment["COLORTERM"] == "truecolor")
    #expect(environment["HOME"]?.isEmpty == false)
    #expect(environment["USER"]?.isEmpty == false)
    #expect(environment["SHELL"] == "/bin/zsh")
}

@Test func environmentOfTheAppDoesNotLeakIntoThePane() {
    #expect(env(spec(.shell, base: base.merging(["SECRET": "x"]) { $1 }))["SECRET"] == nil)
}

@Test func relativeLinkResolvesAgainstThePaneFolder() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    try FileManager.default.createDirectory(atPath: folder + "/docs", withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: folder) }
    FileManager.default.createFile(atPath: folder + "/docs/notes.md", contents: nil)
    let pane = spec(.claude, path: folder)
    #expect(pane.resolvedLink("docs/notes.md") == folder + "/docs/notes.md")
    #expect(pane.resolvedLink("docs/notes.md:12:4") == folder + "/docs/notes.md:12:4")
    #expect(pane.resolvedLink("docs/notes.md.") == folder + "/docs/notes.md")
    #expect(pane.resolvedLink("docs/notes.md:12,") == folder + "/docs/notes.md:12")
    #expect(pane.resolvedLink(folder + "/docs/notes.md.") == folder + "/docs/notes.md")
    #expect(pane.resolvedLink("docs/missing.md.") == "docs/missing.md.")
    #expect(pane.resolvedLink("docs/missing.md") == "docs/missing.md")
    #expect(pane.resolvedLink("/etc/hosts") == "/etc/hosts")
    #expect(pane.resolvedLink("~/notes.md") == "~/notes.md")
    #expect(pane.resolvedLink("https://example.com/docs/notes.md") == "https://example.com/docs/notes.md")
    #expect(pane.resolvedLink("") == "")
}

@Test func slashCommandInAClaudePaneIsNoFile() {
    let pane = spec(.claude)
    #expect(pane.slashCommand("/hp:deepen-plan docs/plans/001-plan.md") == "/hp:deepen-plan docs/plans/001-plan.md")
    #expect(pane.slashCommand("/hp:build.") == "/hp:build")
    #expect(pane.slashCommand("/clear") == "/clear")
    #expect(pane.slashCommand("/tmp") == nil)
    #expect(pane.slashCommand("/etc/hosts") == nil)
    #expect(pane.slashCommand("docs/notes.md") == nil)
    #expect(pane.slashCommand("https://example.com/clear") == nil)
    #expect(pane.slashCommand("/") == nil)
    #expect(pane.slashCommand("") == nil)
    #expect(spec(.shell).slashCommand("/clear") == nil)
}

@Test func linkToAFileThatCanRunBecomesAShellCommand() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
    try FileManager.default.createDirectory(atPath: folder + "/my scripts", withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(atPath: folder) }
    let executable: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
    FileManager.default.createFile(atPath: folder + "/run.sh", contents: nil, attributes: executable)
    FileManager.default.createFile(atPath: folder + "/my scripts/it's.sh", contents: nil, attributes: executable)
    FileManager.default.createFile(atPath: folder + "/notes.md", contents: nil)
    let pane = spec(.claude, path: folder)
    #expect(pane.executableCommand("./run.sh") == folder + "/run.sh")
    #expect(pane.executableCommand("run.sh.") == folder + "/run.sh")
    #expect(pane.executableCommand(folder + "/run.sh") == folder + "/run.sh")
    #expect(pane.executableCommand("my scripts/it's.sh") == "'\(folder)/my scripts/it'\\''s.sh'")
    #expect(pane.executableCommand("notes.md") == nil)
    #expect(pane.executableCommand("my scripts") == nil)
    #expect(pane.executableCommand("missing.sh") == nil)
    #expect(pane.executableCommand("https://example.com/run.sh") == nil)
    #expect(pane.executableCommand("") == nil)
}
