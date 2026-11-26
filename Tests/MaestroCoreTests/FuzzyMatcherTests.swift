import Testing
@testable import MaestroCore

private let names = ["Elevate Tony", "Elevate Translate", "Golfmaster", "Justai"]

private func rank(_ query: String, _ items: [String] = names) -> [String] {
    FuzzyMatcher.rank(query, in: items) { $0 }
}

@Test func lettersInOrderMatch() {
    #expect(rank("gm") == ["Golfmaster"])
}

@Test func missingLettersDoNotMatch() {
    #expect(FuzzyMatcher.score("xyz", in: "Golfmaster") == nil)
}

@Test func lettersOutOfOrderDoNotMatch() {
    #expect(FuzzyMatcher.score("mg", in: "Golfmaster") == nil)
}

@Test func wordStartsRankHigher() {
    #expect(rank("ele tra").first == "Elevate Translate")
}

@Test func wordStartBeatsMatchInsideAWord() {
    #expect(rank("t", ["Justai", "Tony"]) == ["Tony", "Justai"])
}

@Test func contiguousMatchBeatsScatteredMatch() {
    #expect(rank("ust", ["Hugoslot", "Justai"]) == ["Justai", "Hugoslot"])
}

@Test func emptyQueryKeepsAllItemsInOrder() {
    #expect(rank("") == names)
    #expect(rank("   ") == names)
}

@Test func caseMakesNoDifference() {
    #expect(rank("GM") == rank("gm"))
    #expect(FuzzyMatcher.score("JUSTAI", in: "justai") == FuzzyMatcher.score("justai", in: "Justai"))
}

@Test func queryLongerThanNameDoesNotMatch() {
    #expect(FuzzyMatcher.score("justaiextra", in: "Justai") == nil)
}

@Test func equalScoresKeepTheGivenOrder() {
    #expect(rank("e", ["Eerste", "Elevate"]) == ["Eerste", "Elevate"])
}

@Test func emptyCandidateListGivesNothing() {
    #expect(rank("a", []).isEmpty)
}
