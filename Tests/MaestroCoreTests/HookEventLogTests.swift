import Foundation
import Testing
@testable import MaestroCore

/// Creates a fresh temp directory for one test.
func makeTempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("maestro-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

/// Appends text to a file, like a hook does.
func append(_ text: String, to url: URL) throws {
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(text.utf8))
}

/// A reset log in its own temp directory.
private func makeLog() throws -> (HookEventLog, URL) {
    let url = try makeTempDir().appendingPathComponent("events")
    let log = HookEventLog(fileURL: url)
    log.reset()
    return (log, url)
}

@Test func resetCreatesEmptyFileAndMissingDirectory() throws {
    let url = try makeTempDir().appendingPathComponent("sub/dir/events")
    HookEventLog(fileURL: url).reset()
    #expect(try Data(contentsOf: url).isEmpty)
}

@Test func resetEmptiesExistingFile() throws {
    let (log, url) = try makeLog()
    try append("p1 busy\n", to: url)
    log.reset()
    #expect(try Data(contentsOf: url).isEmpty)
    #expect(log.readNew().isEmpty)
}

@Test func readNewOnMissingFileReturnsNothing() throws {
    let log = HookEventLog(fileURL: try makeTempDir().appendingPathComponent("events"))
    #expect(log.readNew().isEmpty)
}

@Test func readNewOnEmptyFileReturnsNothing() throws {
    let (log, _) = try makeLog()
    #expect(log.readNew().isEmpty)
}

@Test func busyLineYieldsBusyEvent() throws {
    let (log, url) = try makeLog()
    try append("p1 busy\n", to: url)
    #expect(log.readNew() == [HookEvent(pane: PaneID("p1"), state: .busy)])
}

@Test func severalLinesInOneReadYieldEventsInOrder() throws {
    let (log, url) = try makeLog()
    try append("p1 busy\np2 waiting\np1 waiting\n", to: url)
    #expect(log.readNew() == [
        HookEvent(pane: PaneID("p1"), state: .busy),
        HookEvent(pane: PaneID("p2"), state: .waiting),
        HookEvent(pane: PaneID("p1"), state: .waiting),
    ])
}

@Test func linesAreReadOnlyOnce() throws {
    let (log, url) = try makeLog()
    try append("p1 busy\n", to: url)
    _ = log.readNew()
    try append("p1 waiting\n", to: url)
    #expect(log.readNew() == [HookEvent(pane: PaneID("p1"), state: .waiting)])
    #expect(log.readNew().isEmpty)
}

@Test func lineInTwoPiecesYieldsOneEventAfterSecondPiece() throws {
    let (log, url) = try makeLog()
    try append("p1 bu", to: url)
    #expect(log.readNew().isEmpty)
    try append("sy\n", to: url)
    #expect(log.readNew() == [HookEvent(pane: PaneID("p1"), state: .busy)])
}

@Test func linesAddedAfterTruncationAreRead() throws {
    let (log, url) = try makeLog()
    try append("p1 busy\np1 waiting\n", to: url)
    _ = log.readNew()
    try Data().write(to: url)
    try append("p2 busy\n", to: url)
    #expect(log.readNew() == [HookEvent(pane: PaneID("p2"), state: .busy)])
}

@Test func truncationDropsIncompleteLine() throws {
    let (log, url) = try makeLog()
    try append("p1 busy\np1 wai", to: url)
    _ = log.readNew()
    try Data().write(to: url)
    try append("p2 busy\n", to: url)
    #expect(log.readNew() == [HookEvent(pane: PaneID("p2"), state: .busy)])
}

@Test func unknownStateEmptyLineAndLineWithoutSpaceAreIgnored() throws {
    let (log, url) = try makeLog()
    try append("p1 sleeping\n\nnospace\np1 idle\np1 busy extra\n   \np2 busy\n", to: url)
    #expect(log.readNew() == [HookEvent(pane: PaneID("p2"), state: .busy)])
}

@Test func crlfLineEndingIsAccepted() throws {
    let (log, url) = try makeLog()
    try append("p1 busy\r\np1 waiting\r\n", to: url)
    #expect(log.readNew() == [
        HookEvent(pane: PaneID("p1"), state: .busy),
        HookEvent(pane: PaneID("p1"), state: .waiting),
    ])
}

@Test func surroundingWhitespaceIsIgnored() throws {
    let (log, url) = try makeLog()
    try append("  p1 waiting \t\n", to: url)
    #expect(log.readNew() == [HookEvent(pane: PaneID("p1"), state: .waiting)])
}

@Test func invalidUTF8LineIsIgnored() throws {
    let (log, url) = try makeLog()
    let handle = try FileHandle(forWritingTo: url)
    try handle.write(contentsOf: Data([0xFF, 0xFE, 0x0A]))
    try handle.close()
    try append("p1 busy\n", to: url)
    #expect(log.readNew() == [HookEvent(pane: PaneID("p1"), state: .busy)])
}
