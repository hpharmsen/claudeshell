/// Fixed pastel tile colors: backgrounds for dark text on a light window.
public enum ColorPalette {
    public static let colors = [
        "#A8C7FA", "#F4A9A8", "#A8DAB5", "#FBC49B", "#C9B6F2", "#9ADBE0", "#F5B5D2", "#E6D38A",
        "#B3BDF5", "#9FDCC9", "#E2B4EC", "#C6DE9A", "#F2CF9A", "#9FCDF2", "#F0A6B8", "#C5CCD6",
    ]

    /// The first color not in use, otherwise the least used one.
    public static func next(used: [String]) -> String {
        let counts = Dictionary(used.map { ($0.uppercased(), 1) }, uniquingKeysWith: +)
        // min(by:) returns the first of equal elements, so unused colors win in palette order.
        return colors.min { counts[$0, default: 0] < counts[$1, default: 0] } ?? "#C5CCD6"
    }
}
