#!/usr/bin/env swift

import AppKit
import CoreGraphics
import CoreText

// MARK: - NibNab App Store Story Card Generator
// Generates 5 high-converting marketing cards at 2880x1800 and 1440x900

struct CardSpec {
    let filename: String
    let badge: String
    let headline: String
    let subheadline: String
    let type: CardType
}

enum CardType {
    case heroPopout
    case fiveColors
    case keyboardTags
    case markdownExport
    case noSubscriptions
}

let cards: [CardSpec] = [
    CardSpec(
        filename: "01-color-coded-clipboard",
        badge: "✨ COLOR-CODED CLIPBOARD",
        headline: "Your clipboard deserves better than Notes.app",
        subheadline: "NibNab catches everything you copy and sorts it into five tactile highlighter collections.",
        type: .heroPopout
    ),
    CardSpec(
        filename: "02-five-highlighter-colors",
        badge: "🎨 5 HIGHLIGHTER COLLECTIONS",
        headline: "Organize quotes, links & code by vibe.",
        subheadline: "Yellow for inspiration, Orange for research, Pink for quotes, Purple for tasks, Green for snippets.",
        type: .fiveColors
    ),
    CardSpec(
        filename: "03-keyboard-driven-tags",
        badge: "⚡ KEYBOARD DRIVEN & #TAGS",
        headline: "Instant search across all five collections.",
        subheadline: "Press Ctrl+Cmd+N anywhere. Type #tags or keywords to find clips instantly without remembering the color.",
        type: .keyboardTags
    ),
    CardSpec(
        filename: "04-markdown-export",
        badge: "📝 MARKDOWN-NATIVE EXPORT",
        headline: "Export clean notes with source apps & timestamps.",
        subheadline: "Export as rich Markdown or clean plain text. Ready to paste directly into Obsidian, Notion, or Slack.",
        type: .markdownExport
    ),
    CardSpec(
        filename: "05-no-subscriptions",
        badge: "🔒 100% PRIVATE • ZERO SUBSCRIPTIONS",
        headline: "Pay once. Yours forever.",
        subheadline: "$14.99 one-time. Stored in local Markdown files on your Mac. No accounts, no cloud, no tracking.",
        type: .noSubscriptions
    )
]

