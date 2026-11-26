import Foundation

/// The last turns of the last Claude conversation of a project.
public struct Transcript: Equatable, Sendable {
    /// A message of HP with the closing answer of Claude, if Claude answered.
    public struct Turn: Equatable, Sendable {
        public let user: String
        public let answer: String?
    }

    public let turns: [Turn]
    /// The interim summary that Claude Code wrote after the last real message.
    public let awaySummary: String?
    public let fileName: String?
    public let lastMessageUUID: String?
    /// When the last real message was written, in ISO 8601.
    public let lastMessageTimestamp: String?
    /// How many bytes of conversation files were read to get here.
    public let bytesRead: Int

    /// True when no conversation with a real message was found.
    public var isEmpty: Bool { lastMessageUUID == nil }
}

/// The names in a conversation file of Claude Code; not a public format, so they all live here.
private enum Format {
    static let fileExtension = "jsonl"
    static let type = "type", subtype = "subtype", uuid = "uuid", timestamp = "timestamp", entrypoint = "entrypoint"
    static let message = "message", content = "content", text = "text", model = "model"
    static let isMeta = "isMeta", isCompactSummary = "isCompactSummary", isApiErrorMessage = "isApiErrorMessage"
    static let origin = "origin", kind = "kind"
    static let user = "user", assistant = "assistant", system = "system", awaySummary = "away_summary"
    static let toolResult = "tool_result", taskNotification = "task-notification", synthetic = "<synthetic>", cli = "cli"
    /// A message of HP that starts like this was written by Claude Code, not by HP.
    static let noisePrefixes = [
        "<task-notification>", "<command-name>", "<local-command-stdout>", "<local-command-caveat>",
        "<bash-input>", "<bash-stdout>", "[Request interrupted",
    ]
    /// Only a line that holds one of these is worth decoding.
    static let wanted = [pair(type, user), pair(type, assistant), pair(subtype, awaySummary)].map { Data($0.utf8) }
    /// Every tool result holds this key; those lines are big and never a message.
    static let unwanted = Data("\"sourceToolAssistantUUID\"".utf8)
    static let entrypointKey = Data("\"\(entrypoint)\":\"".utf8)
    static let cliEntrypoint = Data(pair(entrypoint, cli).utf8)

    /// A key with a string value, spelled as the files spell it: without spaces.
    private static func pair(_ key: String, _ value: String) -> String { "\"\(key)\":\"\(value)\"" }

    /// The folder of a project: its path with every character outside ASCII letters and digits as a hyphen.
    static func folderName(for path: String) -> String {
        String(path.unicodeScalars.map { $0.isASCII && $0.properties.isAlphabetic || ("0"..."9").contains($0) ? Character($0) : "-" })
    }
}

/// A line that says something: a message of HP, a text of Claude, or an interim summary.
private struct TranscriptLine {
    enum Kind { case user, assistant, awaySummary }

    let kind: Kind
    let text: String
    let uuid: String
    let timestamp: String

    /// Decodes a line only when the cheap filter passes; nil for everything that is not a real message or summary.
    init?(_ data: Data) {
        guard Format.wanted.contains(where: { data.range(of: $0) != nil }), data.range(of: Format.unwanted) == nil,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uuid = json[Format.uuid] as? String, let timestamp = json[Format.timestamp] as? String else { return nil }
        let message = json[Format.message] as? [String: Any] ?? [:]
        let blocks = message[Format.content] as? [[String: Any]] ?? []
        let blockText = blocks.filter { $0[Format.type] as? String == Format.text }
            .compactMap { $0[Format.text] as? String }.joined(separator: "\n")
        let text: String
        switch (json[Format.type] as? String, json[Format.subtype] as? String) {
        case (Format.user, _):
            guard json[Format.isMeta] as? Bool != true, json[Format.isCompactSummary] as? Bool != true,
                  (json[Format.origin] as? [String: Any])?[Format.kind] as? String != Format.taskNotification,
                  !blocks.contains(where: { $0[Format.type] as? String == Format.toolResult }) else { return nil }
            kind = .user
            text = message[Format.content] as? String ?? blockText
        case (Format.assistant, _):
            guard message[Format.model] as? String != Format.synthetic, json[Format.isApiErrorMessage] as? Bool != true else { return nil }
            kind = .assistant
            text = blockText
        case (Format.system, Format.awaySummary):
            kind = .awaySummary
            text = json[Format.content] as? String ?? ""
        default:
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, kind != .user || !Format.noisePrefixes.contains(where: trimmed.hasPrefix) else { return nil }
        self.text = String(trimmed.prefix(TranscriptReader.maxCharacters))
        self.uuid = uuid
        self.timestamp = timestamp
    }
}

/// Hands out the lines of a file from the last to the first, reading it in blocks from the end.
private final class ReverseLines {
    private let handle: FileHandle
    private let blockSize: UInt64
    private var offset: UInt64
    /// The start of a line whose beginning lies in a block that is not read yet.
    private var partial = Data()
    private var lines: [Data] = []
    private(set) var bytesRead = 0

