import Foundation
import Testing
@testable import ClaudeshellCore

// MARK: - Helpers

private let claude = "/voorbeeld/bin/claude"
private let goodText = "De knop is blauw gemaakt. De tests voor de strook staan nog open."

/// The JSON that `claude -p --output-format json` prints.
private func claudeJSON(_ result: String, isError: Bool = false) -> String {
    let fields: [String: Any] = ["type": "result", "subtype": "success", "is_error": isError, "result": result,
                                 "api_error_status": isError ? 401 : NSNull(), "terminal_reason": "completed"]
    return String(decoding: try! JSONSerialization.data(withJSONObject: fields), as: UTF8.self)
}

/// Records every call; git goes to the real git, `claude` and `zsh` get a fixed answer or throw.
private final class RunStub: @unchecked Sendable {
    typealias Call = (program: String, arguments: [String], directory: URL, input: String?, timeout: TimeInterval)

    private let lock = NSLock()
    private var log: [Call] = []
    private var fixed: Result<String, SubprocessError> = .success(claudeJSON(goodText))

    /// What `claude` and `zsh` answer from now on.
    var answer: Result<String, SubprocessError> {
        get { lock.withLock { fixed } }
        set { lock.withLock { fixed = newValue } }
    }

    var calls: [Call] { lock.withLock { log } }
    var claudeCalls: [Call] { calls.filter { $0.program == claude } }

    var run: ProcessRunner {
        { program, arguments, directory, input, timeout in
            self.lock.withLock { self.log.append((program, arguments, directory, input, timeout)) }
            if program == "/usr/bin/git" { return try await Subprocess.run(program, arguments, directory, input, timeout) }
            return try self.answer.get()
        }
    }
}

/// One made-up line of a conversation file; `n` makes its uuid and its minute.
private func line(_ n: Int, _ fields: String) -> String {
    let time = String(format: "2026-01-01T10:%02d:00.000Z", n)
    return "{\(fields),\"uuid\":\"id-\(n)\",\"timestamp\":\"\(time)\",\"entrypoint\":\"cli\"}\n"
}

private func quoted(_ text: String) -> String { String(decoding: try! JSONEncoder().encode(text), as: UTF8.self) }

private func user(_ n: Int, _ text: String, extra: String = "") -> String {
    line(n, "\"type\":\"user\",\(extra)\"message\":{\"role\":\"user\",\"content\":\(quoted(text))}")
}

private func reply(_ n: Int, _ text: String) -> String {
    line(n, "\"type\":\"assistant\",\"message\":{\"model\":\"claude-voorbeeld-1\",\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\(quoted(text))}]}")
}

private func system(_ n: Int, subtype: String, content: String = "") -> String {
    line(n, "\"type\":\"system\",\"subtype\":\"\(subtype)\",\"content\":\(quoted(content))")
}

/// A made-up project in its own temp folders: a project folder, a conversation folder and a support folder.
private struct Fixture {
    let project: Project
    let folder: URL
    let conversations: URL
    let support: URL
    let stub = RunStub()
    let writer: SummaryWriter

