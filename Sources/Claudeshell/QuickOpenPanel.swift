import AppKit
import ClaudeshellCore
import SwiftUI

/// The Cmd+P finder over all projects, shown as a sheet on the window.
@MainActor enum QuickOpenPanel {
    static func present(on window: NSWindow, projects: [Project], choose: @escaping (Project.ID) -> Void) {
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        panel.contentViewController = NSHostingController(rootView: QuickOpenView(projects: projects) { id in
            window.endSheet(panel)
            if let id { choose(id) }
        })
        window.beginSheet(panel)
    }
}

private struct QuickOpenView: View {
    /// All projects: the bar in bar order, then the inactive ones.
    let projects: [Project]
    let choose: (Project.ID?) -> Void

    @State private var query = ""
    @State private var index = 0
    @FocusState private var isFocused: Bool

    private var matches: [Project] { FuzzyMatcher.rank(query, in: projects, by: \.name) }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Zoek project", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(10)
                .focused($isFocused)
                .onSubmit { choose(matches.indices.contains(index) ? matches[index].id : nil) }
                .onKeyPress(.downArrow) { move(1) }
                .onKeyPress(.upArrow) { move(-1) }
                .onChange(of: query) { index = 0 }
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(matches.enumerated()), id: \.element.id) { offset, project in
                            HStack {
                                Text(project.name)
                                Spacer()
                                Text(project.path).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(offset == index ? Color.accentColor.opacity(0.4) : .clear)
                            .contentShape(Rectangle())
                            .onTapGesture { choose(project.id) }
                            .id(project.id)
                        }
                    }
                }
                .onChange(of: index) {
                    if matches.indices.contains(index) { proxy.scrollTo(matches[index].id) }
                }
            }
            .frame(height: 320)
        }
        .frame(width: 560)
        .onExitCommand { choose(nil) }
        .onAppear { isFocused = true }
    }

    private func move(_ step: Int) -> KeyPress.Result {
        index = min(max(index + step, 0), max(matches.count - 1, 0))
        return .handled
    }
}
