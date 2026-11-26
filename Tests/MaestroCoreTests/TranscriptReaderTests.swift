import Foundation
import Testing
@testable import MaestroCore

private let projectPath = "/Users/x/proj/voorbeeld"

/// A string as a JSON string literal.
private func quoted(_ text: String) -> String {
    String(decoding: try! JSONEncoder().encode(text), as: UTF8.self)
}

/// Builds the lines of one made-up conversation file, in the key order and spacing of real files.
private struct Conversation {
    var lines: [String] = []
    private let hour: Int
    private let entrypoint: String
    private var minute = 0

    init(hour: Int = 0, entrypoint: String = "cli") {
        self.hour = hour
        self.entrypoint = entrypoint
    }

    /// The uuid of the next line and the fields that close it.
    private mutating func stamp() -> (uuid: String, tail: String) {
        minute += 1
        let uuid = "id-\(hour)-\(minute)"
        let time = String(format: "2026-01-01T%02d:%02d:00.000Z", hour, minute)
        let tail = "\"uuid\":\"\(uuid)\",\"timestamp\":\"\(time)\",\"userType\":\"external\",\"entrypoint\":\"\(entrypoint)\",\"cwd\":\"\(projectPath)\",\"sessionId\":\"s\"}"
        return (uuid, tail)
    }

    /// A user line with raw JSON as content; `extra` holds raw fields such as '"isMeta":true,'.
    @discardableResult mutating func user(content: String, extra: String = "") -> String {
        let (uuid, tail) = stamp()
        lines.append("{\"parentUuid\":null,\"isSidechain\":false,\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\(content)},\(extra)\(tail)")
        return uuid
    }

    @discardableResult mutating func user(_ text: String, extra: String = "") -> String {
        user(content: quoted(text), extra: extra)
    }

    /// An assistant line with raw JSON blocks as content.
    @discardableResult mutating func claude(blocks: [String], model: String = "claude-voorbeeld-1", extra: String = "") -> String {
        let (uuid, tail) = stamp()
        lines.append("{\"parentUuid\":null,\"isSidechain\":false,\"message\":{\"model\":\"\(model)\",\"id\":\"m\",\"type\":\"message\",\"role\":\"assistant\",\"content\":[\(blocks.joined(separator: ","))]},\"type\":\"assistant\",\(extra)\(tail)")
        return uuid
    }

    @discardableResult mutating func claude(_ text: String) -> String {
        claude(blocks: [textBlock(text)])
    }

    /// A system line; an away_summary carries its text in `content`.
    @discardableResult mutating func system(subtype: String, content: String = "") -> String {
        let (uuid, tail) = stamp()
        lines.append("{\"parentUuid\":null,\"isSidechain\":false,\"type\":\"system\",\"subtype\":\"\(subtype)\",\"content\":\(quoted(content)),\(tail)")
        return uuid
    }

    /// The two lines that `/clear` leaves in a new file.
    mutating func clearEnvelope() {
        user("<local-command-caveat>Voorbeeld van een omhulsel</local-command-caveat>", extra: "\"isMeta\":true,")
        user("<command-name>/clear</command-name>\n<command-message>clear</command-message>\n<command-args></command-args>")
    }

    var text: String { lines.map { $0 + "\n" }.joined() }
}

private func textBlock(_ text: String) -> String { "{\"type\":\"text\",\"text\":\(quoted(text))}" }
private let thinkingBlock = "{\"type\":\"thinking\",\"thinking\":\"even denken\",\"signature\":\"x\"}"
private let toolUseBlock = "{\"type\":\"tool_use\",\"id\":\"t1\",\"name\":\"Read\",\"input\":{\"file_path\":\"/Users/x/proj/voorbeeld/knop.css\"}}"
private let toolResultContent = "[{\"tool_use_id\":\"t1\",\"type\":\"tool_result\",\"content\":\"inhoud van het bestand\"}]"

/// A reader on a fresh root with the folder of the example project in it.
private func makeProject(blockSize: Int = 64 * 1024) throws -> (TranscriptReader, URL) {
    let root = try makeTempDir()
    let folder = root.appendingPathComponent(TranscriptReader.folderName(for: projectPath))
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return (TranscriptReader(root: root, blockSize: blockSize), folder)
}

/// Writes a conversation file; `age` is how many hours ago it was last modified.
private func write(_ text: String, to folder: URL, name: String = "a.jsonl", age: Double = 0) throws {
    let url = folder.appendingPathComponent(name)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -age * 3600)], ofItemAtPath: url.path)
}

