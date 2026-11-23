import Foundation

/// Generates the Claude Code settings file that reports pane state through hooks.
public enum HookSettings {
    private static let hooks: [(event: String, matcher: String?, state: AttentionState)] = [
        ("UserPromptSubmit", nil, .busy),
        ("PostToolUse", nil, .busy),
        ("Stop", nil, .waiting),
        ("PreToolUse", "AskUserQuestion", .waiting),
        ("PermissionRequest", nil, .waiting),
        ("Notification", "idle_prompt|agent_needs_input|elicitation_dialog|permission_prompt", .waiting),
    ]

    /// Settings JSON with one hook per event; each appends '<pane-id> <state>' to the events file.
    /// Stop reads its payload on stdin and stays silent while 'background_tasks' holds a running task.
    public static func json() throws -> Data {
        let entries = hooks.map { hook -> (String, [[String: Any]]) in
            let report = "echo \"$CLAUDESHELL_PANE \(hook.state.rawValue)\" >> \"$CLAUDESHELL_EVENTS\""
            // A turn that ends with background tasks still running is not finished: Claude resumes by itself.
            let command = hook.event == "Stop" ? #"grep -q '"status": *"running"' || "# + report : report
            var entry: [String: Any] = ["hooks": [["type": "command", "command": command]]]
            entry["matcher"] = hook.matcher
            return (hook.event, [entry])
        }
        return try JSONSerialization.data(
            withJSONObject: ["hooks": Dictionary(uniqueKeysWithValues: entries)],
            options: [.prettyPrinted, .sortedKeys]
        )
    }
}
