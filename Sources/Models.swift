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
