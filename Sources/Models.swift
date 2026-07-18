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
    var screenshotPath: String?

    init(text: String, timestamp: Date, url: String?, appName: String, screenshotPath: String? = nil, order: Int = 0, id: UUID? = nil) {
        self.id = id ?? UUID()
        self.text = text
        self.timestamp = timestamp
        self.url = url
        self.appName = appName
        self.order = order
        self.screenshotPath = screenshotPath
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
