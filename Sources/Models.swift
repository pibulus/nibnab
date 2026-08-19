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

    init(text: String, timestamp: Date, url: String?, appName: String, order: Int = 0, id: UUID? = nil) {
        self.id = id ?? UUID()
        self.text = text
        self.timestamp = timestamp
        self.url = url
        self.appName = appName
        self.order = order
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

            let looksHex = body.count == 6 && body.allSatisfy { $0.isHexDigit }
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
}

extension Array where Element == Clip {
    /// Collapses a collection into a single clip, oldest text first. Keeps the
    /// oldest clip's identity so a merge reads as "everything folded into the
    /// first one" rather than a brand new clip appearing.
    func mergedIntoOne(now: Date = Date()) -> Clip? {
        guard count > 1, let oldest = self.min(by: { $0.timestamp < $1.timestamp }) else { return first }

        let ordered = sorted { $0.timestamp < $1.timestamp }
        return Clip(
            text: ordered.map(\.text).joined(separator: "\n\n"),
            timestamp: now,
            url: ordered.compactMap(\.url).first,
            appName: oldest.appName,
            order: 0,
            id: oldest.id
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
