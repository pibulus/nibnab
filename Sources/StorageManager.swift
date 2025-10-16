import Foundation
import OSLog

final class StorageManager {
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

    func saveClip(_ clip: Clip, to colorName: String) {
        ensureDirectoryExists(for: colorName)
        let fileURL = clipFileURL(for: colorName)

        var markdown = "\n---\n"
        markdown += "### \(clip.appName)"
        if let url = clip.url {
            markdown += " | [\(url)](\(url))"
        }
        markdown += "\n"
        markdown += "\(formatter.string(from: clip.timestamp))\n\n"
        markdown += "\(clip.text)\n"

        guard let data = markdown.data(using: .utf8) else {
            self.logger.error("Unable to encode clip markdown for \(colorName, privacy: .public)")
            return
        }

        if self.fileManager.fileExists(atPath: fileURL.path) {
            do {
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                self.logger.error("Failed appending clip to \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        } else {
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                self.logger.error("Failed writing clip file \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
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

    func deleteClip(_ clip: Clip, from colorName: String) {
        let remainingClips = loadClips(for: colorName).filter { $0.id != clip.id }
        if remainingClips.isEmpty {
            deleteAllClips(for: colorName)
        } else {
            rewriteClips(remainingClips, for: colorName)
        }
    }

    func rewriteClips(_ clips: [Clip], for colorName: String) {
        let fileURL = clipFileURL(for: colorName)

        do {
            if self.fileManager.fileExists(atPath: fileURL.path) {
                try self.fileManager.removeItem(at: fileURL)
            }
        } catch {
            self.logger.error("Failed removing existing clip file \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        for clip in clips {
            saveClip(clip, to: colorName)
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

        var clips: [Clip] = []

        let sections = content.components(separatedBy: "\n---\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for section in sections {
            let lines = section.components(separatedBy: "\n")
            guard lines.count >= 3 else { continue }

            var appName = ""
            var url: String? = nil
            var timestamp = Date()
            var text = ""

            var lineIndex = 0

            for (index, line) in lines.enumerated() {
                if line.hasPrefix("###") {
                    lineIndex = index
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
            }

            if lineIndex + 1 < lines.count {
                let timestampLine = lines[lineIndex + 1].trimmingCharacters(in: .whitespaces)
                let cleanedTimestamp = timestampLine.replacingOccurrences(of: " Bangkok", with: "")
                if let parsedDate = formatter.date(from: cleanedTimestamp) {
                    timestamp = parsedDate
                }
            }

            if lineIndex + 2 < lines.count {
                let textLines = Array(lines[(lineIndex + 2)...])
                text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }

            if !appName.isEmpty && !text.isEmpty {
                let clip = Clip(
                    text: text,
                    timestamp: timestamp,
                    url: url,
                    appName: appName
                )
                clips.append(clip)
            }
        }

        return clips.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Helpers

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
