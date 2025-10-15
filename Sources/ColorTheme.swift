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
}

// MARK: - Gradient Colors
struct NibGradients {
    static let yellow = LinearGradient(
        colors: [Color(red: 1.0, green: 0.922, blue: 0.231), Color(red: 0.95, green: 0.872, blue: 0.181)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let orange = LinearGradient(
        colors: [Color(red: 0.965, green: 0.529, blue: 0.090), Color(red: 0.915, green: 0.479, blue: 0.040)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pink = LinearGradient(
        colors: [Color(red: 0.965, green: 0.016, blue: 0.455), Color(red: 0.915, green: 0.0, blue: 0.405)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let purple = LinearGradient(
        colors: [Color(red: 0.529, green: 0.090, blue: 0.965), Color(red: 0.479, green: 0.040, blue: 0.915)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let green = LinearGradient(
        colors: [Color(red: 0.224, green: 1.0, blue: 0.078), Color(red: 0.174, green: 0.95, blue: 0.028)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
