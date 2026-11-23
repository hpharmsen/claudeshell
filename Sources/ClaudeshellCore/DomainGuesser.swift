import Foundation

/// Guesses the domains of a project from what is literally written in its folder.
public enum DomainGuesser {
    /// Hosting and placeholder domains that never carry the project's own icon, subdomains included.
    private static let rejectedDomains = [
        "herokuapp.com", "github.com", "github.io", "gitlab.com", "pypi.org", "readthedocs.io", "example.com",
    ]
    private static let skippedFolders: Set = ["node_modules", "venv", "build", "dist", "staticfiles"]
    private static let settingsDepth = 3

    /// Returns the host names found in the project, in the order of the sources and without duplicates.
    public static func domains(for projectPath: String) -> [String] {
        let root = URL(fileURLWithPath: projectPath)
        func read(_ name: String) -> String? { try? String(contentsOf: root.appendingPathComponent(name), encoding: .utf8) }

        var candidates = [root.lastPathComponent]
        if let cname = read("CNAME") { candidates.append(cname) }
        if let data = read("package.json")?.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let homepage = json["homepage"] as? String {
            candidates.append(homepage)
        }
        let homepage = #/^\s*homepage\s*=\s*["']([^"'\n]+)["']/#.ignoresCase().anchorsMatchLineEndings()
        if let match = read("pyproject.toml")?.firstMatch(of: homepage) { candidates.append(String(match.1)) }
        for file in [root.appendingPathComponent("settings.py")] + settingsFiles(in: root, depth: settingsDepth) {
            guard let contents = try? String(contentsOf: file, encoding: .utf8) else { continue }
            // Python comments go first, so an apostrophe in a comment cannot pair up with a quote.
            let code = contents.replacing(#/#.*/#, with: "")
            for list in code.matches(of: #/ALLOWED_HOSTS\s*\+?=\s*[\[(]([^\])]*)[\])]/#) {
                candidates += list.1.matches(of: #/["']([^"'\n]*)["']/#).map { String($0.1) }
            }
        }

        var seen: Set<String> = []
        return candidates.compactMap(host).filter { seen.insert($0).inserted }
    }

    /// Returns the `settings.py` files at most `depth` folders below `folder`, the shallowest first.
    private static func settingsFiles(in folder: URL, depth: Int) -> [URL] {
        guard depth > 0, let entries = try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        let folders = entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .filter { !$0.lastPathComponent.hasPrefix(".") && !skippedFolders.contains($0.lastPathComponent) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let found = folders.map { $0.appendingPathComponent("settings.py") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        return found + folders.flatMap { settingsFiles(in: $0, depth: depth - 1) }
    }

    /// Returns the host of a URL or bare host name, or nil when it is not an acceptable domain.
    private static func host(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var host = trimmed.contains("://") ? URLComponents(string: trimmed)?.host ?? "" : trimmed
        if host.hasPrefix(".") { host.removeFirst() }
        // Labels plus an alphabetic top-level domain: this drops IP addresses, wildcards and hosts without a dot.
        guard host.wholeMatch(of: #/([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}/#) != nil,
              !rejectedDomains.contains(where: { host == $0 || host.hasSuffix(".\($0)") })
        else { return nil }
        return host
    }
}
