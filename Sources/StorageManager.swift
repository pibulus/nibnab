import CryptoKit
import Foundation
import OSLog

@MainActor
final class StorageManager {
    private static let maxClipsPerColor = 100

    private let baseURL: URL
    private let fileManager: FileManager
    private let logger: Logger
    private lazy var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let bundleID = Bundle.main.bundleIdentifier ?? "com.pibulus.nibnab"
        self.logger = Logger(subsystem: bundleID, category: "Storage")

        let supportDirectory = self.fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? self.fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let appDirectory = supportDirectory.appendingPathComponent(bundleID, isDirectory: true)
        self.baseURL = appDirectory

        do {
            try self.fileManager.createDirectory(at: self.baseURL, withIntermediateDirectories: true)
        } catch {
            self.logger.error("Failed to create storage root at \(self.baseURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        migrateLegacyStorage()
        createColorDirectories()
    }

    func deleteAllClips(for colorName: String) {
        let fileURL = clipFileURL(for: colorName)
        do {
            if self.fileManager.fileExists(atPath: fileURL.path) {
                try self.fileManager.removeItem(at: fileURL)
            }
        } catch {
            self.logger.error("Failed deleting clip file \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func rewriteClips(_ clips: [Clip], for colorName: String) {
        ensureDirectoryExists(for: colorName)

        let normalizedClips = Array(clips.prefix(Self.maxClipsPerColor))

        if normalizedClips.isEmpty {
            deleteAllClips(for: colorName)
            return
        }

        let fileURL = clipFileURL(for: colorName)
        let markdown = normalizedClips.map(markdownSection(for:)).joined()

        guard let data = markdown.data(using: .utf8) else {
            self.logger.error("Unable to encode clip markdown for \(colorName, privacy: .public)")
            return
        }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            self.logger.error("Failed writing clip file \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadClips(for colorName: String) -> [Clip] {
        let fileURL = clipFileURL(for: colorName)

        guard self.fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let content: String
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            self.logger.error("Failed reading clip file \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return []
        }

        let sections = content.components(separatedBy: "\n---\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let clips = sections.compactMap(parseClip(from:))
        return clips.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Helpers

    private func parseClip(from section: String) -> Clip? {
        let lines = section.components(separatedBy: "\n")
        guard lines.count >= 3 else { return nil }

        var appName = ""
        var url: String? = nil
        var clipID: UUID? = nil
        var timestamp = Date()
        var text = ""
        var headerIndex = 0

        for (index, line) in lines.enumerated() {
            guard line.hasPrefix("###") else { continue }

            headerIndex = index
            let headerContent = line.replacingOccurrences(of: "###", with: "").trimmingCharacters(in: .whitespaces)

            if headerContent.contains("|") {
                let parts = headerContent.components(separatedBy: "|")
                appName = parts[0].trimmingCharacters(in: .whitespaces)

                if let urlPart = parts.last,
                   let urlStart = urlPart.range(of: "](")?.upperBound,
                   let urlEnd = urlPart[urlStart...].firstIndex(of: ")") {
                    url = String(urlPart[urlStart..<urlEnd])
                }
            } else {
                appName = headerContent
            }
            break
        }

        guard !appName.isEmpty else { return nil }

        var contentStartIndex = headerIndex + 1

        while contentStartIndex < lines.count {
            let metadataLine = lines[contentStartIndex].trimmingCharacters(in: .whitespaces)

            if metadataLine.isEmpty {
                contentStartIndex += 1
                break
            }

            if metadataLine.hasPrefix("id: ") {
                clipID = UUID(uuidString: String(metadataLine.dropFirst(4)))
            } else if metadataLine.hasPrefix("timestamp: ") {
                let timestampValue = String(metadataLine.dropFirst("timestamp: ".count))
                if let parsedDate = formatter.date(from: timestampValue) {
                    timestamp = parsedDate
                }
            } else {
                let cleanedTimestamp = metadataLine.replacingOccurrences(of: " Bangkok", with: "")
                if let parsedDate = formatter.date(from: cleanedTimestamp) {
                    timestamp = parsedDate
                } else {
                    break
                }
            }

            contentStartIndex += 1
        }

        if contentStartIndex < lines.count {
            let textLines = Array(lines[contentStartIndex...])
            text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard !text.isEmpty else { return nil }

        let resolvedID = clipID ?? legacyID(
            appName: appName,
            url: url,
            timestamp: timestamp,
            text: text
        )

        return Clip(
            text: text,
            timestamp: timestamp,
            url: url,
            appName: appName,
            id: resolvedID
        )
    }

    private func markdownSection(for clip: Clip) -> String {
        var markdown = "\n---\n"
        markdown += "### \(clip.appName)"
        if let url = clip.url {
            markdown += " | [\(url)](\(url))"
        }
        markdown += "\n"
        markdown += "id: \(clip.id.uuidString)\n"
        markdown += "timestamp: \(formatter.string(from: clip.timestamp))\n\n"
        markdown += "\(clip.text)\n"
        return markdown
    }

    private func legacyID(appName: String, url: String?, timestamp: Date, text: String) -> UUID {
        let legacyFingerprint = [
            appName,
            url ?? "",
            formatter.string(from: timestamp),
            text
        ].joined(separator: "\u{1F}")

        let digest = SHA256.hash(data: Data(legacyFingerprint.utf8))
        let bytes = Array(digest.prefix(16))

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private func migrateLegacyStorage() {
        let legacyBase = self.fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".nibnab", isDirectory: true)
        guard self.fileManager.fileExists(atPath: legacyBase.path) else { return }

        do {
            let items = try self.fileManager.contentsOfDirectory(at: legacyBase, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            var migrationSucceeded = true

            for item in items {
                let destination = self.baseURL.appendingPathComponent(item.lastPathComponent, isDirectory: true)
                if self.fileManager.fileExists(atPath: destination.path) { continue }

                do {
                    try self.fileManager.copyItem(at: item, to: destination)
                    self.logger.info("Migrated legacy storage item \(item.lastPathComponent, privacy: .public)")
                } catch {
                    self.logger.error("Failed migrating \(item.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    migrationSucceeded = false
                }
            }

            if migrationSucceeded {
                do {
                    try self.fileManager.removeItem(at: legacyBase)
                    self.logger.info("Removed legacy storage directory at \(legacyBase.path, privacy: .public)")
                } catch {
                    self.logger.error("Failed removing legacy storage directory: \(error.localizedDescription, privacy: .public)")
                }
            }
        } catch {
            self.logger.error("Failed reading legacy storage directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func createColorDirectories() {
        for color in NibColor.all {
            ensureDirectoryExists(for: color.name)
        }
    }

    private func ensureDirectoryExists(for colorName: String) {
        let directory = directoryURL(for: colorName)
        do {
            try self.fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            self.logger.error("Failed creating directory \(directory.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func directoryURL(for colorName: String) -> URL {
        self.baseURL.appendingPathComponent(colorName.lowercased(), isDirectory: true)
    }

    private func clipFileURL(for colorName: String) -> URL {
        directoryURL(for: colorName).appendingPathComponent("\(colorName.lowercased())_clips.md")
    }
}