    /// With `repo` the project folder is a repository with one commit; with `conversation` it has one turn.
    init(repo: Bool = true, conversation: Bool = true) async throws {
        // Claude Code names the conversation folder after the real path, and the temp folder is a symlink.
        let root = URL(fileURLWithPath: try #require(realpath(try makeTempDir().path, nil).map { pointer in
            defer { free(pointer) }
            return String(cString: pointer)
        }))
        folder = root.appendingPathComponent("voorbeeld")
        support = root.appendingPathComponent("support")
        let transcripts = root.appendingPathComponent("gesprekken")
        conversations = transcripts.appendingPathComponent(TranscriptReader.folderName(for: folder.path))
        for url in [folder, conversations] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        project = Project(name: "Voorbeeld", path: folder.path, color: "#336699")
        writer = SummaryWriter(supportFolder: support, claudePath: claude, run: stub.run,
                               transcripts: TranscriptReader(root: transcripts))
        if repo {
            try await git("init", "--initial-branch=main")
            try await git("config", "user.name", "Test Gebruiker")
            try await git("config", "user.email", "test@voorbeeld.nl")
            try await git("config", "commit.gpgsign", "false")
            try await commit("knop.css", subject: "maak de knop blauw")
        }
        if conversation {
            try say(user(1, "maak de knop blauw") + reply(2, "De knop is nu blauw."))
        }
    }

    @discardableResult func git(_ arguments: String...) async throws -> String {
        try await Subprocess.run("/usr/bin/git", arguments, folder, nil, 10)
    }

    func commit(_ file: String, subject: String) async throws {
        try Data(file.utf8).write(to: folder.appendingPathComponent(file))
        try await git("add", "-A")
        try await git("commit", "-m", subject)
    }

    /// Appends lines to a conversation file, creating it when it is missing.
    func say(_ lines: String, file: String = "a.jsonl") throws {
        let url = conversations.appendingPathComponent(file)
        let old = (try? Data(contentsOf: url)) ?? Data()
        try (old + Data(lines.utf8)).write(to: url)
    }

    /// Writes a file in the project folder, creating its folder.
    func document(_ path: String, _ text: String) throws {
        let url = folder.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    func update(force: Bool = false) async -> SummaryWriter.Outcome { await writer.update(project, force: force) }

    var stored: ProjectSummary? { ProjectSummary.read(for: project.id, in: support) }
    var storedBytes: Data? { try? Data(contentsOf: ProjectSummary.fileURL(for: project.id, in: support)) }
    var input: String { stub.claudeCalls.last?.input ?? "" }

    /// Makes a first summary and returns the bytes of its file.
    func firstSummary() async throws -> Data {
        guard case .updated = await update() else { throw SubprocessError.launchFailed("no first summary") }
        return try #require(storedBytes)
    }

    /// Expects that a second update makes no call and leaves the file as it is.
    func expectUnchanged(since bytes: Data) async {
        #expect(await update() == .unchanged)
        #expect(stub.claudeCalls.count == 1)
        #expect(storedBytes == bytes)
    }

    /// Expects that an update with this answer of `claude` fails and leaves the earlier summary as it is.
    func expectFailure(_ answer: Result<String, SubprocessError>) async throws {
        let bytes = try await firstSummary()
        stub.answer = answer
        #expect(await update(force: true) == .failed)
        #expect(stub.claudeCalls.count == 2)
        #expect(storedBytes == bytes)
    }
}

// MARK: - Making a summary

@Test func firstUpdateCallsClaudeOnceAndStoresTheResult() async throws {
    let fixture = try await Fixture()
    let outcome = await fixture.update()
    let stored = try #require(fixture.stored)
    #expect(outcome == .updated(stored))
    #expect(fixture.stub.claudeCalls.count == 1)
    #expect(stored.text == goodText)
    #expect(stored.fingerprint.conversationFile == "a.jsonl")
    #expect(stored.fingerprint.lastMessageUUID == "id-2")
    #expect(stored.fingerprint.headCommit == (try await fixture.git("rev-parse", "HEAD")).trimmingCharacters(in: .whitespacesAndNewlines))
}

@Test func claudeIsCalledWithTheFixedFlagsInTheSupportFolder() async throws {
    let fixture = try await Fixture()
    _ = await fixture.update()
    let call = try #require(fixture.stub.claudeCalls.first)
    #expect(call.arguments == ["-p", "--model", "haiku", "--safe-mode", "--no-session-persistence", "--tools", "",
                               "--strict-mcp-config", "--disable-slash-commands", "--output-format", "json",
                               "--system-prompt", SummaryWriter.instruction])
    #expect(call.program == claude)
    #expect(call.directory == fixture.support)
    #expect(call.directory != fixture.folder)
    #expect(call.timeout == 60)
    #expect(FileManager.default.fileExists(atPath: fixture.support.path))
}

@Test func instructionAsksForDutchSentencesAndCallsTheInputMaterial() {
    let instruction = SummaryWriter.instruction
    #expect(instruction.contains("Nederlands"))
    #expect(instruction.contains("materiaal"))
    #expect(instruction.contains("geen opdracht"))
    #expect(!instruction.contains("\u{2014}"))
}