func drawCard(spec: CardSpec, width: CGFloat, height: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: width, height: height))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return image }

    let scale = width / 2880.0

    // 1. Background gradient (Warm charcoal with pink/orange dusk glow)
    let bgColors = [
        NSColor(red: 0.08, green: 0.06, blue: 0.07, alpha: 1.0).cgColor,
        NSColor(red: 0.12, green: 0.08, blue: 0.10, alpha: 1.0).cgColor,
        NSColor(red: 0.06, green: 0.05, blue: 0.06, alpha: 1.0).cgColor
    ]
    let bgGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                            colors: bgColors as CFArray,
                            locations: [0.0, 0.5, 1.0])!
    ctx.drawLinearGradient(bgGrad,
                           start: CGPoint(x: width * 0.5, y: height),
                           end: CGPoint(x: width * 0.5, y: 0),
                           options: [])

    // 2. Ambient top glow orb (Warm highlighter pink & yellow glow)
    let glowColors = [
        NSColor(red: 1.0, green: 0.42, blue: 0.62, alpha: 0.20).cgColor,
        NSColor(red: 1.0, green: 0.88, blue: 0.26, alpha: 0.08).cgColor,
        NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0).cgColor
    ]
    let glowGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: glowColors as CFArray,
                              locations: [0.0, 0.4, 1.0])!
    ctx.drawRadialGradient(glowGrad,
                           startCenter: CGPoint(x: width * 0.5, y: height * 0.85),
                           startRadius: 0,
                           endCenter: CGPoint(x: width * 0.5, y: height * 0.85),
                           endRadius: width * 0.55,
                           options: [])

    // 3. Header Text Section
    let topY = height - (140 * scale)

    // Badge
    let badgeFont = NSFont.systemFont(ofSize: 22 * scale, weight: .bold)
    let badgeAttrs: [NSAttributedString.Key: Any] = [
        .font: badgeFont,
        .foregroundColor: NSColor(red: 1.0, green: 0.88, blue: 0.26, alpha: 0.95),
        .kern: 2.0 * scale
    ]
    let badgeString = NSAttributedString(string: spec.badge, attributes: badgeAttrs)
    let badgeSize = badgeString.size()
    let badgeRect = CGRect(x: (width - badgeSize.width) / 2, y: topY - badgeSize.height, width: badgeSize.width, height: badgeSize.height)
    badgeString.draw(in: badgeRect)

    // Headline
    let headlineFont = NSFont.systemFont(ofSize: 64 * scale, weight: .black)
    let headlineStyle = NSMutableParagraphStyle()
    headlineStyle.alignment = .center
    let headlineAttrs: [NSAttributedString.Key: Any] = [
        .font: headlineFont,
        .foregroundColor: NSColor(red: 0.99, green: 0.97, blue: 0.94, alpha: 1.0),
        .paragraphStyle: headlineStyle
    ]
    let headlineString = NSAttributedString(string: spec.headline, attributes: headlineAttrs)
    let headlineRect = CGRect(x: width * 0.08, y: badgeRect.minY - (90 * scale), width: width * 0.84, height: 80 * scale)
    headlineString.draw(in: headlineRect)

    // Subheadline
    let subFont = NSFont.systemFont(ofSize: 28 * scale, weight: .medium)
    let subStyle = NSMutableParagraphStyle()
    subStyle.alignment = .center
    let subAttrs: [NSAttributedString.Key: Any] = [
        .font: subFont,
        .foregroundColor: NSColor(red: 0.90, green: 0.85, blue: 0.88, alpha: 0.80),
        .paragraphStyle: subStyle
    ]
    let subString = NSAttributedString(string: spec.subheadline, attributes: subAttrs)
    let subRect = CGRect(x: width * 0.12, y: headlineRect.minY - (54 * scale), width: width * 0.76, height: 50 * scale)
    subString.draw(in: subRect)

    // 4. Main Body Content Area
    let contentY: CGFloat = 80 * scale
    let contentHeight = subRect.minY - contentY - (40 * scale)
    let contentRect = CGRect(x: width * 0.10, y: contentY, width: width * 0.80, height: contentHeight)

    switch spec.type {
    case .heroPopout:
        drawHeroPopout(in: contentRect, scale: scale, ctx: ctx)
    case .fiveColors:
        drawFiveColors(in: contentRect, scale: scale, ctx: ctx)
    case .keyboardTags:
        drawKeyboardTags(in: contentRect, scale: scale, ctx: ctx)
    case .markdownExport:
        drawMarkdownExport(in: contentRect, scale: scale, ctx: ctx)
    case .noSubscriptions:
        drawNoSubscriptions(in: contentRect, scale: scale, ctx: ctx)
    }

    image.unlockFocus()
    return image
}

