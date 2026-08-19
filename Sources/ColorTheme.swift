import AppKit

// MARK: - Color Theme
struct NibColor {
    let name: String
    let hex: String
    /// Shown greyed in an empty collection. Nobody switches colours until
    /// something suggests what the other four are for.
    let suggestion: String
    let nsColor: NSColor

    static let yellow = NibColor(
        name: "Highlighter Yellow",
        hex: "#FFEB3B",
        suggestion: "Ideas",
        nsColor: NSColor(red: 1.0, green: 0.922, blue: 0.231, alpha: 1.0)
    )

    static let orange = NibColor(
        name: "Highlighter Orange",
        hex: "#f68717",
        suggestion: "Quotes",
        nsColor: NSColor(red: 0.965, green: 0.529, blue: 0.090, alpha: 1.0)
    )

    static let pink = NibColor(
        name: "Highlighter Pink",
        hex: "#f60474",
        suggestion: "Links",
        nsColor: NSColor(red: 0.965, green: 0.016, blue: 0.455, alpha: 1.0)
    )

    static let purple = NibColor(
        name: "Highlighter Purple",
        hex: "#8717f6",
        suggestion: "To-do",
        nsColor: NSColor(red: 0.529, green: 0.090, blue: 0.965, alpha: 1.0)
    )

    static let green = NibColor(
        name: "Highlighter Green",
        hex: "#39FF14",
        suggestion: "Later",
        nsColor: NSColor(red: 0.224, green: 1.0, blue: 0.078, alpha: 1.0)
    )

    static let all = [yellow, orange, pink, purple, green]
}