@Test func inputHoldsTheLastTurnTheLastCommitAndTheNewestPlan() async throws {
    let fixture = try await Fixture()
    try fixture.say(user(3, "zet de tekst in het midden") + reply(4, "De tekst staat nu in het midden."))
    try await fixture.commit("tekst.css", subject: "zet de tekst in het midden")
    try fixture.document("docs/plans/2026-01-01-001-oud-plan.md", "Het oude plan van Voorbeeld")
    try fixture.document("docs/plans/2026-02-01-001-nieuw-plan.md", "Het nieuwe plan van Voorbeeld")
    try fixture.document("docs/plans/2026-03-01-001-notities.md", "Losse notities zonder plan")
    try fixture.document("docs/handoff/README.md", "De overdracht van Voorbeeld")
    _ = await fixture.update()
    let input = fixture.input
    #expect(input.contains("maak de knop blauw"))
    #expect(input.contains("zet de tekst in het midden"))
    #expect(input.contains("De tekst staat nu in het midden."))
    #expect(input.contains("Het nieuwe plan van Voorbeeld"))
    #expect(input.contains("De overdracht van Voorbeeld"))
    #expect(input.contains("main"))
    #expect(!input.contains("Het oude plan"))
    #expect(!input.contains("Losse notities"))
    #expect(!input.contains(SummaryWriter.instruction))
}

@Test func inputHoldsTheAwaySummary() async throws {
    let fixture = try await Fixture()
    try fixture.say(system(3, subtype: "away_summary", content: "Tussenstand: de knop is klaar."))
    _ = await fixture.update()
    #expect(fixture.input.contains("Tussenstand: de knop is klaar."))
}

@Test func planAndHandoffAreCutAtFourThousandCharacters() async throws {
    let fixture = try await Fixture()
    try fixture.document("docs/plans/2026-02-01-001-lang-plan.md", String(repeating: "@", count: 10_000))
    try fixture.document("docs/handoff/README.md", String(repeating: "%", count: 10_000))
    _ = await fixture.update()
    #expect(fixture.input.count { $0 == "@" } == 4000)
    #expect(fixture.input.count { $0 == "%" } == 4000)
}

@Test func resultOfNineHundredCharactersIsStoredAsFourHundred() async throws {
    let fixture = try await Fixture()
    fixture.stub.answer = .success(claudeJSON("  \n" + String(repeating: "a", count: 900) + "\n"))
    _ = await fixture.update()
    #expect(fixture.stored?.text == String(repeating: "a", count: 400))
}

@Test func projectWithoutConversationButWithRepoIsSummarisedFromTheRepo() async throws {
    let fixture = try await Fixture(conversation: false)
    guard case .updated(let summary) = await fixture.update() else {
        Issue.record("no summary")
        return
    }
    #expect(fixture.stub.claudeCalls.count == 1)
    #expect(fixture.input.contains("maak de knop blauw"))
    #expect(!fixture.input.contains("HP:"))
    #expect(summary.fingerprint.conversationFile == nil)
    #expect(summary.fingerprint.lastMessageUUID == nil)
    #expect(summary.fingerprint.headCommit != nil)
}

@Test func projectWithoutConversationAndWithoutRepoMakesNoCall() async throws {
    let fixture = try await Fixture(repo: false, conversation: false)
    #expect(await fixture.update() == .unchanged)
    #expect(await fixture.update(force: true) == .unchanged)
    #expect(fixture.stub.claudeCalls.isEmpty)
    #expect(fixture.stored == nil)
}

@Test func projectWithConversationButWithoutRepoIsSummarised() async throws {
    let fixture = try await Fixture(repo: false)
    guard case .updated(let summary) = await fixture.update() else {
        Issue.record("no summary")
        return
    }
    #expect(fixture.input.contains("maak de knop blauw"))
    #expect(summary.fingerprint.headCommit == nil)
}

// MARK: - The fingerprint

@Test func secondUpdateWithoutNewsMakesNoCall() async throws {
    let fixture = try await Fixture()
    try await fixture.expectUnchanged(since: fixture.firstSummary())
}

@Test func systemAndCostStateLinesAreNoNews() async throws {
    let fixture = try await Fixture()
    let bytes = try await fixture.firstSummary()
    try fixture.say(system(3, subtype: "turn_duration") + "{\"type\":\"cost-state\",\"entrypoint\":\"cli\"}\n")
    await fixture.expectUnchanged(since: bytes)
}

@Test func awaySummaryIsNoNews() async throws {
    let fixture = try await Fixture()
    let bytes = try await fixture.firstSummary()
    try fixture.say(system(3, subtype: "away_summary", content: "Tussenstand: de knop is klaar."))
    await fixture.expectUnchanged(since: bytes)
}

@Test func newFileWithOnlyTheClearEnvelopeIsNoNews() async throws {
    let fixture = try await Fixture()
    let bytes = try await fixture.firstSummary()
    try fixture.say(user(3, "<local-command-caveat>Voorbeeld van een omhulsel</local-command-caveat>", extra: "\"isMeta\":true,")
        + user(4, "<command-name>/clear</command-name>\n<command-message>clear</command-message>"), file: "b.jsonl")
    await fixture.expectUnchanged(since: bytes)
}

