import AppKit
import ClaudeshellCore
import SwiftUI

/// Whether Cmd is held down; the tiles show their shortcut meanwhile (R38).
@MainActor @Observable final class CommandKeyState {
    var isDown = false
}

/// The bar of project tiles, with the inactive dropdown and the + on the right.
struct TilesBarView: View {
    static let height: CGFloat = 67

    let store: ProjectStore
    let tracker: AttentionTracker
    let commandKey: CommandKeyState
    unowned let actions: MainWindowController

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(store.barProjects.enumerated()), id: \.element.id) { index, project in
                TileView(project: project, shortcut: commandKey.isDown ? Self.shortcut(forTile: index) : "",
                         isRunning: store.status(of: project.id) == .running, isSelected: store.selectedID == project.id,
                         attention: tracker.state(of: project.id))
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
                        openInFinderButton(for: project)
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
        openInFinderButton(for: project)
        Button("Hernoemen…") { actions.rename(project.id) }
        Menu("Kleur") {
            ForEach(Array(ColorPalette.colors.enumerated()), id: \.element) { index, hex in
                Button { store.setColor(hex, for: project.id) } label: {
                    Label { Text("Kleur \(index + 1)") } icon: { Image(nsImage: Self.swatch(hex)) }
                }
            }
        }
    }

    private func openInFinderButton(for project: Project) -> some View {
        Button("Open in Finder") { NSWorkspace.shared.open(URL(fileURLWithPath: project.path)) }
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

/// One tile: the icon area with the name below it; greyed when nothing runs, white with a dark line when selected.
private struct TileView: View {
    let project: Project
    let shortcut: String
    let isRunning: Bool
    let isSelected: Bool
    let attention: AttentionState

    static let ink = Color(hex: "#24292F")

    var body: some View {
        VStack(spacing: 2) {
            IconArea(project: project)
                .grayscale(isRunning ? 0 : 1)
                .opacity(isRunning ? 1 : 0.45)
                .overlay {
                    if !shortcut.isEmpty {
                        Text(shortcut)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Self.ink.opacity(0.6), in: IconArea.shape)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    // Half over the corner of the icon area.
                    Group {
                        if attention == .waiting { WaitingDot() }
                        if attention == .busy { BusySpinner() }
                    }
                    .offset(x: 7, y: -7)
                }
            Text(project.name)
                .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(Self.ink.opacity(isRunning ? 1 : 0.5))
                .padding(.horizontal, 2)
        }
        .frame(minWidth: 44, maxWidth: 64, maxHeight: .infinity)
        .background {
            if isSelected {
                Color.white
                    .overlay(alignment: .bottom) { Rectangle().fill(Self.ink).frame(height: 3) }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .help(project.name)
    }
}

/// The square of a tile: the initials on the project color.
private struct IconArea: View {
    static let shape = RoundedRectangle(cornerRadius: 7)

    let project: Project

    var body: some View {
        Text(project.initials)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(TileView.ink)
            .frame(width: 36, height: 36)
            .background(Color(hex: project.color), in: Self.shape)
    }
}

/// The signal the product is about: Claude waits for HP.
private struct WaitingDot: View {
    @State private var isDimmed = false

    var body: some View {
        Circle()
            .fill(Color(hex: "#CF222E"))
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
            .frame(width: 14, height: 14)
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
            .stroke(TileView.ink, lineWidth: 2)
            .frame(width: 9, height: 9)
            .rotationEffect(.degrees(isTurned ? 360 : 0))
            .frame(width: 14, height: 14)
            .background(.white, in: Circle())
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
