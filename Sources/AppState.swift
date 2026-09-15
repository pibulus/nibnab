import Cocoa
import SwiftUI
import ServiceManagement

// NibNab's voice is synthesised by Weightless — no sample files, and no two
// plays identical. Each case names the Weightless cue it speaks through.
enum NibSound {
    case capture, copy, delete, toggleOn, toggleOff, switchColor, celebrate, nope, open, close

    /// The Weightless cue this speaks through. Several actions deliberately
    /// share one — a tap is a tap.
    var cue: String {
        switch self {
        case .capture:                    return "notify"
        case .copy, .switchColor, .open:  return "select"
        case .delete, .close, .toggleOff: return "toggleOff"
        case .toggleOn:                   return "toggleOn"
        case .celebrate:                  return "success"
        case .nope:                       return "error"
        }
    }
}

@MainActor
class AppState: ObservableObject {
    static let maxClipsPerColor = 100

    @Published var activeColor: NibColor {
        didSet {
            UserDefaults.standard.set(activeColor.name, forKey: "activeColorName")
            delegate?.updateMenubarIcon()
            // One scale degree per colour — cycling them plays a little run.
            let degree = NibColor.all.firstIndex { $0.name == activeColor.name } ?? 0
            play(.switchColor, transpose: Weightless.transposes[degree])
            // Inside the popover the whole UI recolors — that IS the feedback.
            // Only announce color switches when the popover is closed.
            if toastGate.shouldAllow(.color), delegate?.popover.isShown != true {
                showToast(activeColor.name.replacingOccurrences(of: "Highlighter ", with: ""), color: activeColor)
            }
        }
    }
    @Published var launchAtLogin = false {
        didSet {
            guard !isSyncingLaunchAtLogin, launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // register/unregister fails for builds run outside /Applications —
                // snap the toggle back to what the system actually has instead
                // of showing a checkbox that lies.
                isSyncingLaunchAtLogin = true
                launchAtLogin = SMAppService.mainApp.status == .enabled
                isSyncingLaunchAtLogin = false
            }
        }
    }
    private var isSyncingLaunchAtLogin = false
    @Published var soundEffectsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEffectsEnabled, forKey: "soundEffectsEnabled")
        }
    }
    @Published var isMonitoring: Bool {
        didSet {
            UserDefaults.standard.set(isMonitoring, forKey: "isMonitoring")
            play(isMonitoring ? .toggleOn : .toggleOff)
            if isMonitoring {
                startClipboardMonitoring()
                if toastGate.shouldAllow(.monitoring) {
                    showToast("Capturing ON", color: NibColor.green)
                }
            } else {
                stopClipboardMonitoring()
                if toastGate.shouldAllow(.monitoring) {
                    showToast("Capturing OFF", color: NibColor.orange)
                }
            }
            delegate?.syncSelectionMonitoring()
            delegate?.updateMenubarIcon()
        }
    }
    @Published var clips: [String: [Clip]] = [:]
    @Published var colorLabels: [String: String] = [:] {
        didSet {
            UserDefaults.standard.set(colorLabels, forKey: "colorLabels")
        }
    }
    /// One level of undo, deep enough for "oh no" and no deeper. Anything that
    /// destroys clips snapshots the colour first.
    @Published private(set) var canUndo = false
    private var undoSnapshot: (colors: [String: [Clip]], what: String)?

    // Bumped every time the popover closes — the UI watches it to tear down any
    // open modal, so reopening never resurfaces a clip from another color.
    @Published var popoverClosedCount = 0

    @Published var toastMessage: String? = nil
    @Published var toastUndoable = false
    @Published var toastColor: NibColor? = nil

    weak var delegate: AppDelegate?
    private var clipboardTimer: Timer?
    private var lastChangeCount: Int = 0
    var lastCapturedText: String? = nil
    /// The pasteboard changeCount of NibNab's own last write. The monitor skips
    /// exactly that change — a boolean flag raced the 0.5s poller and could be
    /// spent on the wrong change or left set, eating a real copy.
    private var selfWriteChangeCount = -1
    private var toastGate = ToastGate()
    let storageManager = StorageManager()
    private var lastCapturedImageHash: Int? = nil

    @Published var geminiApiKey: String {
        didSet {
            KeychainHelper.saveGeminiApiKey(geminiApiKey)
            UserDefaults.standard.removeObject(forKey: "geminiApiKey")
        }
    }

    var hasAiSuperpowers: Bool {
        !geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @Published var selectionCaptureEnabled: Bool {
        didSet {
            UserDefaults.standard.set(selectionCaptureEnabled, forKey: "autoCopyEnabled")
            delegate?.syncSelectionMonitoring()
        }
    }

    @Published var autoTagScreenshotsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoTagScreenshotsEnabled, forKey: "autoTagScreenshots")
        }
    }

    /// All unique tags across all color collections with their frequency counts,
    /// sorted by highest count first. Powers the ZipList-style Tag Rack Shelf.
    var allTagsWithCounts: [(tag: String, count: Int)] {
        var rawCounts: [String: Int] = [:]
        for (_, list) in clips {
            for clip in list {
                for tag in NibTag.tags(in: clip.text) {
                    rawCounts[tag.lowercased(), default: 0] += 1
                }
            }
        }
        let vocabulary = Array(rawCounts.keys)
        var counts: [String: Int] = [:]
        for (raw, count) in rawCounts {
            let canonical = NibTag.canonicalTag(raw, existingTags: vocabulary)
            counts[canonical, default: 0] += count
        }
        return counts.sorted { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value > rhs.value
            }
            return lhs.key < rhs.key
        }.map { (tag: $0.key, count: $0.value) }
    }

    init() {
        toastGate.suppressNext(.color)

        let initialColor: NibColor
        if let savedColorName = UserDefaults.standard.string(forKey: "activeColorName"),
           let savedColor = NibColor.all.first(where: { $0.name == savedColorName }) {
            initialColor = savedColor
        } else {
            initialColor = NibColor.yellow
        }
        activeColor = initialColor

        // Migrate from UserDefaults to Keychain if legacy key exists
        if let legacyKey = UserDefaults.standard.string(forKey: "geminiApiKey"), !legacyKey.isEmpty {
            KeychainHelper.saveGeminiApiKey(legacyKey)
            UserDefaults.standard.removeObject(forKey: "geminiApiKey")
        }

        geminiApiKey = KeychainHelper.loadGeminiApiKey()
            ?? (ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? "")

        soundEffectsEnabled = UserDefaults.standard.object(forKey: "soundEffectsEnabled") as? Bool ?? true
        isMonitoring = UserDefaults.standard.object(forKey: "isMonitoring") as? Bool ?? true
        selectionCaptureEnabled = UserDefaults.standard.object(forKey: "autoCopyEnabled") as? Bool ?? false
        autoTagScreenshotsEnabled = UserDefaults.standard.object(forKey: "autoTagScreenshots") as? Bool ?? false

        if let savedLabels = UserDefaults.standard.dictionary(forKey: "colorLabels") as? [String: String] {
            colorLabels = savedLabels
        }

        for color in NibColor.all {
            clips[color.name] = storageManager.loadClips(for: color.name)
        }

        launchAtLogin = SMAppService.mainApp.status == .enabled

        // Check if first launch - show welcome window
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunchedBefore {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.delegate?.showWelcomeWindow()
            }
        }
    }

    /// True when the next capture will silently evict the oldest clip.
    func isColorFull(_ colorName: String) -> Bool {
        (clips[colorName]?.count ?? 0) >= Self.maxClipsPerColor
    }

    func labelForColor(_ colorName: String) -> String {
        if let customLabel = colorLabels[colorName], !customLabel.isEmpty {
            return customLabel
        }
        return colorName.replacingOccurrences(of: "Highlighter ", with: "")
    }

    func setLabel(_ label: String, forColor colorName: String) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            colorLabels.removeValue(forKey: colorName)
        } else {
            let limited = String(trimmed.prefix(12))
            colorLabels[colorName] = limited
        }
    }

    // Password managers and other polite apps mark sensitive or ephemeral
    // pasteboard content with these types — never capture them.
    private static let skippedPasteboardTypes: [NSPasteboard.PasteboardType] = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
        NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")
    ]

    private static let imageFileExtensions: Set<String> = [
        "png", "jpg", "jpeg", "webp", "gif", "tiff", "tif", "heic", "bmp"
    ]

    private static func isImageFileURL(_ url: URL) -> Bool {
        imageFileExtensions.contains(url.pathExtension.lowercased())
    }

    private static func extractImageData(from pasteboard: NSPasteboard) -> Data? {
        if let pngData = pasteboard.data(forType: .png) {
            return pngData
        }
        if let tiffData = pasteboard.data(forType: .tiff),
           let imageRep = NSBitmapImageRep(data: tiffData),
           let pngData = imageRep.representation(using: .png, properties: [:]) {
            return pngData
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let firstImageURL = urls.first(where: isImageFileURL),
           let data = try? Data(contentsOf: firstImageURL),
           let imageRep = NSBitmapImageRep(data: data),
           let pngData = imageRep.representation(using: .png, properties: [:]) {
            return pngData
        }
        return nil
    }

    func startClipboardMonitoring() {
        clipboardTimer?.invalidate()
        lastChangeCount = NSPasteboard.general.changeCount

        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let pasteboard = NSPasteboard.general

                if pasteboard.changeCount != self.lastChangeCount {
                    self.lastChangeCount = pasteboard.changeCount

                    // NibNab put this here itself — copying a clip out must
                    // never file it straight back in.
                    if self.lastChangeCount == self.selfWriteChangeCount { return }

                    let types = pasteboard.types ?? []
                    if Self.skippedPasteboardTypes.contains(where: types.contains) {
                        return
                    }

                    let sourceApp = self.getCurrentAppName()
                    let browserURL = self.getCurrentBrowserURL(for: sourceApp)

                    // 1. Check for image data / screenshot first
                    if let imageData = Self.extractImageData(from: pasteboard) {
                        let imageHash = imageData.hashValue
                        if imageHash != self.lastCapturedImageHash {
                            self.lastCapturedImageHash = imageHash
                            self.lastCapturedText = nil
                            self.saveImageClip(data: imageData, to: self.activeColor, from: sourceApp, url: browserURL)
                            return
                        }
                    }

                    // 2. Otherwise capture text / file path
                    let captured = pasteboard.string(forType: .string) ?? Self.filePaths(from: pasteboard)

                    if let text = captured,
                       !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if text != self.lastCapturedText {
                            self.lastCapturedText = text
                            self.lastCapturedImageHash = nil
                            self.saveClip(text, to: self.activeColor, from: sourceApp, url: browserURL)
                            self.delegate?.pulseMenuBarIcon()
                        }
                    }
                }
            }
        }
        RunLoop.main.add(clipboardTimer!, forMode: .common)
    }

    private static func filePaths(from pasteboard: NSPasteboard) -> String? {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else { return nil }
        let paths = urls.filter { $0.isFileURL && !isImageFileURL($0) }.map(\.path)
        return paths.isEmpty ? nil : paths.joined(separator: "\n")
    }

    func stopClipboardMonitoring() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
    }

    func saveClip(_ text: String, to color: NibColor, from sourceApp: String, url: String? = nil) {
        // Trim on save so what's persisted round-trips identically
        // (the storage parser trims section text on load).
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Huge payload guard: Cap single clip text at 100,000 characters
        let maxCharacters = 100_000
        let processedText: String
        if trimmed.count > maxCharacters {
            processedText = String(trimmed.prefix(maxCharacters)) + "\n\n[...truncated: payload exceeded 100,000 characters]"
        } else {
            processedText = trimmed
        }

        // Re-capturing the newest clip again would just create a duplicate.
        if clips[color.name]?.first?.text == processedText { return }

        let clip = Clip(
            text: processedText,
            timestamp: Date(),
            url: url,
            appName: sourceApp
        )

        if clips[color.name] == nil {
            clips[color.name] = []
        }
        invalidateUndo()
        clips[color.name]?.insert(clip, at: 0)

        if var colorClips = clips[color.name], colorClips.count > Self.maxClipsPerColor {
            let evicted = colorClips.suffix(from: Self.maxClipsPerColor)
            for oldClip in evicted {
                for oldPath in oldClip.imagePaths {
                    storageManager.deleteImage(at: oldPath, for: color.name)
                }
            }
            colorClips = Array(colorClips.prefix(Self.maxClipsPerColor))
            clips[color.name] = colorClips
            showToast("Oldest clip archived (100 cap)", color: color)
        }

        if clips[color.name] != nil {
            reindexOrders(for: color.name)
            if let colorClips = clips[color.name] {
                storageManager.rewriteClips(colorClips, for: color.name)
            }
        }
        let isFirstInColor = clips[color.name]?.count == 1
        play(isFirstInColor ? .celebrate : .capture)
    }

    func saveImageClip(data: Data, to color: NibColor, from sourceApp: String, url: String? = nil) {
        // Coalesce burst screenshots from the same source app within 2 minutes (up to 10 images)
        if let topClip = clips[color.name]?.first,
           !topClip.imagePaths.isEmpty,
           topClip.imagePaths.count < 10,
           topClip.appName == sourceApp,
           abs(Date().timeIntervalSince(topClip.timestamp)) < 120,
           let relPath = storageManager.saveImageData(data, id: topClip.id, for: color.name) {

            let updatedImages = topClip.imagePaths + [relPath]
            let updatedClip = Clip(
                text: topClip.text,
                timestamp: Date(),
                url: topClip.url ?? url,
                appName: topClip.appName,
                order: topClip.order,
                id: topClip.id,
                imagePaths: updatedImages
            )
            clips[color.name]?[0] = updatedClip
            if let colorClips = clips[color.name] {
                storageManager.rewriteClips(colorClips, for: color.name)
            }
            play(.capture)
            delegate?.pulseMenuBarIcon()
            showToast("Added to screenshot card (\(updatedImages.count))", color: color)

            // Run OCR for the new image and append recognized text
            Task {
                let recognized = await VisionOCR.recognizeText(from: data)
                if !recognized.isEmpty {
                    await MainActor.run {
                        if let current = self.clips[color.name]?.first(where: { $0.id == topClip.id }) {
                            let newText: String
                            if current.text.hasPrefix("Screenshot (") {
                                newText = recognized
                            } else {
                                newText = current.text + "\n\n" + recognized
                            }
                            self.updateClipText(clipID: topClip.id, newText: newText, in: color.name)
                        }
                    }
                }
            }
            return
        }

        let clipID = UUID()
        guard let relPath = storageManager.saveImageData(data, id: clipID, for: color.name) else { return }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "MMM d, h:mm a"
        let placeholder = "Screenshot (\(timeFormatter.string(from: Date())))"

        let clip = Clip(
            text: placeholder,
            timestamp: Date(),
            url: url,
            appName: sourceApp,
            order: 0,
            id: clipID,
            imagePaths: [relPath]
        )

        if clips[color.name] == nil {
            clips[color.name] = []
        }
        invalidateUndo()
        clips[color.name]?.insert(clip, at: 0)

        if var colorClips = clips[color.name], colorClips.count > Self.maxClipsPerColor {
            let evicted = colorClips.suffix(from: Self.maxClipsPerColor)
            for oldClip in evicted {
                for oldPath in oldClip.imagePaths {
                    storageManager.deleteImage(at: oldPath, for: color.name)
                }
            }
            colorClips = Array(colorClips.prefix(Self.maxClipsPerColor))
            clips[color.name] = colorClips
            showToast("Oldest clip archived (100 cap)", color: color)
        }

        reindexOrders(for: color.name)
        if let colorClips = clips[color.name] {
            storageManager.rewriteClips(colorClips, for: color.name)
        }

        let isFirstInColor = clips[color.name]?.count == 1
        play(isFirstInColor ? .celebrate : .capture)
        delegate?.pulseMenuBarIcon()

        // Run Apple Vision OCR in background
        Task {
            let recognized = await VisionOCR.recognizeText(from: data)
            if !recognized.isEmpty {
                await MainActor.run {
                    // Only replace if the user hasn't already manually edited the placeholder
                    if let current = self.clips[color.name]?.first(where: { $0.id == clipID }),
                       current.text.hasPrefix("Screenshot (") {
                        self.updateClipText(clipID: clipID, newText: recognized, in: color.name)
                    }
                }

                // Optional AI auto-tag pass (strictly opt-in via autoTagScreenshotsEnabled)
                if self.hasAiSuperpowers && self.autoTagScreenshotsEnabled {
                    let existing = await MainActor.run { self.allTagsWithCounts.map(\.tag) }
                    let suggested = await NibAI.suggestTags(for: recognized, existingTags: existing, apiKey: self.geminiApiKey)
                    if !suggested.isEmpty {
                        await MainActor.run {
                            if let current = self.clips[color.name]?.first(where: { $0.id == clipID }) {
                                let taggedText = current.text + "\n\n" + suggested.joined(separator: " ")
                                self.updateClipText(clipID: clipID, newText: taggedText, in: color.name)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Captures the current text selection (if accessibility is trusted) or
    /// pasteboard contents directly into the specified color collection.
    func captureCurrentSelectionOrClipboard(to targetColor: NibColor) {
        let sourceApp = getCurrentAppName()
        let browserURL = getCurrentBrowserURL(for: sourceApp)

        var textToSave: String? = nil
        if let focused = AXUIElement.focusedElement,
           let selected = focused.selectedText,
           !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textToSave = selected
        }

        if textToSave == nil {
            let pasteboard = NSPasteboard.general
            if let imageData = Self.extractImageData(from: pasteboard) {
                saveImageClip(data: imageData, to: targetColor, from: sourceApp, url: browserURL)
                return
            }
            textToSave = pasteboard.string(forType: .string) ?? Self.filePaths(from: pasteboard)
        }

        if let text = textToSave, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveClip(text, to: targetColor, from: sourceApp, url: browserURL)
            showToast("Saved to \(labelForColor(targetColor.name))", color: targetColor)
        } else {
            showToast("Nothing to copy", color: targetColor)
        }
    }

    // MARK: - AI Actions
    func aiAutoTagClip(_ clip: Clip, in colorName: String) {
        guard hasAiSuperpowers else { return }
        Task {
            let existing = allTagsWithCounts.map(\.tag)
            let suggested = await NibAI.suggestTags(for: clip.text, existingTags: existing, apiKey: geminiApiKey)
            guard !suggested.isEmpty else { return }

            await MainActor.run {
                var newText = clip.text
                for tag in suggested {
                    if !newText.contains(tag) {
                        newText += " " + tag
                    }
                }
                self.updateClipText(clipID: clip.id, newText: newText, in: colorName)
                self.play(.celebrate)
                self.showToast("AI Auto-Tagged", color: activeColor)
            }
        }
    }

    func aiCleanClipText(_ clip: Clip, in colorName: String) {
        guard hasAiSuperpowers else { return }
        Task {
            do {
                let cleaned = try await NibAI.cleanOCR(text: clip.text, apiKey: geminiApiKey)
                await MainActor.run {
                    self.updateClipText(clipID: clip.id, newText: cleaned, in: colorName)
                    self.play(.celebrate)
                    self.showToast("AI Cleaned to Markdown", color: activeColor)
                }
            } catch {
                await MainActor.run {
                    self.play(.nope)
                    self.showToast("AI error", color: NibColor.orange)
                }
            }
        }
    }

    func aiSummarizeClip(_ clip: Clip, in colorName: String) {
        guard hasAiSuperpowers else { return }
        Task {
            do {
                let summary = try await NibAI.summarizeToBullets(text: clip.text, apiKey: geminiApiKey)
                await MainActor.run {
                    let combined = clip.text + "\n\n### ⚡ Summary\n" + summary
                    self.updateClipText(clipID: clip.id, newText: combined, in: colorName)
                    self.play(.celebrate)
                    self.showToast("AI Summary Added", color: activeColor)
                }
            } catch {
                await MainActor.run {
                    self.play(.nope)
                    self.showToast("AI error", color: NibColor.orange)
                }
            }
        }
    }

    func updateClipText(clipID: UUID, newText: String, in preferredColorName: String? = nil) {
        let targetColor: String
        let targetIndex: Int

        if let preferred = preferredColorName,
           let index = clips[preferred]?.firstIndex(where: { $0.id == clipID }) {
            targetColor = preferred
            targetIndex = index
        } else {
            var foundColor: String? = nil
            var foundIndex: Int? = nil
            for (color, list) in clips {
                if let idx = list.firstIndex(where: { $0.id == clipID }) {
                    foundColor = color
                    foundIndex = idx
                    break
                }
            }
            guard let c = foundColor, let i = foundIndex else { return }
            targetColor = c
            targetIndex = i
        }

        let existing = clips[targetColor]![targetIndex]
        let updated = Clip(
            text: newText,
            timestamp: existing.timestamp,
            url: existing.url,
            appName: existing.appName,
            order: existing.order,
            id: existing.id,
            imagePath: existing.imagePath
        )
        clips[targetColor]?[targetIndex] = updated
        if let colorClips = clips[targetColor] {
            storageManager.rewriteClips(colorClips, for: targetColor)
        }
    }

    private func getCurrentBrowserURL(for appName: String) -> String? {
        guard !SandboxInfo.isSandboxed else { return nil }
        let scriptText: String
        switch appName {
        case "Safari", "Safari Technology Preview":
            scriptText = "tell application \"\(appName)\" to return URL of front document"
        case "Google Chrome", "Brave Browser", "Microsoft Edge", "Arc", "Chromium", "Vivaldi", "Orion":
            scriptText = "tell application \"\(appName)\" to return URL of active tab of front window"
        default:
            return nil
        }
        var result: String? = nil
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            defer { semaphore.signal() }
            var error: NSDictionary?
            guard let script = NSAppleScript(source: scriptText),
                  let output = script.executeAndReturnError(&error).stringValue,
                  !output.isEmpty,
                  output.hasPrefix("http://") || output.hasPrefix("https://") else {
                return
            }
            result = output
        }
        _ = semaphore.wait(timeout: .now() + 0.15)
        return result
    }

    func play(_ sound: NibSound, transpose: Float = 1) {
        guard soundEffectsEnabled else { return }
        WeightlessPlayer.shared.play(cue: sound.cue, transpose: transpose)
    }

    func getCurrentAppName() -> String {
        return NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
    }

    private func snapshotForUndo(_ colorNames: [String], what: String) {
        if let old = undoSnapshot {
            for name in old.colors.keys { storageManager.purgeUndoImages(for: name) }
        }
        var snapshot: [String: [Clip]] = [:]
        for name in colorNames { snapshot[name] = clips[name] ?? [] }
        undoSnapshot = (snapshot, what)
        canUndo = true
    }

    private func invalidateUndo() {
        if let snapshot = undoSnapshot {
            for name in snapshot.colors.keys { storageManager.purgeUndoImages(for: name) }
        }
        undoSnapshot = nil
        canUndo = false
        toastUndoable = false
    }

    func undoLast() {
        guard let snapshot = undoSnapshot else { return }
        for (name, list) in snapshot.colors {
            storageManager.restoreImagesFromUndo(for: name)
            clips[name] = list
            storageManager.rewriteClips(list, for: name)
        }
        undoSnapshot = nil
        canUndo = false
        play(.open)
        showToast("Undid \(snapshot.what)", color: activeColor)
    }

    func deleteClip(_ clip: Clip, from colorName: String) {
        snapshotForUndo([colorName], what: "delete")
        clips[colorName]?.removeAll { $0.id == clip.id }
        for imagePath in clip.imagePaths {
            storageManager.moveImageToUndo(at: imagePath, for: colorName)
        }
        storageManager.rewriteClips(clips[colorName] ?? [], for: colorName)
        play(.delete)
        showToast("Clip deleted", color: activeColor, undoable: true)
    }

    func clearAllClips(for colorName: String) {
        snapshotForUndo([colorName], what: "clear all")
        let clearedCount = undoSnapshot?.colors[colorName]?.count ?? 0
        if let colorClips = clips[colorName] {
            for clip in colorClips {
                for imagePath in clip.imagePaths {
                    storageManager.moveImageToUndo(at: imagePath, for: colorName)
                }
            }
        }
        clips[colorName] = []
        storageManager.deleteAllClips(for: colorName)
        play(.delete)
        showToast("Cleared \(clearedCount) clips", color: activeColor, undoable: true)
    }

    func moveClip(_ clip: Clip, from sourceColor: String, to targetColor: String) {
        snapshotForUndo([sourceColor, targetColor], what: "move")
        clips[sourceColor]?.removeAll { $0.id == clip.id }

        var targetClips = clips[targetColor] ?? []

        var newPaths: [String] = []
        for path in clip.imagePaths {
            if let newPath = storageManager.moveImage(at: path, from: sourceColor, to: targetColor) {
                newPaths.append(newPath)
            } else {
                newPaths.append(path)
            }
        }

        let updatedClip = Clip(
            text: clip.text,
            timestamp: clip.timestamp,
            url: clip.url,
            appName: clip.appName,
            order: clip.order,
            id: clip.id,
            imagePaths: newPaths
        )

        // Insert preserving newest-first order so the cap below always trims
        // the oldest clip — never the clip the user just moved.
        let insertionIndex = targetClips.firstIndex { $0.timestamp <= updatedClip.timestamp } ?? targetClips.count
        targetClips.insert(updatedClip, at: insertionIndex)

        if targetClips.count > Self.maxClipsPerColor,
           let dropIndex = targetClips.indices.reversed().first(where: { targetClips[$0].id != updatedClip.id }) {
            let evicted = targetClips.remove(at: dropIndex)
            for evictedPath in evicted.imagePaths {
                storageManager.deleteImage(at: evictedPath, for: targetColor)
            }
        }
        clips[targetColor] = targetClips

        storageManager.rewriteClips(clips[sourceColor] ?? [], for: sourceColor)
        storageManager.rewriteClips(targetClips, for: targetColor)
        play(.switchColor)
        showToast("Moved clip", color: activeColor, undoable: true)
    }

    func reorderClip(_ clip: Clip, in colorName: String, to targetIndex: Int) {
        snapshotForUndo([colorName], what: "reorder")
        guard var colorClips = clips[colorName] else { return }
        guard let sourceIndex = colorClips.firstIndex(of: clip) else { return }

        let movedClip = colorClips.remove(at: sourceIndex)
        let clampedTarget = min(targetIndex, colorClips.count)
        colorClips.insert(movedClip, at: clampedTarget)

        for i in colorClips.indices {
            colorClips[i].order = i
        }
        clips[colorName] = colorClips
        storageManager.rewriteClips(colorClips, for: colorName)
        showToast("Reordered clip", color: activeColor, undoable: true)
    }

    func testApiKey(_ key: String) async -> (success: Bool, message: String) {
        do {
            let res = try await NibAI.generateText(prompt: "Say OK", apiKey: key)
            return (!res.isEmpty, "Key verified! ✨")
        } catch {
            return (false, "Verification failed: \(error.localizedDescription)")
        }
    }

    private func reindexOrders(for colorName: String) {
        guard var colorClips = clips[colorName] else { return }
        for i in colorClips.indices {
            colorClips[i].order = i
        }
        clips[colorName] = colorClips
    }

    /// Collapses a whole collection into a single clip, oldest first, so a
    /// colour used as a scratch pad becomes one pasteable block.
    func mergeAllClips(in colorName: String) {
        guard let colorClips = clips[colorName], colorClips.count > 1,
              let merged = colorClips.mergedIntoOne() else { return }

        snapshotForUndo([colorName], what: "merge all")

        clips[colorName] = [merged]
        storageManager.rewriteClips([merged], for: colorName)
        play(.capture)
        showToast("Merged \(colorClips.count) clips", color: activeColor, undoable: true)
    }

    /// Export, then clear — but only if the file actually got written. A
    /// cancelled save panel must not take the clips with it.
    func exportAndClear(for colorName: String) {
        guard let colorClips = clips[colorName], !colorClips.isEmpty else { return }

        let plainText = colorClips.map(\.text).joined(separator: "\n\n---\n\n")
        presentExportPanel(
            defaultName: "\(exportFileStem(for: colorName))-clips.txt",
            content: plainText
        ) { [weak self] _ in
            self?.clearAllClips(for: colorName)
        }
    }

    func mergeClip(_ source: Clip, into target: Clip, in colorName: String) {
        snapshotForUndo([colorName], what: "merge")
        guard var colorClips = clips[colorName],
              let targetIndex = colorClips.firstIndex(of: target) else { return }

        let mergedText = target.text + "\n\n" + source.text
        let combinedImages = target.imagePaths + source.imagePaths

        let merged = Clip(
            text: mergedText,
            timestamp: Date(),
            url: target.url ?? source.url,
            appName: target.appName,
            order: target.order,
            id: target.id,
            imagePaths: combinedImages
        )
        colorClips[targetIndex] = merged
        colorClips.removeAll { $0.id == source.id }

        for i in colorClips.indices {
            colorClips[i].order = i
        }
        clips[colorName] = colorClips
        storageManager.rewriteClips(colorClips, for: colorName)
        play(.capture)
        showToast("Clips merged", color: activeColor, undoable: true)
    }

    /// The only place NibNab writes the pasteboard. Everything else routes
    /// through here so the monitor always knows which change was ours.
    private func writePasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        selfWriteChangeCount = pasteboard.changeCount
        lastCapturedText = text
    }

    func copyToPasteboard(_ text: String) {
        writePasteboard(text)
        play(.copy)
    }

    /// Text selected in another app: put it on the clipboard and file it, in
    /// that order, so the write is stamped before the monitor can see it.
    func captureSelection(_ text: String, from sourceApp: String) {
        writePasteboard(text)
        saveClip(text, to: activeColor, from: sourceApp)
    }

    func switchToColor(_ color: NibColor, announce: Bool = true) {
        guard activeColor.name != color.name else { return }
        if !announce {
            toastGate.suppressNext(.color)
        }
        // activeColor's didSet fires the toast, sound, and menubar redraw.
        activeColor = color
    }

    func setMonitoring(_ enabled: Bool, suppressToast: Bool) {
        if suppressToast {
            toastGate.suppressNext(.monitoring)
        }
        isMonitoring = enabled
    }

    func toggleMonitoring(suppressToast: Bool) {
        if suppressToast {
            toastGate.suppressNext(.monitoring)
        }
        isMonitoring.toggle()
    }

    func updateClip(_ clip: Clip, newText: String, in colorName: String) {
        let trimmedText = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        guard let index = clips[colorName]?.firstIndex(where: { $0.id == clip.id }) else { return }
        invalidateUndo()

        clips[colorName]?[index] = Clip(
            text: trimmedText,
            timestamp: clip.timestamp,
            url: clip.url,
            appName: clip.appName,
            order: clip.order,
            id: clip.id,
            imagePaths: clip.imagePaths
        )

        if let colorClips = clips[colorName] {
            storageManager.rewriteClips(colorClips, for: colorName)
        }

        play(.capture)
    }

    // Export takes an explicit list so it can serve a whole colour OR a set of
    // search results — "search a tag, export those" only works if the actions
    // follow the search rather than the collection.
    func exportAsMarkdown(_ clipsToExport: [Clip], title: String, stem: String) {
        guard !clipsToExport.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"

        var markdown = "# NibNab Export - \(title)\n"
        markdown += "Exported: \(formatter.string(from: Date()))\n\n"

        for clip in clipsToExport {
            markdown += "---\n"
            markdown += "### \(clip.appName)"
            if let url = clip.url {
                markdown += " | [\(url)](\(url))"
            }
            markdown += "\n"
            markdown += "*\(formatter.string(from: clip.timestamp))*\n\n"

            for imgPath in clip.imagePaths {
                let filename = (imgPath as NSString).lastPathComponent
                markdown += "![Screenshot](images/\(filename))\n\n"
            }

            markdown += "\(clip.text)\n\n"
        }

        presentExportPanel(defaultName: "\(stem)-clips.md", content: markdown) { [weak self] exportURL in
            guard let self = self else { return }
            let exportDir = exportURL.deletingLastPathComponent()
            let targetImagesDir = exportDir.appendingPathComponent("images", isDirectory: true)

            for clip in clipsToExport {
                guard !clip.imagePaths.isEmpty else { continue }
                for imgPath in clip.imagePaths {
                    for color in NibColor.all {
                        let srcURL = self.storageManager.imageURL(for: imgPath, in: color.name)
                        if FileManager.default.fileExists(atPath: srcURL.path) {
                            try? FileManager.default.createDirectory(at: targetImagesDir, withIntermediateDirectories: true)
                            let destURL = targetImagesDir.appendingPathComponent(srcURL.lastPathComponent)
                            if FileManager.default.fileExists(atPath: destURL.path) {
                                try? FileManager.default.removeItem(at: destURL)
                            }
                            try? FileManager.default.copyItem(at: srcURL, to: destURL)
                            break
                        }
                    }
                }
            }
        }
    }

    func exportAsPlainText(_ clipsToExport: [Clip], stem: String) {
        guard !clipsToExport.isEmpty else { return }
        let plainText = clipsToExport.map(\.text).joined(separator: "\n\n---\n\n")
        presentExportPanel(defaultName: "\(stem)-clips.txt", content: plainText)
    }

    func exportClipsAsMarkdown(for colorName: String) {
        exportAsMarkdown(clips[colorName] ?? [], title: colorName, stem: exportFileStem(for: colorName))
    }

    func exportClipsAsPlainText(for colorName: String) {
        exportAsPlainText(clips[colorName] ?? [], stem: exportFileStem(for: colorName))
    }

    /// Fold an arbitrary set — typically a tag's search results, which can span
    /// colours — into one clip in `targetColor`. Every colour it touches is
    /// snapshotted, so one ⌘Z puts them all back.
    func mergeClips(_ clipsToMerge: [Clip], into targetColor: String) {
        guard clipsToMerge.count > 1, let merged = clipsToMerge.mergedIntoOne() else { return }

        let ids = Set(clipsToMerge.map(\.id))
        let holders = clips.filter { $0.value.contains { ids.contains($0.id) } }.map(\.key)
        snapshotForUndo(Array(Set(holders + [targetColor])), what: "merge")

        var finalImagePaths: [String] = []
        for clip in clipsToMerge {
            let sourceColor = holders.first(where: { self.clips[$0]?.contains(where: { $0.id == clip.id }) == true }) ?? targetColor
            for path in clip.imagePaths {
                if sourceColor != targetColor {
                    if let newPath = storageManager.moveImage(at: path, from: sourceColor, to: targetColor) {
                        finalImagePaths.append(newPath)
                    } else {
                        finalImagePaths.append(path)
                    }
                } else {
                    finalImagePaths.append(path)
                }
            }
        }

        let updatedMerged = Clip(
            text: merged.text,
            timestamp: merged.timestamp,
            url: merged.url,
            appName: merged.appName,
            order: 0,
            id: merged.id,
            imagePaths: finalImagePaths
        )

        let touched = clips.removeClips(ids: ids).union([targetColor])
        clips[targetColor, default: []].insert(updatedMerged, at: 0)

        for name in touched {
            reindexOrders(for: name)
            storageManager.rewriteClips(clips[name] ?? [], for: name)
        }
        play(.capture)
        showToast("Merged \(clipsToMerge.count) clips", color: activeColor, undoable: true)
    }

    private func exportFileStem(for colorName: String) -> String {
        colorName.replacingOccurrences(of: "Highlighter ", with: "").lowercased()
    }

    private func presentExportPanel(defaultName: String, content: String, onSuccess: ((URL) -> Void)? = nil) {
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = defaultName
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true

        // Menubar apps aren't the active app, so the panel can land behind
        // other windows without this.
        NSApp.activate(ignoringOtherApps: true)

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                onSuccess?(url)
            } catch {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Export Failed"
                alert.informativeText = "Couldn't save to \(url.lastPathComponent): \(error.localizedDescription)"
                alert.runModal()
            }
        }
    }

    func showToast(_ message: String, color: NibColor, undoable: Bool = false) {
        toastUndoable = undoable
        if delegate?.popover.isShown == true {
            toastMessage = message
            toastColor = color

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
                // A newer toast may have replaced this one — leave it alone.
                guard self?.toastMessage == message else { return }
                self?.toastMessage = nil
                self?.toastColor = nil
                self?.toastUndoable = false
            }
        } else {
            toastMessage = nil
            toastColor = nil
            delegate?.pulseMenuBarIcon(color: color)
        }
    }
}

private enum ToastKind: Hashable {
    case color
    case monitoring
}

private struct ToastGate {
    private var suppressedKinds: Set<ToastKind> = []

    mutating func suppressNext(_ kind: ToastKind) {
        suppressedKinds.insert(kind)
    }

    mutating func shouldAllow(_ kind: ToastKind) -> Bool {
        if suppressedKinds.contains(kind) {
            suppressedKinds.remove(kind)
            return false
        }
        return true
    }
}
