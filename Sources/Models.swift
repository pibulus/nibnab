import Foundation
import UniformTypeIdentifiers
import CoreTransferable

// MARK: - Clip Model
struct Clip: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let text: String
    let timestamp: Date
    let url: String?
    let appName: String
    var order: Int = 0
    var imagePaths: [String] = []

    /// Backward-compatible accessor for primary image
    var imagePath: String? {
        imagePaths.first
    }

    init(text: String, timestamp: Date, url: String?, appName: String, order: Int = 0, id: UUID? = nil, imagePaths: [String] = [], imagePath: String? = nil) {
        self.id = id ?? UUID()
        self.text = text
        self.timestamp = timestamp
        self.url = url
        self.appName = appName
        self.order = order
        if !imagePaths.isEmpty {
            self.imagePaths = imagePaths
        } else if let single = imagePath {
            self.imagePaths = [single]
        } else {
            self.imagePaths = []
        }
    }
}

extension Dictionary where Key == String, Value == [Clip] {
    /// Pulls a set of clips out of whichever collections hold them and reports
    /// which ones changed. Search results can span colours, so a merge has to
    /// know every collection it touched — both to rewrite them and to snapshot
    /// them for undo.
    mutating func removeClips(ids: Set<UUID>) -> Set<String> {
        var touched: Set<String> = []
        for (name, list) in self {
            let kept = list.filter { !ids.contains($0.id) }
            if kept.count != list.count {
                self[name] = kept
                touched.insert(name)
            }
        }
        return touched
    }
}

enum NibTag {
    /// `#tag` inside clip text. Captured text is full of things that merely
    /// start with a hash — `#FFEB3B`, `# Heading`, `#include`, `#42`, CSS, code
    /// comments — so a tag must start with a letter, hold only word characters,
    /// sit after whitespace or a line start, and not look like a hex colour.
    static func matches(in text: String) -> [Range<String.Index>] {
        var found: [Range<String.Index>] = []
        var index = text.startIndex

        while index < text.endIndex {
            guard text[index] == "#" else {
                index = text.index(after: index)
                continue
            }
            // Must start a word: beginning of text, or preceded by whitespace.
            let atWordStart: Bool
            if index == text.startIndex {
                atWordStart = true
            } else {
                atWordStart = text[text.index(before: index)].isWhitespace
            }

            var end = text.index(after: index)
            var body = ""
            while end < text.endIndex, text[end].isLetter || text[end].isNumber || text[end] == "_" || text[end] == "-" {
                body.append(text[end])
                end = text.index(after: end)
            }

            let looksHex = (body.count == 3 || body.count == 6 || body.count == 8) && body.allSatisfy { $0.isHexDigit }
            if atWordStart, let first = body.first, first.isLetter,
               body.count >= 2, body.count <= 24, !looksHex {
                found.append(index..<end)
            }
            index = end > index ? end : text.index(after: index)
        }
        return found
    }

    static func tags(in text: String) -> [String] {
        var seen = Set<String>()
        return matches(in: text).map { String(text[$0]) }.filter { seen.insert($0.lowercased()).inserted }
    }

    /// Anti-drift normalization: Snaps tags to existing vocabulary where possible.
    /// If `#idea` exists and a new tag is `#ideas`, snaps to `#idea`.
    /// If `#ideas` exists and a new tag is `#idea`, snaps to `#ideas`.
    static func canonicalTag(_ tag: String, existingTags: [String]) -> String {
        let cleanTag = tag.hasPrefix("#") ? tag : "#\(tag)"
        let lower = cleanTag.lowercased()

        // Exact match (case-insensitive)
        if let exact = existingTags.first(where: { $0.lowercased() == lower }) {
            return exact
        }

        // Plural / singular snapping: check if `tag + s` or `tag - s` matches existing vocabulary
        if lower.hasSuffix("s") && lower.count > 3 {
            let singular = String(lower.dropLast())
            if let match = existingTags.first(where: { $0.lowercased() == singular }) {
                return match
            }
        } else {
            let plural = lower + "s"
            if let match = existingTags.first(where: { $0.lowercased() == plural }) {
                return match
            }
        }

        return cleanTag
    }
}

extension Array where Element == Clip {
    /// Collapses a collection into a single clip, oldest text first. Keeps the
    /// oldest clip's identity so a merge reads as "everything folded into the
    /// first one" rather than a brand new clip appearing.
    func mergedIntoOne(now: Date = Date()) -> Clip? {
        guard count > 1, let oldest = self.min(by: { $0.timestamp < $1.timestamp }) else { return first }

        let ordered = sorted { $0.timestamp < $1.timestamp }
        let allImages = ordered.flatMap(\.imagePaths)
        return Clip(
            text: ordered.map(\.text).joined(separator: "\n\n"),
            timestamp: now,
            url: ordered.compactMap(\.url).first,
            appName: oldest.appName,
            order: 0,
            id: oldest.id,
            imagePaths: allImages
        )
    }
}

extension Clip: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .nibNabClip)
        ProxyRepresentation(exporting: \.text)
    }
}

extension UTType {
    static let nibNabClip = UTType(exportedAs: "com.pibulus.nibnab.clip")
}
