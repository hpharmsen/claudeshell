/// A project as found in the WezTerm configuration.
public struct ImportedProject: Equatable, Sendable {
    public let name: String
    public let path: String
}

/// Reads the project list from the contents of `~/.wezterm.lua`.
public enum WezTermImporter {
    /// Returns the projects of both tables, sorted by name the way WezTerm sorts them.
    public static func parse(_ contents: String, home: String) -> [ImportedProject] {
        // Drops Lua line comments; a `--` inside a quoted string is left alone.
        let comment = #/^((?:[^'"\-\n]|'[^'\n]*'|"[^"\n]*"|-(?!-))*)--.*$/#.anchorsMatchLineEndings()
        let text = contents.replacing(comment) { $0.1 }

        var projects: [ImportedProject] = []
        for entry in body(after: #/local\s+projects\s*=\s*\{/#, in: text).matches(of: #/\{[^{}]*\}/#) {
            guard let name = entry.0.firstMatch(of: #/\bname\s*=\s*(?<q>['"])(?<value>.*?)\k<q>/#),
                  let cwd = entry.0.firstMatch(
                      of: #/\bcwd\s*=\s*(?<home>wezterm\.home_dir\s*\.\.\s*)?(?<q>['"])(?<value>.*?)\k<q>/#)
            else { continue }
            let prefix = cwd.output.home == nil ? "" : home
            projects.append(ImportedProject(name: String(name.output.value), path: prefix + cwd.output.value))
        }
        for match in body(after: #/local\s+simple_projects\s*=\s*\{/#, in: text).matches(of: #/(?<q>['"])(?<value>.*?)\k<q>/#) {
            let name = String(match.output.value)
            projects.append(ImportedProject(name: name, path: "\(home)/proj/\(name.lowercased())"))
        }
        // Lua compares strings byte by byte, so uppercase sorts before lowercase.
        return projects.sorted { $0.name.utf8.lexicographicallyPrecedes($1.name.utf8) }
    }

    /// Returns the text between the opening brace matched by `opening` and its closing brace.
    private static func body(after opening: Regex<Substring>, in text: String) -> Substring {
        guard let start = text.firstMatch(of: opening)?.range.upperBound else { return "" }
        var depth = 1
        for index in text[start...].indices {
            if text[index] == "{" { depth += 1 }
            if text[index] == "}" { depth -= 1 }
            if depth == 0 { return text[start..<index] }
        }
        return ""
    }
}