/// Reads the example project after writing one conversation file.
private func read(_ conversation: Conversation, blockSize: Int = 64 * 1024) throws -> Transcript {
    let (reader, folder) = try makeProject(blockSize: blockSize)
    try write(conversation.text, to: folder)
    return reader.read(projectPath: projectPath)
}

private func turn(_ user: String, _ answer: String?) -> Transcript.Turn { Transcript.Turn(user: user, answer: answer) }

// MARK: - Folder name

@Test(arguments: [
    ("/Users/x/proj/voorbeeld", "-Users-x-proj-voorbeeld"),
    ("/Users/x/Sites/voorbeeld.nl", "-Users-x-Sites-voorbeeld-nl"),
    ("/Users/x/proj/a_b c", "-Users-x-proj-a-b-c"),
    ("/Users/x/.claude", "-Users-x--claude"),
    ("/Users/x/Proj/VoorBeeld9", "-Users-x-Proj-VoorBeeld9"),
    ("/Users/x/proj/café", "-Users-x-proj-caf-"),
])
func folderNameReplacesEverythingButLettersAndDigits(path: String, name: String) {
    #expect(TranscriptReader.folderName(for: path) == name)
}

// MARK: - Choosing the conversation

@Test func missingRootGivesEmptyResult() throws {
    let reader = TranscriptReader(root: try makeTempDir().appendingPathComponent("bestaat-niet"))
    #expect(reader.read(projectPath: projectPath).isEmpty)
}

@Test func missingProjectFolderGivesEmptyResult() throws {
    let transcript = TranscriptReader(root: try makeTempDir()).read(projectPath: projectPath)
    #expect(transcript.isEmpty)
    #expect(transcript.turns.isEmpty)
    #expect(transcript.fileName == nil)
    #expect(transcript.lastMessageUUID == nil)
    #expect(transcript.awaySummary == nil)
}

@Test func folderWithoutFilesGivesEmptyResult() throws {
    let (reader, _) = try makeProject()
    #expect(reader.read(projectPath: projectPath).isEmpty)
}

@Test func emptyFileGivesEmptyResult() throws {
    let (reader, folder) = try makeProject()
    try write("", to: folder)
    #expect(reader.read(projectPath: projectPath).isEmpty)
}

@Test func conversationWithTheLatestRealMessageIsRead() throws {
    let (reader, folder) = try makeProject()
    var old = Conversation(hour: 1), new = Conversation(hour: 2)
    old.user("oude vraag")
    new.user("maak de knop blauw")
    try write(old.text, to: folder, name: "old.jsonl", age: 2)
    try write(new.text, to: folder, name: "new.jsonl", age: 1)
    let transcript = reader.read(projectPath: projectPath)
    #expect(transcript.fileName == "new.jsonl")
    #expect(transcript.turns == [turn("maak de knop blauw", nil)])
}

@Test func newestFileWithOnlySystemAndCostLinesIsPassedOver() throws {
    let (reader, folder) = try makeProject()
    var old = Conversation(hour: 1), new = Conversation(hour: 2)
    old.user("maak de knop blauw")
    new.system(subtype: "turn_duration")
    new.lines.append("{\"type\":\"cost-state\",\"totalCostUSD\":0.12,\"sessionId\":\"s\"}")
    try write(old.text, to: folder, name: "old.jsonl", age: 2)
    try write(new.text, to: folder, name: "new.jsonl")
    #expect(reader.read(projectPath: projectPath).fileName == "old.jsonl")
}

@Test func newestFileWithOnlyTheClearEnvelopeIsPassedOver() throws {
    let (reader, folder) = try makeProject()
    var old = Conversation(hour: 1), new = Conversation(hour: 2)
    old.user("maak de knop blauw")
    new.clearEnvelope()
    try write(old.text, to: folder, name: "old.jsonl", age: 2)
    try write(new.text, to: folder, name: "new.jsonl")
    #expect(reader.read(projectPath: projectPath).fileName == "old.jsonl")
}

@Test func onlyFilesWithoutRealMessageGiveEmptyResult() throws {
    var conversation = Conversation()
    conversation.clearEnvelope()
    #expect(try read(conversation).isEmpty)
}

@Test func lastMessageTimeBeatsModificationTime() throws {
    let (reader, folder) = try makeProject()
    var resumed = Conversation(hour: 1), other = Conversation(hour: 5)
    resumed.user("oude vraag")
    other.user("maak de knop blauw")
    try write(resumed.text, to: folder, name: "resumed.jsonl")
    try write(other.text, to: folder, name: "other.jsonl", age: 24)
    #expect(reader.read(projectPath: projectPath).fileName == "other.jsonl")
}