func drawHeroPopout(in rect: CGRect, scale: CGFloat, ctx: CGContext) {
    let mockWidth: CGFloat = rect.width * 0.75
    let mockHeight: CGFloat = rect.height * 0.95
    let mockRect = CGRect(x: rect.midX - (mockWidth / 2), y: rect.midY - (mockHeight / 2), width: mockWidth, height: mockHeight)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24 * scale), blur: 50 * scale, color: NSColor.black.withAlphaComponent(0.65).cgColor)
    let path = CGPath(roundedRect: mockRect, cornerWidth: 24 * scale, cornerHeight: 24 * scale, transform: nil)
    ctx.addPath(path)
    ctx.setFillColor(NSColor(red: 0.11, green: 0.09, blue: 0.10, alpha: 0.95).cgColor)
    ctx.fillPath()

    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    ctx.setLineWidth(2.5 * scale)
    ctx.setStrokeColor(NSColor(red: 1.0, green: 0.42, blue: 0.62, alpha: 0.45).cgColor)
    ctx.addPath(path)
    ctx.strokePath()
    ctx.restoreGState()

    // 5 Highlighter Color Tabs Header
    let colors = [
        ("🟡", "YELLOW", NSColor(red: 1.0, green: 0.88, blue: 0.26, alpha: 1.0), true),
        ("🟠", "ORANGE", NSColor(red: 1.0, green: 0.62, blue: 0.26, alpha: 0.6), false),
        ("🩷", "PINK", NSColor(red: 1.0, green: 0.42, blue: 0.62, alpha: 0.6), false),
        ("🟣", "PURPLE", NSColor(red: 0.64, green: 0.35, blue: 1.0, alpha: 0.6), false),
        ("🟢", "GREEN", NSColor(red: 0.18, green: 0.84, blue: 0.45, alpha: 0.6), false)
    ]

    let tabWidth = (mockWidth - (32 * scale * 2)) / 5
    let tabY = mockRect.maxY - (70 * scale)

    for (i, tab) in colors.enumerated() {
        let tabX = mockRect.minX + (32 * scale) + CGFloat(i) * tabWidth
        let tabRect = CGRect(x: tabX + 4 * scale, y: tabY, width: tabWidth - 8 * scale, height: 44 * scale)

        ctx.saveGState()
        let tabPath = CGPath(roundedRect: tabRect, cornerWidth: 12 * scale, cornerHeight: 12 * scale, transform: nil)
        ctx.addPath(tabPath)
        ctx.setFillColor(tab.3 ? tab.2.withAlphaComponent(0.25).cgColor : NSColor.white.withAlphaComponent(0.06).cgColor)
        ctx.fillPath()
        if tab.3 {
            ctx.setLineWidth(2 * scale)
            ctx.setStrokeColor(tab.2.cgColor)
            ctx.addPath(tabPath)
            ctx.strokePath()
        }
        ctx.restoreGState()

        let tFont = NSFont.systemFont(ofSize: 15 * scale, weight: .bold)
        let tAttrs: [NSAttributedString.Key: Any] = [
            .font: tFont,
            .foregroundColor: tab.3 ? tab.2 : NSColor.white.withAlphaComponent(0.5)
        ]
        let tStr = NSAttributedString(string: "\(tab.0) \(tab.1)", attributes: tAttrs)
        let tSize = tStr.size()
        tStr.draw(at: CGPoint(x: tabRect.midX - (tSize.width / 2), y: tabRect.midY - (tSize.height / 2)))
    }

    // Mock Sample Clips
    let clips = [
        ("Safari", "2m ago", "https://spellbreak.app — Break the screen spell with breathing aurora waves #inspiration #design"),
        ("VS Code", "14m ago", "const activeHighlighter = colors[activeColorIndex] || 'yellow'; // auto-captured"),
        ("Twitter", "1h ago", "\"Can't scale is the feature. Cartridge philosophy: complete tools, owned forever.\" #quotes")
    ]

    let clipListY = tabY - (20 * scale)
    let clipHeight = (clipListY - mockRect.minY - (40 * scale)) / 3

    for (i, clip) in clips.enumerated() {
        let cY = clipListY - CGFloat(i + 1) * clipHeight
        let cRect = CGRect(x: mockRect.minX + (32 * scale), y: cY + (8 * scale), width: mockWidth - (64 * scale), height: clipHeight - (16 * scale))

        ctx.saveGState()
        let cPath = CGPath(roundedRect: cRect, cornerWidth: 16 * scale, cornerHeight: 16 * scale, transform: nil)
        ctx.addPath(cPath)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.04).cgColor)
        ctx.fillPath()
        ctx.setLineWidth(1.5 * scale)
        ctx.setStrokeColor(i == 0 ? NSColor(red: 1.0, green: 0.88, blue: 0.26, alpha: 0.5).cgColor : NSColor.white.withAlphaComponent(0.12).cgColor)
        ctx.addPath(cPath)
        ctx.strokePath()
        ctx.restoreGState()

        // Source App + Time
        let metaFont = NSFont.systemFont(ofSize: 14 * scale, weight: .bold)
        let metaAttrs: [NSAttributedString.Key: Any] = [
            .font: metaFont,
            .foregroundColor: NSColor(red: 1.0, green: 0.88, blue: 0.26, alpha: 0.90)
        ]
        let metaStr = NSAttributedString(string: "\(clip.0)  •  \(clip.1)", attributes: metaAttrs)
        metaStr.draw(at: CGPoint(x: cRect.minX + 20 * scale, y: cRect.maxY - 32 * scale))

        // Clip Text
        let bodyFont = NSFont.systemFont(ofSize: 17 * scale, weight: .medium)
        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.lineSpacing = 4 * scale
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor(red: 0.95, green: 0.92, blue: 0.96, alpha: 0.90),
            .paragraphStyle: bodyStyle
        ]
        let bodyStr = NSAttributedString(string: clip.2, attributes: bodyAttrs)
        bodyStr.draw(in: CGRect(x: cRect.minX + 20 * scale, y: cRect.minY + 12 * scale, width: cRect.width - 40 * scale, height: cRect.height - 48 * scale))
    }
}

