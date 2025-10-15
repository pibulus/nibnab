import Foundation
import UniformTypeIdentifiers

// MARK: - Clip Model
struct Clip: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let text: String
    let timestamp: Date
    let url: String?
    let appName: String
    var screenshotPath: String?

    init(text: String, timestamp: Date, url: String?, appName: String, screenshotPath: String? = nil, id: UUID? = nil) {
        self.id = id ?? UUID()
        self.text = text
        self.timestamp = timestamp
        self.url = url
        self.appName = appName
        self.screenshotPath = screenshotPath
    }
}

extension UTType {
    static let nibNabClip = UTType(exportedAs: "com.pibulus.nibnab.clip")
}
