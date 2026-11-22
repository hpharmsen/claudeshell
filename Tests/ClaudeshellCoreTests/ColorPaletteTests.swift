import Testing
@testable import ClaudeshellCore

@Test func paletteHasSixteenDistinctHexColors() {
    #expect(ColorPalette.colors.count == 16)
    #expect(Set(ColorPalette.colors).count == 16)
    #expect(ColorPalette.colors.allSatisfy { $0.wholeMatch(of: /#[0-9A-F]{6}/) != nil })
}

@Test func nextWithNothingUsedIsFirstColor() {
    #expect(ColorPalette.next(used: []) == ColorPalette.colors[0])
}

@Test func nextSkipsColorsInUse() {
    #expect(ColorPalette.next(used: [ColorPalette.colors[0], ColorPalette.colors[2]]) == ColorPalette.colors[1])
}

@Test func nextIgnoresCaseOfUsedColors() {
    #expect(ColorPalette.next(used: [ColorPalette.colors[0].lowercased()]) == ColorPalette.colors[1])
}

@Test func nextIgnoresColorsOutsideThePalette() {
    #expect(ColorPalette.next(used: ["#123456"]) == ColorPalette.colors[0])
}

@Test func nextWithAllUsedIsLeastUsedColor() {
    let used = ColorPalette.colors + ColorPalette.colors.filter { $0 != ColorPalette.colors[5] }
    #expect(ColorPalette.next(used: used) == ColorPalette.colors[5])
}

@Test func nextWithAllUsedEquallyIsFirstColor() {
    #expect(ColorPalette.next(used: ColorPalette.colors) == ColorPalette.colors[0])
}