    init?(url: URL, blockSize: Int) {
        guard let handle = try? FileHandle(forReadingFrom: url), let end = try? handle.seekToEnd() else { return nil }
        self.handle = handle
        self.blockSize = UInt64(max(blockSize, 1))
        offset = end
    }

    deinit { try? handle.close() }

    /// The line before the previous one, without its newline; nil at the start of the file or on a read error.
    func next() -> Data? {
        while lines.isEmpty {
            guard offset > 0 else {
                defer { partial = Data() }
                return partial.isEmpty ? nil : partial
            }
            let count = min(blockSize, offset)
            guard (try? handle.seek(toOffset: offset - count)) != nil,
                  let block = try? handle.read(upToCount: Int(count)), block.count == Int(count) else { return nil }
            offset -= count
            bytesRead += block.count
            let parts = (block + partial).split(separator: 0x0A, omittingEmptySubsequences: false)
            partial = Data(parts[0])
            lines = parts.dropFirst().filter { !$0.isEmpty }
        }
        return lines.removeLast()
    }
}

/// Reads the last conversation of a project from the files that Claude Code keeps.
public struct TranscriptReader: Sendable {
    static let maxTurns = 8
    static let maxCharacters = 2000
    private static let maxCandidates = 3

    private let root: URL
    private let blockSize: Int

    public init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects"), blockSize: Int = 64 * 1024) {
        self.root = root
        self.blockSize = blockSize
    }

    /// The name of the folder that holds the conversations of a project path.
    public static func folderName(for path: String) -> String { Format.folderName(for: path) }

    /// The last turns of the last conversation of a project; empty when there is none.
    public func read(projectPath: String) -> Transcript {
        // Claude Code names the folder after the real path, so symlinks are resolved when the folder exists.
        let realPath = realpath(projectPath, nil).map { pointer in
            defer { free(pointer) }
            return String(cString: pointer)
        } ?? projectPath
        let folder = root.appendingPathComponent(Self.folderName(for: realPath))
        var bytesRead = 0
        var candidates: [(file: URL, timestamp: String?)] = []
        for file in newestFirst(in: folder) where candidates.count < Self.maxCandidates {
            let scan = scan(file, maxTurns: 0)
            bytesRead += scan.bytesRead
            if scan.isCLI { candidates.append((file, scan.timestamp)) }
        }
        // All timestamps are ISO 8601 in UTC, so they sort as text.
        let latest = candidates.compactMap { candidate in candidate.timestamp.map { (candidate.file, $0) } }.max { $0.1 < $1.1 }
        guard let file = latest?.0 else {
            return Transcript(turns: [], awaySummary: nil, fileName: nil, lastMessageUUID: nil, lastMessageTimestamp: nil,
                              bytesRead: bytesRead)
        }
        let scan = scan(file, maxTurns: Self.maxTurns)
        return Transcript(turns: scan.turns.reversed(), awaySummary: scan.awaySummary, fileName: file.lastPathComponent,
                          lastMessageUUID: scan.uuid, lastMessageTimestamp: scan.timestamp, bytesRead: bytesRead + scan.bytesRead)
    }

    /// The conversation files directly in a folder, the last modified first.
    private func newestFirst(in folder: URL) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.filter { $0.pathExtension == Format.fileExtension }
            .map { ($0, (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast) }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    /// What reading a file backwards found, with the turns from the last to the first.
    private struct Scan {
        var isCLI = false
        var uuid: String?
        var timestamp: String?
        var turns: [Transcript.Turn] = []
        var awaySummary: String?
        var bytesRead = 0
    }

    /// Reads a file backwards until it holds `maxTurns` turns, or one real message when that is zero.
    private func scan(_ file: URL, maxTurns: Int) -> Scan {
        var scan = Scan()
        guard let lines = ReverseLines(url: file, blockSize: blockSize) else { return scan }
        var entrypointKnown = false
        var answer: String?
        while let data = lines.next() {
            // The newest line that names an entrypoint decides for the file; another one than cli ends the scan.
            if !entrypointKnown, data.range(of: Format.entrypointKey) != nil {
                entrypointKnown = true
                scan.isCLI = data.range(of: Format.cliEntrypoint) != nil
                if !scan.isCLI { break }
            }
            guard let line = TranscriptLine(data) else { continue }
            if line.kind == .awaySummary {
                if scan.uuid == nil, scan.awaySummary == nil { scan.awaySummary = line.text }
                continue
            }
            if scan.uuid == nil { (scan.uuid, scan.timestamp) = (line.uuid, line.timestamp) }
            if line.kind == .user {
                scan.turns.append(Transcript.Turn(user: line.text, answer: answer))
                answer = nil
            } else if answer == nil {
                // Going backwards, the first text of Claude in a turn is its closing answer.
                answer = line.text
            }
            if scan.turns.count >= maxTurns { break }
        }
        scan.bytesRead = lines.bytesRead
        return scan
    }
}