@Test func conversationFromAnotherEntrypointIsSkipped() throws {
    let (reader, folder) = try makeProject()
    var cli = Conversation(hour: 1), sdk = Conversation(hour: 2, entrypoint: "sdk-cli")
    cli.user("maak de knop blauw")
    sdk.user("vraag van een script")
    try write(cli.text, to: folder, name: "cli.jsonl", age: 2)
    try write(sdk.text, to: folder, name: "sdk.jsonl")
    #expect(reader.read(projectPath: projectPath).fileName == "cli.jsonl")
}

@Test func otherEntrypointsDoNotCountAsOneOfTheThreeNewest() throws {
    let (reader, folder) = try makeProject()
    var cli = Conversation(hour: 1)
    cli.user("maak de knop blauw")
    try write(cli.text, to: folder, name: "cli.jsonl", age: 9)
    for index in 1...4 {
        var sdk = Conversation(hour: 2, entrypoint: "sdk-cli")
        sdk.user("vraag van een script")
        try write(sdk.text, to: folder, name: "sdk\(index).jsonl", age: Double(index))
    }
    #expect(reader.read(projectPath: projectPath).fileName == "cli.jsonl")
}

@Test func onlyTheThreeNewestFilesAreCandidates() throws {
    let (reader, folder) = try makeProject()
    for index in 1...4 {
        // The oldest file by modification time holds the newest message.
        var conversation = Conversation(hour: index)
        conversation.user("vraag \(index)")
        try write(conversation.text, to: folder, name: "c\(index).jsonl", age: Double(index))
    }
    #expect(reader.read(projectPath: projectPath).fileName == "c3.jsonl")
}

@Test func fileInSubfolderIsNotChosen() throws {
    let (reader, folder) = try makeProject()
    var conversation = Conversation()
    conversation.user("vraag van een subagent")
    try write(conversation.text, to: folder, name: "subagents/agent.jsonl")
    #expect(reader.read(projectPath: projectPath).isEmpty)
}

// MARK: - What counts as a message

@Test func userContentAsTextAndAsTextBlocksBothCount() throws {
    var conversation = Conversation()
    conversation.user("maak de knop blauw")
    conversation.user(content: "[\(textBlock("en de rand"))," + "\(textBlock("ook"))]")
    #expect(try read(conversation).turns == [turn("maak de knop blauw", nil), turn("en de rand\nook", nil)])
}

@Test func assistantLineYieldsOnlyItsText() throws {
    var conversation = Conversation()
    conversation.user("maak de knop blauw")
    conversation.claude(blocks: [thinkingBlock, textBlock("De knop is blauw."), toolUseBlock])
    #expect(try read(conversation).turns == [turn("maak de knop blauw", "De knop is blauw.")])
}

@Test func assistantLineWithoutTextDoesNotCount() throws {
    var conversation = Conversation()
    conversation.user("maak de knop blauw")
    let answer = conversation.claude("De knop is blauw.")
    conversation.claude(blocks: [thinkingBlock, toolUseBlock])
    conversation.claude(blocks: [textBlock("")])
    let transcript = try read(conversation)
    #expect(transcript.turns == [turn("maak de knop blauw", "De knop is blauw.")])
    #expect(transcript.lastMessageUUID == answer)
}

/// Each case is the raw content and the raw extra fields of a user line that is not HP speaking.
@Test(arguments: [
    (toolResultContent, ""),
    (quoted("Voorbeeld van een verborgen bericht"), "\"isMeta\":true,"),
    (quoted("Voorbeeld van een samenvatting"), "\"isCompactSummary\":true,"),
    (quoted("Voorbeeld van een melding"), "\"origin\":{\"kind\":\"task-notification\"},"),
    (quoted("<task-notification>klaar</task-notification>"), ""),
    (quoted("<command-name>/clear</command-name>"), ""),
    (quoted("<local-command-stdout>uitvoer</local-command-stdout>"), ""),
    (quoted("<local-command-caveat>omhulsel</local-command-caveat>"), ""),
    (quoted("<bash-input>ls</bash-input>"), ""),
    (quoted("<bash-stdout>knop.css</bash-stdout>"), ""),
    (quoted("[Request interrupted by user]"), ""),
    ("[\(textBlock("[Request interrupted by user for tool use]"))]", ""),
    (quoted("  \n"), ""),
])
func userLineThatIsNotFromHPDoesNotCount(content: String, extra: String) throws {
    var conversation = Conversation()
    conversation.user("maak de knop blauw")
    let answer = conversation.claude("De knop is blauw.")
    conversation.user(content: content, extra: extra)
    let transcript = try read(conversation)
    #expect(transcript.turns == [turn("maak de knop blauw", "De knop is blauw.")])
    #expect(transcript.lastMessageUUID == answer)
}

