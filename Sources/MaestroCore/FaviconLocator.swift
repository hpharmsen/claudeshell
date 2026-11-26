import Foundation

/// Finds the places where the icon of a web page may live.
public enum FaviconLocator {
    /// Returns the candidate icon URLs of a page, the most promising first, ending with the two fixed paths.
    public static func candidates(html: String, pageURL: URL) -> [URL] {
        var touchIcons: [String] = []
        var icons: [(href: String, size: Int)] = []
        for tag in html.matches(of: #/<link\b[^>]*>/#.ignoresCase()) {
            let pairs = tag.0.matches(of: #/([a-zA-Z-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/#)
                .map { ($0.1.lowercased(), String($0.2 ?? $0.3 ?? "")) }
            let attributes = Dictionary(pairs, uniquingKeysWith: { first, _ in first })
            guard let href = attributes["href"], let rel = attributes["rel"]?.lowercased().split(separator: " ")
            else { continue }
            if rel.contains(where: { $0.hasPrefix("apple-touch-icon") }) {
                touchIcons.append(href)
            } else if rel.contains("icon") {
                let sizes = (attributes["sizes"] ?? "").matches(of: #/(\d+)x\d+/#.ignoresCase()).compactMap { Int($0.1) }
                icons.append((href, sizes.max() ?? 0))
            }
        }
        // The offset keeps equal sizes in document order; links without `sizes` count as size 0 and come last.
        let sorted = icons.enumerated()
            .sorted { ($1.element.size, $0.offset) < ($0.element.size, $1.offset) }
            .map(\.element.href)

        var seen: Set<URL> = []
        return (touchIcons + sorted + ["/apple-touch-icon.png", "/favicon.ico"])
            .compactMap { URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines), relativeTo: pageURL)?.absoluteURL }
            .filter { ["http", "https"].contains($0.scheme?.lowercased() ?? "") && seen.insert($0).inserted }
    }
}