func drawFiveColors(in rect: CGRect, scale: CGFloat, ctx: CGContext) {
    let palettes = [
        ("🟡 YELLOW", "INSPIRATION", "Links, moodboards, references, and fresh ideas", NSColor(red: 1.0, green: 0.88, blue: 0.26, alpha: 1.0)),
        ("🟠 ORANGE", "RESEARCH", "Articles, citations, docs, and reading list snippets", NSColor(red: 1.0, green: 0.62, blue: 0.26, alpha: 1.0)),
        ("🩷 PINK", "QUOTES", "Memorable lines, customer words, and book highlights", NSColor(red: 1.0, green: 0.42, blue: 0.62, alpha: 1.0)),
        ("🟣 PURPLE", "TASKS & IDEAS", "Todos, quick reminders, and project notes to handle", NSColor(red: 0.64, green: 0.35, blue: 1.0, alpha: 1.0)),
        ("🟢 GREEN", "CODE & DATA", "Commands, terminal snippets, API keys & configs", NSColor(red: 0.18, green: 0.84, blue: 0.45, alpha: 1.0))
    ]

    let cardWidth = (rect.width - (20 * scale * 4)) / 5
    let cardHeight = rect.height * 0.90
    let cardY = rect.midY - (cardHeight / 2)

    for (i, p) in palettes.enumerated() {
        let cardX = rect.minX + CGFloat(i) * (cardWidth + (20 * scale))
        let cardRect = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -16 * scale), blur: 32 * scale, color: NSColor.black.withAlphaComponent(0.5).cgColor)
        let path = CGPath(roundedRect: cardRect, cornerWidth: 20 * scale, cornerHeight: 20 * scale, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(NSColor(red: 0.11, green: 0.08, blue: 0.10, alpha: 0.92).cgColor)
        ctx.fillPath()

        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.setLineWidth(2 * scale)
        ctx.setStrokeColor(p.3.withAlphaComponent(0.5).cgColor)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()

        let pad = 24 * scale

        // Title
        let tFont = NSFont.systemFont(ofSize: 20 * scale, weight: .black)
        let tAttrs: [NSAttributedString.Key: Any] = [
            .font: tFont,
            .foregroundColor: p.3,
            .kern: 1.2 * scale
        ]
        let tStr = NSAttributedString(string: p.0, attributes: tAttrs)
        tStr.draw(at: CGPoint(x: cardX + pad, y: cardY + cardHeight - pad - 24 * scale))

        // Role
        let rFont = NSFont.systemFont(ofSize: 14 * scale, weight: .bold)
        let rAttrs: [NSAttributedString.Key: Any] = [
            .font: rFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.55),
            .kern: 1.0 * scale
        ]
        let rStr = NSAttributedString(string: p.1, attributes: rAttrs)
        rStr.draw(at: CGPoint(x: cardX + pad, y: cardY + cardHeight - pad - 50 * scale))

        // Description
        let dFont = NSFont.systemFont(ofSize: 17 * scale, weight: .medium)
        let dStyle = NSMutableParagraphStyle()
        dStyle.lineSpacing = 5 * scale
        let dAttrs: [NSAttributedString.Key: Any] = [
            .font: dFont,
            .foregroundColor: NSColor(red: 0.92, green: 0.88, blue: 0.94, alpha: 0.85),
            .paragraphStyle: dStyle
        ]
        let dStr = NSAttributedString(string: p.2, attributes: dAttrs)
        dStr.draw(in: CGRect(x: cardX + pad, y: cardY + pad, width: cardWidth - (pad * 2), height: cardHeight * 0.6))
    }
}

