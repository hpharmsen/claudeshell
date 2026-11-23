import Foundation
import Testing
@testable import ClaudeshellCore

/// A support folder that does not exist yet.
private func tempSupportFolder() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("claudeshell-tests-\(UUID().uuidString)")
}

private let fingerprint = SummaryFingerprint(conversationFile: "gesprek-1.jsonl", lastMessageUUID: "bericht-42",
                                             headCommit: "0123abc")

@Test func summaryIsWrittenAndReadBackUnchanged() {
    let folder = tempSupportFolder(), id = UUID()
    let summary = ProjectSummary(text: "Voorbeeld: de strook staat, de tests nog niet.\nVolgende stap: U2.",
                                 date: Date(), fingerprint: fingerprint)
    summary.write(for: id, in: folder)
    let loaded = ProjectSummary.read(for: id, in: folder)
    #expect(loaded == summary)
    #expect(loaded?.text == summary.text)
    #expect(loaded?.date == summary.date)
    #expect(loaded?.fingerprint == fingerprint)
}

@Test func summaryWithEmptyFingerprintAndEmptyTextRoundTrips() {
    let folder = tempSupportFolder(), id = UUID()
    let summary = ProjectSummary(text: "", date: Date(timeIntervalSince1970: 1_800_000_000.25), fingerprint: SummaryFingerprint())
    summary.write(for: id, in: folder)
    #expect(ProjectSummary.read(for: id, in: folder) == summary)
}

@Test func summaryIsStoredInSummariesFolderUnderTheProjectID() {
    let folder = tempSupportFolder(), id = UUID()
    let url = ProjectSummary.fileURL(for: id, in: folder)
    #expect(url.path == folder.appendingPathComponent("summaries/\(id.uuidString).json").path)
    #expect(!FileManager.default.fileExists(atPath: folder.appendingPathComponent("summaries").path))
    ProjectSummary(text: "a", date: Date(), fingerprint: fingerprint).write(for: id, in: folder)
    #expect(FileManager.default.fileExists(atPath: url.path))
}

@Test func writingReplacesTheEarlierSummary() {
    let folder = tempSupportFolder(), id = UUID()
    ProjectSummary(text: "oud", date: Date(), fingerprint: fingerprint).write(for: id, in: folder)
    ProjectSummary(text: "nieuw", date: Date(), fingerprint: SummaryFingerprint(headCommit: "fff")).write(for: id, in: folder)
    let loaded = ProjectSummary.read(for: id, in: folder)
    #expect(loaded?.text == "nieuw")
    #expect(loaded?.fingerprint == SummaryFingerprint(headCommit: "fff"))
}

@Test func everyProjectHasItsOwnSummary() {
    let folder = tempSupportFolder(), one = UUID(), two = UUID()
    ProjectSummary(text: "een", date: Date(), fingerprint: fingerprint).write(for: one, in: folder)
    #expect(ProjectSummary.read(for: one, in: folder)?.text == "een")
    #expect(ProjectSummary.read(for: two, in: folder) == nil)
}

@Test func readingWithoutFileGivesNothing() {
    #expect(ProjectSummary.read(for: UUID(), in: tempSupportFolder()) == nil)
}

@Test(arguments: ["", "onzin", "{ kapot", "{\"text\": \"zonder moment\"}", "[]"])
func readingUnreadableFileGivesNothing(content: String) throws {
    let folder = tempSupportFolder(), id = UUID()
    let url = ProjectSummary.fileURL(for: id, in: folder)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(content.utf8).write(to: url)
    #expect(ProjectSummary.read(for: id, in: folder) == nil)
}

@Test func deletedSummaryIsGone() {
    let folder = tempSupportFolder(), id = UUID(), other = UUID()
    let summary = ProjectSummary(text: "a", date: Date(), fingerprint: fingerprint)
    summary.write(for: id, in: folder)
    summary.write(for: other, in: folder)
    ProjectSummary.delete(for: id, in: folder)
    #expect(ProjectSummary.read(for: id, in: folder) == nil)
    #expect(!FileManager.default.fileExists(atPath: ProjectSummary.fileURL(for: id, in: folder).path))
    #expect(ProjectSummary.read(for: other, in: folder) == summary)
}

@Test func deletingMissingSummaryGivesNoError() {
    let folder = tempSupportFolder()
    ProjectSummary.delete(for: UUID(), in: folder)
    #expect(!FileManager.default.fileExists(atPath: folder.path))
}

// MARK: Fingerprint

@Test func fingerprintsWithTheSameValuesAreEqual() {
    #expect(fingerprint == SummaryFingerprint(conversationFile: "gesprek-1.jsonl", lastMessageUUID: "bericht-42",
                                              headCommit: "0123abc"))
    #expect(SummaryFingerprint() == SummaryFingerprint(conversationFile: nil, lastMessageUUID: nil, headCommit: nil))
}

@Test(arguments: [
    SummaryFingerprint(conversationFile: "gesprek-2.jsonl", lastMessageUUID: "bericht-42", headCommit: "0123abc"),
    SummaryFingerprint(conversationFile: "gesprek-1.jsonl", lastMessageUUID: "bericht-43", headCommit: "0123abc"),
    SummaryFingerprint(conversationFile: "gesprek-1.jsonl", lastMessageUUID: "bericht-42", headCommit: "fff"),
    SummaryFingerprint(conversationFile: "gesprek-1.jsonl", lastMessageUUID: "bericht-42"),
    SummaryFingerprint(),
]) func fingerprintDiffersWhenOnePartDiffers(other: SummaryFingerprint) {
    #expect(other != fingerprint)
}
