import Testing
@testable import MaestroCore

@Test func plainPathIsPastedAsIsWithASpaceBehind() {
    #expect(DroppedFiles.pasteText(["/Users/hp/Desktop/shot.png"]) == "/Users/hp/Desktop/shot.png ")
}

@Test func spacesAndShellCharactersGetABackslash() {
    #expect(DroppedFiles.pasteText(["/Users/hp/Desktop/Schermafbeelding 2026 (1)'s.png"])
            == "/Users/hp/Desktop/Schermafbeelding\\ 2026\\ \\(1\\)\\'s.png ")
}

@Test func accentedLettersStayAsTheyAre() {
    #expect(DroppedFiles.pasteText(["/tmp/café.png"]) == "/tmp/café.png ")
}

@Test func severalFilesAreSeparatedBySpaces() {
    #expect(DroppedFiles.pasteText(["/a.png", "/b c.png"]) == "/a.png /b\\ c.png ")
}

@Test func noFilesGiveNoText() {
    #expect(DroppedFiles.pasteText([]) == "")
}
