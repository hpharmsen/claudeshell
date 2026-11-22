/// Scores how well typed letters match a name: all letters in order, case-insensitive.
public enum FuzzyMatcher {
    /// The score of a match, or nil without one; adjacent hits and hits at a word start score higher.
    public static func score(_ query: String, in candidate: String) -> Int? {
        let letters = Array(query.lowercased().filter { !$0.isWhitespace })
        let name = Array(candidate.lowercased())
        var score = 0, next = 0, previousHit = -2
        for (index, character) in name.enumerated() where next < letters.count && character == letters[next] {
            let atWordStart = index == 0 || !(name[index - 1].isLetter || name[index - 1].isNumber)
            score += 1 + (index == previousHit + 1 ? 2 : 0) + (atWordStart ? 3 : 0)
            previousHit = index
            next += 1
        }
        return next == letters.count ? score : nil
    }

    /// The matching items, best first; equal scores and an empty query keep the given order.
    public static func rank<Item>(_ query: String, in items: [Item], by name: (Item) -> String) -> [Item] {
        items.enumerated()
            .compactMap { offset, item in score(query, in: name(item)).map { (offset, $0, item) } }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
            .map(\.2)
    }
}
