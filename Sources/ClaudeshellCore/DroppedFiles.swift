/// Files dropped on a pane, as the text a terminal pastes for them.
public enum DroppedFiles {
    /// The paths with a backslash before every character the shell would read, as Terminal.app does,
    /// separated by spaces and with one behind, so typing can go on. Claude Code attaches a pasted image path.
    public static func pasteText(_ paths: [String]) -> String {
        paths.map { $0.replacing(/[^\w\/.+@%:,-]/) { "\\" + $0.output } + " " }.joined()
    }
}
