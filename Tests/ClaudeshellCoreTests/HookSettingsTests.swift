import Foundation
import Testing
@testable import ClaudeshellCore

private let expectedHooks: [(event: String, matcher: String?, state: String)] = [
    ("UserPromptSubmit", nil, "busy"),
    ("PostToolUse", nil, "busy"),
    ("Stop", nil, "waiting"),
    ("PreToolUse", "AskUserQuestion", "waiting"),
    ("PermissionRequest", nil, "waiting"),
    ("Notification", "idle_prompt|agent_needs_input|elicitation_dialog|permission_prompt", "waiting"),
]

/// The generated 'hooks' object: event name to its list of entries.
private func generatedHooks() throws -> [String: [[String: Any]]] {
    let root = try JSONSerialization.jsonObject(with: HookSettings.json()) as? [String: Any]
    return try #require(root?["hooks"] as? [String: [[String: Any]]])
}

/// The single command of one hook event.
private func command(for event: String) throws -> String {
    let entry = try #require(try generatedHooks()[event]?.first)
    let hook = try #require((entry["hooks"] as? [[String: String]])?.first)
    return try #require(hook["command"])
}

@Test func settingsHoldOnlyHooks() throws {
    let root = try #require(try JSONSerialization.jsonObject(with: HookSettings.json()) as? [String: Any])
    #expect(Array(root.keys) == ["hooks"])
}

@Test func settingsHoldExactlyTheSixHookEvents() throws {
    #expect(Set(try generatedHooks().keys) == Set(expectedHooks.map(\.event)))
}

@Test func everyEventHasOneEntryWithOneCommandHook() throws {
    for (event, entries) in try generatedHooks() {
        #expect(entries.count == 1, "\(event)")
        let hooks = try #require(entries.first?["hooks"] as? [[String: String]])
        #expect(hooks.count == 1, "\(event)")
        #expect(hooks.first?["type"] == "command", "\(event)")
    }
}

@Test func everyEventHasTheRightMatcherOrNoMatcherKey() throws {
    let hooks = try generatedHooks()
    for expected in expectedHooks {
        let entry = try #require(hooks[expected.event]?.first)
        #expect(entry["matcher"] as? String == expected.matcher, "\(expected.event)")
        #expect(Set(entry.keys) == (expected.matcher == nil ? ["hooks"] : ["hooks", "matcher"]), "\(expected.event)")
    }
}

@Test func everyCommandAppendsTheRightStateToTheEventsFile() throws {
    for expected in expectedHooks {
        let expectedCommand = #"echo "$CLAUDESHELL_PANE \#(expected.state)" >> "$CLAUDESHELL_EVENTS""#
        #expect(try command(for: expected.event).hasSuffix(expectedCommand), "\(expected.event)")
    }
}

/// Runs a hook command the way Claude Code does: through sh, with the pane environment and a JSON payload on stdin.
private func runHook(_ event: String, pane: PaneID, events: URL, payload: String = "{}") throws {
    let process = Process(), stdin = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", try command(for: event)]
    process.environment = ["CLAUDESHELL_PANE": pane.rawValue, "CLAUDESHELL_EVENTS": events.path]
    process.standardInput = stdin
    try process.run()
    stdin.fileHandleForWriting.write(Data(payload.utf8))
    try stdin.fileHandleForWriting.close()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0)
}

@MainActor @Test func stopWithRunningBackgroundTaskKeepsThePaneBusy() throws {
    let log = HookEventLog(fileURL: try makeTempDir().appendingPathComponent("events"))
    log.reset()
    let tracker = AttentionTracker(), pane = PaneID(), project = UUID()
    tracker.register(pane, kind: .claude, project: project)
    try runHook("UserPromptSubmit", pane: pane, events: log.fileURL)

    // Payloads as Claude Code 2.1.319 sends them; a quoted lookalike in the message must not count.
    let running = #"{"hook_event_name":"Stop","background_tasks":[{"id":"b1","type":"shell","status":"running"}]}"#
    try runHook("Stop", pane: pane, events: log.fileURL, payload: running)
    #expect(log.readNew().map { tracker.apply($0) } == [false])
    #expect(tracker.state(of: project) == .busy)

    let done = #"{"hook_event_name":"Stop","last_assistant_message":"\"status\":\"running\"","background_tasks":[]}"#
    try runHook("Stop", pane: pane, events: log.fileURL, payload: done)
    #expect(log.readNew().map { tracker.apply($0) } == [true])
    #expect(tracker.state(of: project) == .waiting)
}

@MainActor @Test func hookCommandsDriveTileStateThroughTheEventsFile() throws {
    let log = HookEventLog(fileURL: try makeTempDir().appendingPathComponent("dir with space/events"))
    log.reset()
    let tracker = AttentionTracker(), pane = PaneID(), project = UUID()
    tracker.register(pane, kind: .claude, project: project)

    try runHook("UserPromptSubmit", pane: pane, events: log.fileURL)
    #expect(log.readNew().map { tracker.apply($0) } == [false])
    #expect(tracker.state(of: project) == .busy)

    try runHook("Stop", pane: pane, events: log.fileURL)
    #expect(log.readNew().map { tracker.apply($0) } == [true])
    #expect(tracker.state(of: project) == .waiting)
}
