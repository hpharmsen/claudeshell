import Foundation

/// Composes the links of a project: the user's own link per kind, else the one the app finds.
public enum ProjectLinks {
    /// Returns the link per kind; a kind without link is absent. A failing `run` means no git link.
    public static func resolve(_ project: Project, run: ProcessRunner) async -> [LinkKind: URL] {
        var links: [LinkKind: URL] = [:]
        for kind in LinkKind.allCases {
            if let own = project.linkOverrides?[kind] {
                // An empty text is a cleared link, so nothing is searched for.
                links[kind] = URL(string: own.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                links[kind] = await found(kind, for: project, run: run)
            }
        }
        return links
    }

    /// Returns the link the app finds itself in the project folder.
    private static func found(_ kind: LinkKind, for project: Project, run: ProcessRunner) async -> URL? {
        switch kind {
        case .live:
            let domain = DomainGuesser.domains(for: project.path).first.map { "https://" + $0 }
            return (project.website ?? domain).flatMap(URL.init(string:))
        case .localhost:
            return LocalhostGuesser.url(for: project.path)
        case .git:
            let folder = URL(fileURLWithPath: project.path)
            let remote = try? await run("/usr/bin/git", ["remote", "get-url", "origin"], folder, nil, 10)
            return remote.flatMap(GitState.browsableURL)
        }
    }
}
