import Foundation

/// Guesses the local address of a project from the port its `runlocal.sh` starts a server on.
public enum LocalhostGuesser {
    /// What a port is written behind, the most telling first.
    private static let markers = ["runserver", "http.server", "--port", "localhost:", "127.0.0.1:"]

    /// Returns `http://localhost:<port>`, or nil without a script or without a port in it.
    public static func url(for projectPath: String) -> URL? {
        let root = URL(fileURLWithPath: projectPath)
        guard let script = lines(of: root.appendingPathComponent("runlocal.sh")) else { return nil }
        // A marker, then a number or a variable with an optional default: `8000`, `"$PORT"`, `${PORT:-8000}`.
        let place = #/(runserver\s+|http\.server\s+|--port[\s=]+|localhost:|127\.0\.0\.1:)["']?(?:(\d+)|\$\{?(\w+)(?::-(\d+))?)/#
        let places = script.flatMap { $0.matches(of: place) }
        for marker in markers {
            for found in places where found.1.hasPrefix(marker) {
                var port = found.2
                if let name = found.3 {
                    port = value(of: name, in: script)
                        ?? value(of: name, in: lines(of: root.appendingPathComponent(".env")) ?? []) ?? found.4
                }
                if let number = port.flatMap({ Int($0) }), 1...65535 ~= number {
                    return URL(string: "http://localhost:\(number)")
                }
            }
        }
        return nil
    }

    /// Returns the lines of a file without its comment lines, or nil when it cannot be read.
    private static func lines(of file: URL) -> [Substring]? {
        (try? String(contentsOf: file, encoding: .utf8))?.split(whereSeparator: \.isNewline)
            .filter { !$0.drop(while: \.isWhitespace).hasPrefix("#") }
    }

    /// Returns the number assigned to exactly this variable; an assignment of anything else is skipped.
    private static func value(of name: Substring, in lines: [Substring]) -> Substring? {
        lines.lazy.compactMap { $0.wholeMatch(of: #/\s*(?:export\s+)?(\w+)=["']?(\d+)["']?\s*(?:#.*)?/#) }
            .first { $0.1 == name }?.2
    }
}