@Test func humanOriginCounts() throws {
    var conversation = Conversation()
    conversation.user("maak de knop blauw", extra: "\"origin\":{\"kind\":\"human\"},\"isMeta\":false,")
    #expect(try read(conversation).turns == [turn("maak de knop blauw", nil)])
}

@Test func slashCommandWithArgumentsCounts() throws {
    let command = "<command-message>hp:plan</command-message>\n<command-name>/hp:plan</command-name>\n<command-args>maak de knop blauw</command-args>"
    var conversation = Conversation()
    conversation.user(command)
    #expect(try read(conversation).turns == [turn(command, nil)])
}

@Test func syntheticAndApiErrorAnswersDoNotCount() throws {
    var conversation = Conversation()
    conversation.user("maak de knop blauw")
    let answer = conversation.claude("De knop is blauw.")
    conversation.claude(blocks: [textBlock("Voorbeeld zonder antwoord")], model: "<synthetic>")
    conversation.claude(blocks: [textBlock("Voorbeeld van een storing")], extra: "\"isApiErrorMessage\":true,")
    let transcript = try read(conversation)
    #expect(transcript.turns == [turn("maak de knop blauw", "De knop is blauw.")])
    #expect(transcript.lastMessageUUID == answer)
}

// MARK: - The window

@Test func onlyTheClosingAnswerOfATurnComesAlong() throws {
    var conversation = Conversation()
    conversation.user("maak de knop blauw")
    conversation.claude(blocks: [textBlock("Ik kijk eerst."), toolUseBlock])
    conversation.user(content: toolResultContent)
    conversation.claude(blocks: [textBlock("Nu de kleur."), toolUseBlock])
    conversation.user(content: toolResultContent)
    conversation.claude("De knop is blauw.")
    conversation.user("dank")
    #expect(try read(conversation).turns == [turn("maak de knop blauw", "De knop is blauw."), turn("dank", nil)])
}

@Test func twelveTurnsGiveTheLastEightInOrder() throws {
    var conversation = Conversation()
    for index in 1...12 {
        conversation.user("vraag \(index)")
        conversation.claude("antwoord \(index)")
    }
    #expect(try read(conversation).turns == (5...12).map { turn("vraag \($0)", "antwoord \($0)") })
}

@Test func longMessagesAreCutAtTwoThousandCharacters() throws {
    var conversation = Conversation()
    conversation.user(String(repeating: "é", count: 5000))
    conversation.claude(String(repeating: "b", count: 5000))
    let turns = try read(conversation).turns
    #expect(turns.first?.user == String(repeating: "é", count: 2000))
    #expect(turns.first?.answer == String(repeating: "b", count: 2000))
}

@Test func awaySummaryAfterTheLastMessageComesAlong() throws {
    var conversation = Conversation()
    conversation.user("maak de knop blauw")
    conversation.system(subtype: "away_summary", content: "Oude tussenstand.")
    conversation.claude("De knop is blauw.")
    conversation.system(subtype: "away_summary", content: "De knop is blauw, de rand nog niet.")
    #expect(try read(conversation).awaySummary == "De knop is blauw, de rand nog niet.")
}

@Test func awaySummaryBeforeTheLastMessageStaysOut() throws {
    var conversation = Conversation()
    conversation.user("maak de knop blauw")
    conversation.system(subtype: "away_summary", content: "Oude tussenstand.")
    conversation.claude("De knop is blauw.")
    let transcript = try read(conversation)
    #expect(transcript.awaySummary == nil)
    #expect(transcript.turns == [turn("maak de knop blauw", "De knop is blauw.")])
}

@Test func uuidIsThatOfTheLastRealMessage() throws {
    var conversation = Conversation()
    conversation.user("maak de knop blauw")
    let answer = conversation.claude("De knop is blauw.")
    conversation.system(subtype: "turn_duration")
    conversation.system(subtype: "away_summary", content: "Tussenstand.")
    conversation.lines.append("{\"type\":\"last-prompt\",\"lastPrompt\":\"maak de knop blauw\",\"sessionId\":\"s\"}")
    #expect(try read(conversation).lastMessageUUID == answer)
}

@Test func assistantTextWithoutAnyUserMessageGivesUUIDButNoTurns() throws {
    var conversation = Conversation()
    let answer = conversation.claude("De knop is blauw.")
    let transcript = try read(conversation)
    #expect(transcript.turns.isEmpty)
    #expect(transcript.lastMessageUUID == answer)
    #expect(!transcript.isEmpty)
}

// MARK: - Lines the reader does not understand

