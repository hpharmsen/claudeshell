import AppKit
import MaestroCore
import CoreText
import SwiftTerm

/// Font and colors of the panes: the shell keeps the dark WezTerm defaults, Claude gets a light theme.
@MainActor enum TerminalTheme {
    nonisolated static let fontSize: CGFloat = 14
    static let font = NSFont(name: "JetBrainsMono-Regular", size: fontSize)
        ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    /// Background of the window around the panes.
    static let background = color(light.background)

    private struct Palette {
        let foreground: UInt32, background: UInt32, cursor: UInt32
        let ansi: [UInt32]
    }

    /// The WezTerm defaults, with the 16 ANSI colors from term/src/color.rs.
    private static let dark = Palette(foreground: 0xB2B2B2, background: 0x000000, cursor: 0x52AD70, ansi: [
        0x000000, 0xCC5555, 0x55CC55, 0xCDCD55, 0x5455CB, 0xCC55CC, 0x7ACACA, 0xCCCCCC,
        0x555555, 0xFF5555, 0x55FF55, 0xFFFF55, 0x5555FF, 0xFF55FF, 0x55FFFF, 0xFFFFFF,
    ])
    /// GitHub Light: ANSI colors dark enough to read on white.
    private static let light = Palette(foreground: 0x24292F, background: 0xFFFFFF, cursor: 0x0969DA, ansi: [
        0x24292F, 0xCF222E, 0x116329, 0x4D2D00, 0x0969DA, 0x8250DF, 0x1B7C83, 0x6E7781,
        0x57606A, 0xA40E26, 0x1A7F37, 0x633C01, 0x218BFF, 0xA475F9, 0x3192AA, 0x8C959F,
    ])
    private static let symbols = SymbolFallback()

    static func apply(to view: TerminalView, kind: PaneKind) {
        let palette = kind == .shell ? dark : light
        view.font = font
        view.nativeForegroundColor = color(palette.foreground)
        view.nativeBackgroundColor = color(palette.background)
        view.caretColor = color(palette.cursor)
        view.installColors(palette.ansi.map {
            Color(red8: UInt16($0 >> 16 & 0xFF), green8: UInt16($0 >> 8 & 0xFF), blue8: UInt16($0 & 0xFF))
        })
        view.glyphFallbackProvider = symbols
    }

    private static func color(_ rgb: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat(rgb >> 16 & 0xFF) / 255, green: CGFloat(rgb >> 8 & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

/// Draws private-use symbols (prompt icons) from the bundled Symbols Nerd Font.
private final class SymbolFallback: TerminalGlyphFallbackProvider, @unchecked Sendable {
    let generation: UInt64 = 1
    private let font = CTFontCreateWithName("SymbolsNFM" as CFString, TerminalTheme.fontSize, nil)

    func placementPolicy(for scalar: Unicode.Scalar) -> TerminalGlyphPlacementPolicy? {
        let isPrivateUse = (0xE000...0xF8FF).contains(scalar.value) || (0xF0000...0xFFFFD).contains(scalar.value)
        return isPrivateUse ? TerminalGlyphPlacementPolicy(placement: .icon) : nil
    }

    func fallbackFont(forPointSize size: CGFloat) -> CTFont? {
        size == TerminalTheme.fontSize ? font : CTFontCreateCopyWithAttributes(font, size, nil, nil)
    }
}
