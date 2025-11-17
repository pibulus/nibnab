import SwiftUI
import AppKit

// MARK: - Color Theme
struct NibColor {
    let name: String
    let hex: String
    let nsColor: NSColor

    static let yellow = NibColor(
        name: "Highlighter Yellow",
        hex: "#FFEB3B",
        nsColor: NSColor(red: 1.0, green: 0.922, blue: 0.231, alpha: 1.0)
    )

    static let orange = NibColor(
        name: "Highlighter Orange",
        hex: "#f68717",
        nsColor: NSColor(red: 0.965, green: 0.529, blue: 0.090, alpha: 1.0)
    )

    static let pink = NibColor(
        name: "Highlighter Pink",
        hex: "#f60474",
        nsColor: NSColor(red: 0.965, green: 0.016, blue: 0.455, alpha: 1.0)
    )

    static let purple = NibColor(
        name: "Highlighter Purple",
        hex: "#8717f6",
        nsColor: NSColor(red: 0.529, green: 0.090, blue: 0.965, alpha: 1.0)
    )

    static let green = NibColor(
        name: "Highlighter Green",
        hex: "#39FF14",
        nsColor: NSColor(red: 0.224, green: 1.0, blue: 0.078, alpha: 1.0)
    )

    static let all = [yellow, orange, pink, purple, green]

    var shortName: String {
        name.replacingOccurrences(of: "Highlighter ", with: "")
    }

    var shortNameLowercased: String {
        shortName.lowercased()
    }
}
