import AppKit
import ClaudeshellCore
import SwiftUI

/// A hosting view that never takes the focus, so a click in it leaves the typing in the terminal pane (KTD5).
final class PassiveHostingView<Content: View>: NSHostingView<Content> {
    override var acceptsFirstResponder: Bool { false }
}

/// The strip below the tiles bar: links, git state and workflow step of the selected project, and its summary.
struct ProjectStripView: View {
    /// Always the same, with or without data, so arriving data never moves the terminals (KTD1).
    static let height: CGFloat = 62
    private static let ink = Color(hex: "#24292F")
    private static let gray = Color(hex: "#6E7781")
    private static let rowHeight: CGFloat = 16

    let store: ProjectStore
    let info: ProjectInfoStore
    unowned let actions: MainWindowController

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let id = store.selectedID {
                let data = info.info(id)
                facts(data, of: id)
                summary(data, of: id)
                Button { actions.toggleStrip(nil) } label: { Image(systemName: "xmark") }
                    .buttonStyle(.borderless)
                    .focusable(false)
                    .help("Sluit de projectstrook (Cmd+I)")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Self.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: Self.height)
        .background(Color(hex: "#F6F8FA"))
        .overlay(alignment: .bottom) { Rectangle().fill(Color(hex: "#D0D7DE")).frame(height: 1) }
        .environment(\.colorScheme, .light)
    }

    /// The left column: the links, the git state and the workflow step, each on its own line.
    private func facts(_ data: ProjectInfo, of id: Project.ID) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ForEach(LinkKind.allCases, id: \.self) { kind in
                    if let url = data.links[kind] {
                        Button(kind.rawValue) { NSWorkspace.shared.open(url) }
                            .buttonStyle(.link)
                            .focusable(false)
                            .help(url.absoluteString)
                    }
                }
            }
            .frame(height: Self.rowHeight)
            Group {
                if let git = data.git {
                    let isClean = git.changedFiles == 0 && git.unpushed == 0
                    Text(Self.text(of: git))
                        .fontWeight(isClean ? .regular : .bold)
                        .foregroundStyle(isClean ? Self.gray : Self.ink)
                }
            }
            .frame(height: Self.rowHeight)
            Group {
                if let step = data.step {
                    Text(Self.label(of: step.kind))
                        .help(step.kind == .handoff ? "docs/handoff/\(step.document)" : step.document)
                }
            }
            .frame(height: Self.rowHeight)
        }
        .lineLimit(1)
        .frame(width: 300, alignment: .leading)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Live-link…") { actions.editLink(.live, of: id) }
            Button("Localhost-link…") { actions.editLink(.localhost, of: id) }
            Button("Git-link…") { actions.editLink(.git, of: id) }
            Divider()
            Button("Links opnieuw zoeken") { actions.findLinksAgain(id) }
        }
    }

    /// The right column: the summary on at most three lines, with its date and the refresh button.
    private func summary(_ data: ProjectInfo, of id: Project.ID) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(data.summary?.text ?? "Nog geen samenvatting")
                .foregroundStyle(data.summary == nil ? Self.gray : Self.ink)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .contextMenu {
                    Button("Kopieer samenvatting") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(data.summary?.text ?? "", forType: .string)
                    }
                    .disabled(data.summary == nil)
                }
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    if let date = data.summary?.date {
                        Text(date.formatted(Self.dateStyle)).foregroundStyle(Self.gray)
                    }
                    if info.isSummarising(id) {
                        ProgressView().controlSize(.small).scaleEffect(0.7).frame(width: 16, height: 16)
                    } else {
                        Button { actions.refreshSummary(id) } label: { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(.borderless)
                            .focusable(false)
                            .help("Ververs de samenvatting")
                    }
                }
                if data.summaryFailed {
                    Text("Verversen lukte niet").foregroundStyle(Color(hex: "#CF222E"))
                }
            }
            .font(.system(size: 10))
            .fixedSize()
        }
    }

    private static let dateStyle = Date.FormatStyle(locale: Locale(identifier: "nl_NL")).day().month(.abbreviated).hour().minute()

    /// The git state as one line: `main · schoon`, or `main · 3 gewijzigd · 2 niet gepusht`.
    private static func text(of git: GitState) -> String {
        var parts = [git.branch == GitState.detachedBranch ? "losse HEAD" : git.branch]
        if git.changedFiles > 0 { parts.append("\(git.changedFiles) gewijzigd") }
        switch git.unpushed {
        case nil: parts.append("geen upstream")
        case let count? where count > 0: parts.append("\(count) niet gepusht")
        default: break
        }
        return (parts.count == 1 ? parts + ["schoon"] : parts).joined(separator: " · ")
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