func drawKeyboardTags(in rect: CGRect, scale: CGFloat, ctx: CGContext) {
    let mockWidth: CGFloat = rect.width * 0.80
    let mockHeight: CGFloat = rect.height * 0.90
    let mockRect = CGRect(x: rect.midX - (mockWidth / 2), y: rect.midY - (mockHeight / 2), width: mockWidth, height: mockHeight)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -20 * scale), blur: 40 * scale, color: NSColor.black.withAlphaComponent(0.6).cgColor)
    let path = CGPath(roundedRect: mockRect, cornerWidth: 24 * scale, cornerHeight: 24 * scale, transform: nil)
    ctx.addPath(path)
    ctx.setFillColor(NSColor(red: 0.10, green: 0.08, blue: 0.10, alpha: 0.95).cgColor)
    ctx.fillPath()
    ctx.setLineWidth(2 * scale)
    ctx.setStrokeColor(NSColor(red: 0.64, green: 0.35, blue: 1.0, alpha: 0.45).cgColor)
    ctx.addPath(path)
    ctx.strokePath()
    ctx.restoreGState()

    // Search Bar with #tag
    let searchRect = CGRect(x: mockRect.minX + 32 * scale, y: mockRect.maxY - 80 * scale, width: mockWidth - 64 * scale, height: 48 * scale)
    ctx.saveGState()
    let sPath = CGPath(roundedRect: searchRect, cornerWidth: 12 * scale, cornerHeight: 12 * scale, transform: nil)
    ctx.addPath(sPath)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.06).cgColor)
    ctx.fillPath()
    ctx.setLineWidth(1.5 * scale)
    ctx.setStrokeColor(NSColor(red: 0.64, green: 0.35, blue: 1.0, alpha: 0.8).cgColor)
    ctx.addPath(sPath)
    ctx.strokePath()
    ctx.restoreGState()

    let sFont = NSFont.systemFont(ofSize: 18 * scale, weight: .bold)
    let sAttrs: [NSAttributedString.Key: Any] = [
        .font: sFont,
        .foregroundColor: NSColor(red: 0.64, green: 0.35, blue: 1.0, alpha: 1.0)
    ]
    let sStr = NSAttributedString(string: "🔍  #inspiration", attributes: sAttrs)
    sStr.draw(at: CGPoint(x: searchRect.minX + 16 * scale, y: searchRect.midY - (sStr.size().height / 2)))

    // Filtered Results
    let results = [
        ("🟡 Yellow", "https://spellbreak.app — Mystical break software for screen creatives #inspiration"),
        ("🟡 Yellow", "Linear 2026 motion curves: cubic-bezier(0.16, 1, 0.3, 1) #inspiration #ui"),
        ("🩷 Pink", "\"Simplicity is about subtracting the obvious and adding the meaningful.\" #inspiration")
    ]

    for (i, r) in results.enumerated() {
        let rY = searchRect.minY - CGFloat(i + 1) * (110 * scale)
        let rRect = CGRect(x: mockRect.minX + 32 * scale, y: rY, width: mockWidth - 64 * scale, height: 95 * scale)

        ctx.saveGState()
        let rPath = CGPath(roundedRect: rRect, cornerWidth: 14 * scale, cornerHeight: 14 * scale, transform: nil)
        ctx.addPath(rPath)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.04).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        let catFont = NSFont.systemFont(ofSize: 14 * scale, weight: .bold)
        let catAttrs: [NSAttributedString.Key: Any] = [
            .font: catFont,
            .foregroundColor: NSColor(red: 1.0, green: 0.88, blue: 0.26, alpha: 0.9)
        ]
        let catStr = NSAttributedString(string: r.0, attributes: catAttrs)
        catStr.draw(at: CGPoint(x: rRect.minX + 20 * scale, y: rRect.maxY - 28 * scale))

        let bFont = NSFont.systemFont(ofSize: 16 * scale, weight: .medium)
        let bAttrs: [NSAttributedString.Key: Any] = [
            .font: bFont,
            .foregroundColor: NSColor(red: 0.95, green: 0.92, blue: 0.96, alpha: 0.90)
        ]
        let bStr = NSAttributedString(string: r.1, attributes: bAttrs)
        bStr.draw(in: CGRect(x: rRect.minX + 20 * scale, y: rRect.minY + 12 * scale, width: rRect.width - 40 * scale, height: 48 * scale))
    }
}

