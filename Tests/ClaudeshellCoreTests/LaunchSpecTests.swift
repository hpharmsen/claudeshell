import Foundation
import Testing
@testable import ClaudeshellCore

private let base = ["HOME": "/Users/hp", "USER": "hp", "SHELL": "/bin/zsh"]

private func spec(_ kind: PaneKind, path: String = "/Users/hp/proj/justai",
                  settings: String = "/Users/hp/Library/Application Support/Claudeshell/hooks.json",
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
    let settings = "--settings \"$CLAUDESHELL_SETTINGS\""
    #expect(LaunchSpec.claudeCommand == "\(flags) --continue \(settings) || exec \(flags) \(settings)")
}

@Test func claudeCommandDoesNotDependOnSettingsPath() {
    let odd = spec(.claude, settings: "/tmp/it's \"odd\"/hooks.json")
    #expect(odd.args == spec(.claude).args)
    #expect(env(odd)["CLAUDESHELL_SETTINGS"] == "/tmp/it's \"odd\"/hooks.json")
}

@Test func projectPathWithSpacesStaysIntact() {
    let path = "/Users/hp/proj/elevate/Curriculum Design Tool"
    #expect(spec(.shell, path: path).directory == path)
    #expect(spec(.claude, path: path).directory == path)
}

@Test func bothSpecsCarryTheirPaneAndTheSameEventsFile() {
    let shell = spec(.shell), claude = spec(.claude)
    #expect(env(shell)["CLAUDESHELL_PANE"] == shell.pane.rawValue)
    #expect(env(claude)["CLAUDESHELL_PANE"] == claude.pane.rawValue)
    #expect(env(shell)["CLAUDESHELL_EVENTS"] == "/tmp/events")
    #expect(env(claude)["CLAUDESHELL_EVENTS"] == "/tmp/events")
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
    #expect(pane.resolvedLink("docs/missing.md") == "docs/missing.md")
    #expect(pane.resolvedLink("/etc/hosts") == "/etc/hosts")
    #expect(pane.resolvedLink("~/notes.md") == "~/notes.md")
    #expect(pane.resolvedLink("https://example.com/docs/notes.md") == "https://example.com/docs/notes.md")
    #expect(pane.resolvedLink("") == "")
}