@Test func newMessageLeadsToANewCall() async throws {
    let fixture = try await Fixture()
    _ = try await fixture.firstSummary()
    try fixture.say(user(3, "zet de tekst in het midden"))
    fixture.stub.answer = .success(claudeJSON("De tekst staat in het midden."))
    #expect(await fixture.update() == .updated(try #require(fixture.stored)))
    #expect(fixture.stub.claudeCalls.count == 2)
    #expect(fixture.stored?.text == "De tekst staat in het midden.")
    #expect(fixture.stored?.fingerprint.lastMessageUUID == "id-3")
}

@Test func newCommitWithoutNewMessageLeadsToANewCall() async throws {
    let fixture = try await Fixture()
    _ = try await fixture.firstSummary()
    let first = try #require(fixture.stored)
    try await fixture.commit("tekst.css", subject: "zet de tekst in het midden")
    guard case .updated(let second) = await fixture.update() else {
        Issue.record("no summary")
        return
    }
    #expect(fixture.stub.claudeCalls.count == 2)
    #expect(second.fingerprint.headCommit != first.fingerprint.headCommit)
    #expect(second.fingerprint.lastMessageUUID == first.fingerprint.lastMessageUUID)
}

@Test func forceWithTheSameFingerprintLeadsToANewCall() async throws {
    let fixture = try await Fixture()
    _ = try await fixture.firstSummary()
    guard case .updated = await fixture.update(force: true) else {
        Issue.record("no summary")
        return
    }
    #expect(fixture.stub.claudeCalls.count == 2)
}

// MARK: - Failure

@Test func runErrorLeavesTheFileAsItWas() async throws {
    try await Fixture().expectFailure(.failure(.timedOut))
}

@Test func errorAnswerWithSubtypeSuccessIsAFailure() async throws {
    let fixture = try await Fixture()
    try await fixture.expectFailure(.success(claudeJSON("Invalid API key · Please run /login", isError: true)))
    #expect(fixture.stored?.text == goodText)
}

@Test func nonZeroExitCodeWithValidJSONIsAFailure() async throws {
    try await Fixture().expectFailure(.failure(.failed(exitCode: 1, output: claudeJSON(goodText))))
}

@Test func answerThatIsNoJSONIsAFailure() async throws {
    try await Fixture().expectFailure(.success("Voorbeeld van uitvoer die geen JSON is"))
}

@Test func emptyResultIsAFailure() async throws {
    try await Fixture().expectFailure(.success(claudeJSON(" \n ")))
}

@Test func failureWithoutEarlierSummaryWritesNoFile() async throws {
    let fixture = try await Fixture()
    fixture.stub.answer = .failure(.failed(exitCode: 1, output: ""))
    #expect(await fixture.update() == .failed)
    #expect(fixture.storedBytes == nil)
}

// MARK: - The path of claude

@Test func fixedPathThatExistsNeedsNoShell() async throws {
    let file = try makeTempDir().appendingPathComponent("claude")
    try Data().write(to: file)
    let stub = RunStub()
    #expect(await SummaryWriter.claudePath(run: stub.run, fixedPath: file.path) == file.path)
    #expect(stub.calls.isEmpty)
}

@Test func missingFixedPathAsksTheShellOnceAndTakesTheLastLine() async throws {
    let missing = try makeTempDir().appendingPathComponent("claude").path
    let stub = RunStub()
    stub.answer = .success("Voorbeeld van een welkomstregel\n/voorbeeld/elders/claude\n")
    #expect(await SummaryWriter.claudePath(run: stub.run, fixedPath: missing) == "/voorbeeld/elders/claude")
    #expect(stub.calls.count == 1)
    #expect(stub.calls.first?.program == "/bin/zsh")
    #expect(stub.calls.first?.arguments == ["-lic", "command -v claude"])
}

@Test(arguments: [Result<String, SubprocessError>.success(""), .success(" \n"), .failure(.failed(exitCode: 1, output: ""))])
private func missingFixedPathAndSilentShellGiveNoPath(answer: Result<String, SubprocessError>) async throws {
    let missing = try makeTempDir().appendingPathComponent("claude").path
    let stub = RunStub()
    stub.answer = answer
    #expect(await SummaryWriter.claudePath(run: stub.run, fixedPath: missing) == nil)
    #expect(stub.calls.count == 1)
}
