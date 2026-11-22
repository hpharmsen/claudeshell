import AppKit
import ClaudeshellCore
import SwiftUI

/// The bar of project tiles, with the inactive dropdown and the + on the right.
struct TilesBarView: View {
    static let height: CGFloat = 56

    let store: ProjectStore
    let tracker: AttentionTracker
    unowned let actions: MainWindowController

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(store.barProjects.enumerated()), id: \.element.id) { index, project in
                TileView(project: project, shortcut: Self.shortcut(forTile: index), isRunning: store.status(of: project.id) == .running,
                         isSelected: store.selectedID == project.id, attention: tracker.state(of: project.id))
                    .onTapGesture { actions.select(project.id) }
                    .contextMenu { contextMenu(for: project) }
                    .draggable(project.id.uuidString)
                    .dropDestination(for: String.self) { items, _ in
                        guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                        store.move(id, toBarIndex: index)
                        return true
                    }
            }
            Spacer(minLength: 0)
            Menu {
                ForEach(store.inactiveProjects) { project in
                    Menu(project.name) {
                        Button("Terugzetten") { store.setStatus(.active, for: project.id) }
                        Button("Verwijderen") { actions.remove(project.id) }
                    }
                }
            } label: {
                Image(systemName: "archivebox")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(store.inactiveProjects.isEmpty)
            .help("Inactieve projecten")
            Button(action: actions.addProject) { Image(systemName: "plus") }
                .buttonStyle(.borderless)
                .help("Project toevoegen")
        }
        .padding(.horizontal, 4)
        .frame(height: Self.height)
        .background(Color(hex: "#ECEEF1"))
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder private func contextMenu(for project: Project) -> some View {
        if store.status(of: project.id) == .running {
            Button("Stoppen") { actions.stop(project.id) }
        }
        Button("Naar inactief") { actions.deactivate(project.id) }
        if store.status(of: project.id) != .running {
            Button("Verwijderen") { actions.remove(project.id) }
        }
        Divider()
        Button("Hernoemen…") { actions.rename(project.id) }
        Menu("Kleur") {
            ForEach(Array(ColorPalette.colors.enumerated()), id: \.element) { index, hex in
                Button { store.setColor(hex, for: project.id) } label: {
                    Label { Text("Kleur \(index + 1)") } icon: { Image(nsImage: Self.swatch(hex)) }
                }
            }
        }
    }

    /// The key that selects a tile together with Cmd: 1...9, 0, then the same with Option (R16).
    private static func shortcut(forTile index: Int) -> String {
        index < 20 ? (index < 10 ? "" : "⌥") + String((index + 1) % 10) : ""
    }

    private static func swatch(_ hex: String) -> NSImage {
        NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            NSColor(Color(hex: hex)).setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
    }
}

/// One tile: muted when nothing runs, full color when running, a dark line when selected.
private struct TileView: View {
    let project: Project
    let shortcut: String
    let isRunning: Bool
    let isSelected: Bool
    let attention: AttentionState

    private static let ink = Color(hex: "#24292F")

    var body: some View {
        HStack(spacing: 4) {
            if attention == .waiting { WaitingDot() }
            if attention == .busy { BusySpinner() }
            VStack(spacing: 1) {
                Text(shortcut)
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.6)
                Text(project.name)
                    .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .truncationMode(.tail)
            }
            .foregroundStyle(Self.ink.opacity(isRunning ? 1 : 0.6))
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: 170, maxHeight: .infinity)
        .background(Color(hex: project.color).opacity(isRunning ? 1 : 0.45))
        .overlay(alignment: .bottom) {
            if isSelected { Rectangle().fill(Self.ink).frame(height: 3) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .help(project.name)
    }
}

/// The signal the product is about: Claude waits for HP.
private struct WaitingDot: View {
    @State private var isDimmed = false

    var body: some View {
        Circle()
            .fill(Color(hex: "#CF222E"))
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
            .frame(width: 11, height: 11)
            .scaleEffect(isDimmed ? 0.6 : 1)
            .fixedSize()
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { isDimmed = true }
            }
    }
}

private struct BusySpinner: View {
    @State private var isTurned = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(Color(hex: "#24292F"), lineWidth: 1.5)
            .frame(width: 9, height: 9)
            .rotationEffect(.degrees(isTurned ? 360 : 0))
            .fixedSize()
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { isTurned = true }
            }
    }
}

extension Color {
    /// A color from '#RRGGBB'; gray when the text is not a color.
    init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0x808080
        self.init(.sRGB, red: Double(value >> 16 & 0xFF) / 255, green: Double(value >> 8 & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}