@Test func otherTypesAndBrokenLinesAreSkipped() throws {
    var conversation = Conversation()
    conversation.lines.append("{\"type\":\"mode\",\"mode\":\"normal\",\"sessionId\":\"s\"}")
    conversation.user("maak de knop blauw")
    conversation.lines += [
        "dit is geen JSON",
        "{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"afgebroken",
        "[\"type\":\"user\"]",
        "{\"type\":\"user\",\"message\":\"geen object\",\"uuid\":7,\"timestamp\":null}",
        "{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"zonder uuid\"},\"entrypoint\":\"cli\"}",
        "{\"type\":\"file-history-snapshot\",\"snapshot\":{\"note\":{\"type\":\"user\"}}}",
        "",
    ]
    conversation.claude("De knop is blauw.")
    conversation.lines.append("\u{FFFD}\u{0}\u{1}")
    #expect(try read(conversation).turns == [turn("maak de knop blauw", "De knop is blauw.")])
}

@Test func fileWithoutTrailingNewlineIsRead() throws {
    let (reader, folder) = try makeProject()
    var conversation = Conversation()
    conversation.user("maak de knop blauw")
    let answer = conversation.claude("De knop is blauw.")
    try write(conversation.lines.joined(separator: "\n"), to: folder)
    let transcript = reader.read(projectPath: projectPath)
    #expect(transcript.turns == [turn("maak de knop blauw", "De knop is blauw.")])
    #expect(transcript.lastMessageUUID == answer)
}

/// Tiny blocks split every line, and every multi-byte character, across block boundaries.
@Test(arguments: [1, 2, 3, 7, 16, 100, 1000])
func blockBoundariesDoNotChangeTheResult(blockSize: Int) throws {
    var conversation = Conversation()
    for index in 1...3 {
        conversation.user("vraag \(index): één café ☕ voor de 👩‍💻")
        conversation.claude("antwoord \(index): crème brûlée 🍮")
    }
    conversation.system(subtype: "away_summary", content: "Tussenstand: klaar ✅")
    let whole = try read(conversation), blocks = try read(conversation, blockSize: blockSize)
    #expect(blocks.turns == whole.turns)
    #expect(blocks.turns.count == 3)
    #expect(blocks.turns.last == turn("vraag 3: één café ☕ voor de 👩‍💻", "antwoord 3: crème brûlée 🍮"))
    #expect(blocks.awaySummary == "Tussenstand: klaar ✅")
    #expect(blocks.lastMessageUUID == whole.lastMessageUUID)
}

// MARK: - Memory

/// A tool result line of the given size that would count as a message of HP if it were decoded.
private func hugeToolResultLine(bytes: Int) -> String {
    var conversation = Conversation(hour: 23)
    conversation.user(String(repeating: "x", count: bytes), extra: "\"sourceToolAssistantUUID\":\"t1\",")
    return conversation.lines[0]
}

@Test func twentyMegabyteFileIsReadFromTheEnd() throws {
    let (reader, folder) = try makeProject()
    defer { try? FileManager.default.removeItem(at: folder) }
    try write("", to: folder)
    let filler = hugeToolResultLine(bytes: 1024 * 1024) + "\n"
    for _ in 1...20 { try append(filler, to: folder.appendingPathComponent("a.jsonl")) }
    // Eight turns of 12 KB each: the window sits in the last 100 KB.
    var conversation = Conversation()
    for index in 1...8 {
        conversation.user("vraag \(index) " + String(repeating: "v", count: 6000))
        conversation.claude("antwoord \(index) " + String(repeating: "a", count: 6000))
    }
    try append(conversation.text, to: folder.appendingPathComponent("a.jsonl"))

    let transcript = reader.read(projectPath: projectPath)
    #expect(transcript.turns.count == 8)
    #expect(transcript.turns.first?.user.hasPrefix("vraag 1 ") == true)
    #expect(transcript.turns.last?.answer?.hasPrefix("antwoord 8 ") == true)
    #expect(transcript.bytesRead > 0)
    #expect(transcript.bytesRead < 2_000_000)
}

@Test func hugeToolResultBetweenTwoTurnsIsSkippedWithoutDecoding() throws {
    var conversation = Conversation()
    conversation.user("maak de knop blauw")
    conversation.claude("De knop is blauw.")
    conversation.lines.append(hugeToolResultLine(bytes: 1024 * 1024))
    conversation.user("en nu de rand")
    conversation.claude("De rand is rood.")
    #expect(try read(conversation).turns == [turn("maak de knop blauw", "De knop is blauw."), turn("en nu de rand", "De rand is rood.")])
}