func drawMarkdownExport(in rect: CGRect, scale: CGFloat, ctx: CGContext) {
    let pillars = [
        ("📄 MARKDOWN WITH METADATA", "Includes source app names, capture timestamps, and tags. Perfect for syncing directly into Obsidian, Notion, or GitHub docs."),
        ("📝 CLEAN PLAIN TEXT", "Just the raw clips separated by clean lines. Zero metadata, zero formatting noise. Ready to paste anywhere."),
        ("📁 LOCAL MARKDOWN FILES", "All clips live as human-readable .md files in your Mac's Application Support folder. You own your data forever."),
        ("⚡ 1-CLICK EXPORT", "Export any color collection or your entire library with a single right-click in your menu bar.")
    ]

    let boxWidth = (rect.width - (30 * scale)) / 2
    let boxHeight = (rect.height - (30 * scale)) / 2

    for (i, p) in pillars.enumerated() {
        let col = CGFloat(i % 2)
        let row = CGFloat(1 - (i / 2))

        let boxX = rect.minX + col * (boxWidth + (30 * scale))
        let boxY = rect.minY + row * (boxHeight + (30 * scale))
        let boxRect = CGRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 30 * scale, color: NSColor.black.withAlphaComponent(0.5).cgColor)
        let path = CGPath(roundedRect: boxRect, cornerWidth: 20 * scale, cornerHeight: 20 * scale, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(NSColor(red: 0.11, green: 0.08, blue: 0.10, alpha: 0.88).cgColor)
        ctx.fillPath()
        ctx.setLineWidth(1.8 * scale)
        ctx.setStrokeColor(NSColor(red: 0.18, green: 0.84, blue: 0.45, alpha: 0.40).cgColor)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()

        let pad = 36 * scale
        let titleFont = NSFont.systemFont(ofSize: 22 * scale, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor(red: 0.18, green: 0.84, blue: 0.45, alpha: 1.0),
            .kern: 1.2 * scale
        ]
        let titleStr = NSAttributedString(string: p.0, attributes: titleAttrs)
        titleStr.draw(at: CGPoint(x: boxX + pad, y: boxY + boxHeight - pad - (20 * scale)))

        let descFont = NSFont.systemFont(ofSize: 20 * scale, weight: .regular)
        let descStyle = NSMutableParagraphStyle()
        descStyle.lineSpacing = 6 * scale
        let descAttrs: [NSAttributedString.Key: Any] = [
            .font: descFont,
            .foregroundColor: NSColor(red: 0.92, green: 0.88, blue: 0.94, alpha: 0.85),
            .paragraphStyle: descStyle
        ]
        let descStr = NSAttributedString(string: p.1, attributes: descAttrs)
        descStr.draw(in: CGRect(x: boxX + pad, y: boxY + pad, width: boxWidth - (pad * 2), height: boxHeight - pad - (60 * scale)))
    }
}

