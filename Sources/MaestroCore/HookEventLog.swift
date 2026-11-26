import Foundation
import os

/// One line from the events file: a pane that became busy or waiting.
public struct HookEvent: Equatable, Sendable {
    public let pane: PaneID
    public let state: AttentionState

    public init(pane: PaneID, state: AttentionState) {
        self.pane = pane
        self.state = state
    }

    /// Parses '<pane-id> <state>'; nil for anything else.
    init?(line: String) {
        let parts = line.split(whereSeparator: \.isWhitespace)
        guard parts.count == 2, let state = AttentionState(rawValue: String(parts[1])), state != .idle else { return nil }
        self.init(pane: PaneID(String(parts[0])), state: state)
    }
}

/// Reads the events file that the hooks append to, from the last read position.
public final class HookEventLog {
    public let fileURL: URL
    private var offset: UInt64 = 0
    private var pending = Data()
    private let logger = Logger(subsystem: "Maestro", category: "HookEventLog")

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Creates the file empty (and its directory) and starts reading at zero.
    public func reset() {
        offset = 0
        pending = Data()
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: fileURL)
        } catch {
            logger.error("Cannot reset events file: \(error)")
        }
    }

    /// Returns the events of all complete lines added since the previous read.
    public func readNew() -> [HookEvent] {
        do {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }
            // A shorter file means another app instance emptied it: start again at zero.
            if try handle.seekToEnd() < offset {
                offset = 0
                pending = Data()
            }
            try handle.seek(toOffset: offset)
            let data = try handle.readToEnd() ?? Data()
            offset += UInt64(data.count)
            pending.append(data)
        } catch {
            logger.error("Cannot read events file: \(error)")
            return []
        }
        // The part after the last newline is an incomplete line; keep it for the next read.
        let lines = pending.split(separator: 0x0A, omittingEmptySubsequences: false)
        pending = Data(lines.last ?? Data())
        return lines.dropLast().compactMap { HookEvent(line: String(decoding: $0, as: UTF8.self)) }
    }
}
