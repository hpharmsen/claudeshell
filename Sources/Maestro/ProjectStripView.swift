import AppKit
import MaestroCore
import SwiftUI

/// A hosting view that never takes the focus, so a click in it leaves the typing in the terminal pane (KTD5).
final class PassiveHostingView<Content: View>: NSHostingView<Content> {
    override var acceptsFirstResponder: Bool { false }
}

/// The strip below the tiles bar: the summary of the selected project first, then its git state, workflow step and links.
struct ProjectStripView: View {
    /// Always the same, with or without data, so arriving data never moves the terminals (KTD1).
    static let height: CGFloat = 62
    private static let ink = Color(hex: "#24292F")
    private static let gray = Color(hex: "#6E7781")
    private static let line = Color(hex: "#D0D7DE")
    private static let rowHeight: CGFloat = 16

    let store: ProjectStore
    let info: ProjectInfoStore
    unowned let actions: MainWindowController

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let id = store.selectedID {
                let data = info.info(id)
                summary(data, of: id)
                Rectangle().fill(Self.line).frame(width: 1)
                facts(data, of: id)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Self.ink)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: Self.height)
        .background(Color.white)
        .overlay(alignment: .bottom) { Rectangle().fill(Self.line).frame(height: 1) }
        .environment(\.colorScheme, .light)
    }

    /// The summary on at most three lines, with its date behind it, and the refresh button.
    private func summary(_ data: ProjectInfo, of id: Project.ID) -> some View {
        HStack(alignment: .top, spacing: 6) {
            summaryText(data)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Kopieer samenvatting") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(data.summary?.text ?? "", forType: .string)
                    }
                    .disabled(data.summary == nil)
                }
            Group {
                if info.isSummarising(id) {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                } else {
                    Button { actions.refreshSummary(id) } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.borderless)
                        .focusable(false)
                        .help("Ververs de samenvatting")
                }
            }
            .frame(width: 16, height: Self.rowHeight)
        }
    }

    /// The summary, small behind it the date it was made, and in red that the last refresh failed.
    private func summaryText(_ data: ProjectInfo) -> Text {
        let small = Font.system(size: 10)
        var text = Text(data.summary?.text ?? "Nog geen samenvatting").font(.system(size: 13))
            .foregroundColor(data.summary == nil ? Self.gray : Self.ink)
        if let date = data.summary?.date {
            text = text + Text("  " + date.formatted(Self.dateStyle)).font(small).foregroundColor(Self.gray)
        }
        if data.summaryFailed {
            text = text + Text("  Verversen lukte niet").font(small).foregroundColor(Color(hex: "#CF222E"))
        }
        return text
    }

    /// The narrow column on the right: the git state, the workflow step and the links, each on its own line.
    private func facts(_ data: ProjectInfo, of id: Project.ID) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Group {
                if let git = data.git {
                    let details = Self.details(of: git)
                    HStack(spacing: 5) {
                        // Green for clean and pushed, orange when something is still open (R49).
                        Circle().fill(Color(hex: details.isEmpty ? "#1A7F37" : "#BC4C00")).frame(width: 7, height: 7)
                        if details.isEmpty {
                            Text("\(Self.branch(of: git)) · schoon").foregroundStyle(Self.gray)
                        } else {
                            Text(Self.branch(of: git)).bold() + Text(" · " + details.joined(separator: " · "))
                        }
                    }
                }
            }
            .frame(height: Self.rowHeight)
            Group {
                if let step = data.step {
                    Text(Self.label(of: step.kind))
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#0550AE"))
                        .padding(.horizontal, 7)
                        .background(Color(hex: "#DDF4FF"), in: Capsule())
                        .help(step.kind == .handoff ? "docs/handoff/\(step.document)" : step.document)
                }
            }
            .frame(height: Self.rowHeight)
            HStack(spacing: 10) {
                ForEach(LinkKind.allCases, id: \.self) { kind in
                    if let url = data.links[kind] { LinkButton(title: kind.rawValue, url: url) }
                }
            }
            .frame(height: Self.rowHeight)
        }
        .lineLimit(1)
        .frame(width: 270, alignment: .trailing)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Live-link…") { actions.editLink(.live, of: id) }
            Button("Localhost-link…") { actions.editLink(.localhost, of: id) }
            Button("Git-link…") { actions.editLink(.git, of: id) }
            Divider()
            Button("Links opnieuw zoeken") { actions.findLinksAgain(id) }
        }
    }

    private static let dateStyle = Date.FormatStyle(locale: Locale(identifier: "nl_NL")).day().month(.abbreviated).hour().minute()

    private static func branch(of git: GitState) -> String {
        git.branch == GitState.detachedBranch ? "losse HEAD" : git.branch
    }

    /// What is still open in a repository: `3 gewijzigd`, `2 niet gepusht`, `geen upstream`; empty when clean and pushed.
    private static func details(of git: GitState) -> [String] {
        var details = git.changedFiles > 0 ? ["\(git.changedFiles) gewijzigd"] : []
        switch git.unpushed {
        case nil: details.append("geen upstream")
        case let count? where count > 0: details.append("\(count) niet gepusht")
        default: break
        }
        return details
    }

    private static func label(of kind: WorkflowStep.Kind) -> String {
        switch kind {
        case .requirements: "requirements, nog geen plan"
        case .plan: "plan, nog niet gebouwd"
        case .build: "build bezig"
        case .bugfix: "bugfix bezig"
        case .handoff: "handoff open"
        }
    }
}

/// One link of the strip: blue, underlined while the pointer is on it; a click opens it in the browser.
private struct LinkButton: View {
    let title: String
    let url: URL
    @State private var isHovered = false

    var body: some View {
        Button { NSWorkspace.shared.open(url) } label: {
            Text(title).underline(isHovered).foregroundStyle(Color(hex: "#0969DA"))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { isHovered = $0 }
        .help(url.absoluteString)
    }
}
