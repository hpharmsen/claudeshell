import Foundation

/// Program, arguments, environment and folder for one pane start.
public struct LaunchSpec: Equatable, Sendable {
    /// Resumes the last conversation; without one `--continue` exits with an error, so a fresh session follows.
    public static let claudeCommand: String = {
        let flags = "claude --dangerously-skip-permissions", settings = "--settings \"$CLAUDESHELL_SETTINGS\""
        return "\(flags) --continue \(settings) || exec \(flags) \(settings)"
    }()

    public let pane = PaneID()
    public let kind: PaneKind
    public let executable: String
    public let args: [String]
    /// 'KEY=VALUE' entries; nothing else of the app's environment reaches the pane.
    public let environment: [String]
    public let directory: String

    public init(kind: PaneKind, projectPath: String, eventsPath: String, settingsPath: String,
                base: [String: String] = ProcessInfo.processInfo.environment) {
        let shell = base["SHELL"] ?? "/bin/zsh"
        self.kind = kind
        directory = projectPath
        // Claude runs through an interactive login shell so PATH comes from ~/.zshrc.
        executable = kind == .shell ? shell : "/bin/zsh"
        args = kind == .shell ? ["-l"] : ["-lic", Self.claudeCommand]
        environment = [
            "HOME=\(base["HOME"] ?? NSHomeDirectory())",
            "USER=\(base["USER"] ?? NSUserName())",
            "SHELL=\(shell)",
            "LANG=en_US.UTF-8",
            "TERM=xterm-256color",
            "COLORTERM=truecolor",
            "CLAUDESHELL_PANE=\(pane.rawValue)",
            "CLAUDESHELL_EVENTS=\(eventsPath)",
            "CLAUDESHELL_SETTINGS=\(settingsPath)",
        ]
    }

    /// A path from the pane's output as an absolute path, when it names a file; relative paths start in the pane's folder.
    public func resolvedLink(_ link: String) -> String {
        // The link detection takes the full stop of a sentence along: 'see docs/notes.md.'
        let trimmed = link.replacing(/[.,;:!?]+$/, with: "")
        for candidate in [link, trimmed] where !candidate.isEmpty {
            let expanded = (candidate as NSString).expandingTildeInPath
            let path = expanded.hasPrefix("/") ? expanded : (directory as NSString).appendingPathComponent(expanded)
            // A source location such as 'main.swift:12:4' stays on the link but is not part of the file name.
            let file = path.replacing(/:[0-9]+(:[0-9]+)?$/, with: "")
            if FileManager.default.fileExists(atPath: file) { return path }
        }
        return link
    }
}