func drawNoSubscriptions(in rect: CGRect, scale: CGFloat, ctx: CGContext) {
    let pillars = [
        ("🔒 100% PRIVATE", "No accounts, no cloud sync, no tracking. Skips passwords automatically and never sends data to any server."),
        ("🎨 5 HIGHLIGHTER COLORS", "Sort links, code snippets, research, quotes, and todos by color vibe without interrupting your work."),
        ("⚡ GLOBAL SHORTCUTS", "Ctrl+Cmd+N opens your stash instantly. Ctrl+Cmd+1..5 switches active highlighter colors in half a second."),
        ("💎 NO SUBSCRIPTIONS", "A single $14.99 purchase. Own it forever without monthly or annual fees.")
    ]

    let boxWidth = (rect.width - (30 * scale)) / 2
    let boxHeight = (rect.height - (30 * scale)) / 2

    for (i, p) in pillars.enumerated() {
        let col = CGFloat(i % 2)
        let row = CGFloat(1 - (i / 2))

        let boxX = rect.minX + col * (boxWidth + (30 * scale))
        let boxY = rect.minY + row * (boxHeight + (30 * scale))
        let boxRect = CGRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 30 * scale, color: NSColor.black.withAlphaComponent(0.5).cgColor)
        let path = CGPath(roundedRect: boxRect, cornerWidth: 20 * scale, cornerHeight: 20 * scale, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(NSColor(red: 0.11, green: 0.08, blue: 0.10, alpha: 0.88).cgColor)
        ctx.fillPath()
        ctx.setLineWidth(1.8 * scale)
        ctx.setStrokeColor(NSColor(red: 1.0, green: 0.42, blue: 0.62, alpha: 0.40).cgColor)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()

        let pad = 36 * scale
        let titleFont = NSFont.systemFont(ofSize: 22 * scale, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor(red: 1.0, green: 0.42, blue: 0.62, alpha: 1.0),
            .kern: 1.2 * scale
        ]
        let titleStr = NSAttributedString(string: p.0, attributes: titleAttrs)
        titleStr.draw(at: CGPoint(x: boxX + pad, y: boxY + boxHeight - pad - (20 * scale)))

        let descFont = NSFont.systemFont(ofSize: 20 * scale, weight: .regular)
        let descStyle = NSMutableParagraphStyle()
        descStyle.lineSpacing = 6 * scale
        let descAttrs: [NSAttributedString.Key: Any] = [
            .font: descFont,
            .foregroundColor: NSColor(red: 0.92, green: 0.88, blue: 0.94, alpha: 0.85),
            .paragraphStyle: descStyle
        ]
        let descStr = NSAttributedString(string: p.1, attributes: descAttrs)
        descStr.draw(in: CGRect(x: boxX + pad, y: boxY + pad, width: boxWidth - (pad * 2), height: boxHeight - pad - (60 * scale)))
    }
}

// MARK: - Execution

let fileManager = FileManager.default
let outputDir = "screenshots/appstore"
try? fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

print("🎨 Rendering NibNab App Store Story Cards...")

for card in cards {
    print("📸 Rendering: \(card.filename)...")
    
    // 1. 2880x1800 (16:10 Retina)
    let img2880 = drawCard(spec: card, width: 2880, height: 1800)
    if let tiff = img2880.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) {
        let path = "\(outputDir)/\(card.filename)-2880x1800.png"
        try? png.write(to: URL(fileURLWithPath: path))
        print("   ✅ Created: \(path)")
    }

    // 2. 1440x900 (16:10 Standard)
    let img1440 = drawCard(spec: card, width: 1440, height: 900)
    if let tiff = img1440.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let png = bitmap.representation(using: .png, properties: [:]) {
        let path = "\(outputDir)/\(card.filename)-1440x900.png"
        try? png.write(to: URL(fileURLWithPath: path))
        print("   ✅ Created: \(path)")
    }
}

print("\n✨ All NibNab App Store Story Cards generated in \(outputDir)/")
