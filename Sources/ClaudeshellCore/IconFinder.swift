import Foundation

/// Finds image files in a project folder that could serve as the project's icon.
public enum IconFinder {
    /// File name patterns, best first; a `*` stands for any text, a name without one must match exactly.
    private static let patterns = [
        "apple-touch-icon*.png", "favicon*.svg", "favicon*.png", "android-chrome*.png", "*.icns",
        "icon.svg", "icon.png", "favicon*.ico", "logo.svg", "logo.png",
    ]
    private static let skippedFolders: Set = ["node_modules", "venv", "build", "dist", "staticfiles"]
    private static let maxDepth = 5
    private static let maxItems = 20_000

    /// Absolute paths of the candidate icons in `folder`, best first; the files are not opened.
    public static func candidates(in folder: String) -> [String] {
        var found: [(rank: Int, depth: Int, path: String)] = []
        var seen = 0
        // Breadth first, so the item limit cuts off the deepest folders rather than arbitrary ones.
        var queue = [(url: URL(fileURLWithPath: folder), depth: 0)]
        while seen < maxItems, !queue.isEmpty {
            let (url, depth) = queue.removeFirst()
            let items = (try? FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
            for item in items.prefix(maxItems - seen) {
                let name = item.lastPathComponent.lowercased()
                if (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    if depth < maxDepth, !name.hasPrefix("."), !skippedFolders.contains(name) {
                        queue.append((item, depth + 1))
                    }
                } else if let rank = rank(of: name) {
                    found.append((rank, depth, item.path))
                }
            }
            seen += items.count
        }
        return found
            .sorted { ($0.rank, $0.depth, $0.path) < ($1.rank, $1.depth, $1.path) }
            .map(\.path)
    }

    /// The position of the first pattern a lowercased file name matches, or nil without a match.
    private static func rank(of name: String) -> Int? {
        patterns.firstIndex { pattern in
            let parts = pattern.split(separator: "*", omittingEmptySubsequences: false)
            guard parts.count == 2 else { return name == pattern }
            return name.count >= parts[0].count + parts[1].count
                && name.hasPrefix(parts[0]) && name.hasSuffix(parts[1])
        }
    }
}
