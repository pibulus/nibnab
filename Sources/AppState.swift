import Cocoa
import SwiftUI
import ServiceManagement

@MainActor
class AppState: ObservableObject {
    private static let maxClipsPerColor = 100

    @Published var viewedColor: NibColor = NibColor.yellow
    @Published var activeColor: NibColor {
        didSet {
            UserDefaults.standard.set(activeColor.name, forKey: "activeColorName")
            delegate?.updateMenubarIcon()
            playSound("Pop")
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
        }
    }
    @Published var clips: [String: [Clip]] = [:]
    @Published var colorLabels: [String: String] = [:] {
        didSet {
            UserDefaults.standard.set(colorLabels, forKey: "colorLabels")
        }
    }
    @Published var showWelcome: Bool = false
    @Published var toastMessage: String? = nil
    @Published var toastColor: NibColor? = nil

    weak var delegate: AppDelegate?
    private var clipboardTimer: Timer?
    private var lastChangeCount: Int = 0
    var lastCapturedText: String? = nil
    var suppressNextClipboardCapture = false
    private var toastGate = ToastGate()
    private let storageManager = StorageManager()
    private var popSound: NSSound?

    @Published var selectionCaptureEnabled: Bool {
        didSet {
            UserDefaults.standard.set(selectionCaptureEnabled, forKey: "autoCopyEnabled")
            delegate?.syncSelectionMonitoring()
        }
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

        soundEffectsEnabled = UserDefaults.standard.object(forKey: "soundEffectsEnabled") as? Bool ?? true
        isMonitoring = UserDefaults.standard.object(forKey: "isMonitoring") as? Bool ?? true
        selectionCaptureEnabled = UserDefaults.standard.object(forKey: "autoCopyEnabled") as? Bool ?? true
        viewedColor = initialColor

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
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
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

    func startClipboardMonitoring() {
        clipboardTimer?.invalidate()
        lastChangeCount = NSPasteboard.general.changeCount

        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                let pasteboard = NSPasteboard.general

                if pasteboard.changeCount != self.lastChangeCount {
                    self.lastChangeCount = pasteboard.changeCount

                    if self.suppressNextClipboardCapture {
                        self.suppressNextClipboardCapture = false
                        return
                    }

                    let types = pasteboard.types ?? []
                    if Self.skippedPasteboardTypes.contains(where: types.contains) {
                        return
                    }

                    if let text = pasteboard.string(forType: .string),
                       !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if text != self.lastCapturedText {
                            self.lastCapturedText = text
                            let sourceApp = self.getCurrentAppName()
                            self.saveClip(text, to: self.activeColor, from: sourceApp)
                            self.delegate?.pulseMenuBarIcon()
                        }
                    }
                }
            }
        }
        RunLoop.main.add(clipboardTimer!, forMode: .common)
    }

    func stopClipboardMonitoring() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
    }

    func saveClip(_ text: String, to color: NibColor, from sourceApp: String) {
        // Trim on save so what's persisted round-trips identically
        // (the storage parser trims section text on load).
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Re-capturing the newest clip again would just create a duplicate.
        if clips[color.name]?.first?.text == text { return }

        let clip = Clip(
            text: text,
            timestamp: Date(),
            url: getCurrentURL(),
            appName: sourceApp
        )

        if clips[color.name] == nil {
            clips[color.name] = []
        }
        clips[color.name]?.insert(clip, at: 0)

        if clips[color.name]!.count > Self.maxClipsPerColor {
            clips[color.name] = Array(clips[color.name]!.prefix(Self.maxClipsPerColor))
        }

        if let colorClips = clips[color.name] {
            storageManager.rewriteClips(colorClips, for: color.name)
        }
        playSound("Purr")
    }

    func playSound(_ name: String) {
        guard soundEffectsEnabled else { return }
        if name == "Pop" {
            if popSound == nil { popSound = NSSound(named: "Pop") }
            popSound?.stop()
            popSound?.play()
        } else {
            NSSound(named: name)?.play()
        }
    }

    private func getCurrentURL() -> String? {
        // Browser URL extraction requires scripting-targets entitlement per browser bundle ID.
        // Deferred until specific browser support is added.
        return nil
    }

    func getCurrentAppName() -> String {
        return NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
    }

    func deleteClip(_ clip: Clip, from colorName: String) {
        clips[colorName]?.removeAll { $0.id == clip.id }
        storageManager.rewriteClips(clips[colorName] ?? [], for: colorName)
        playSound("Tink")
    }

    func clearAllClips(for colorName: String) {
        clips[colorName] = []
        storageManager.deleteAllClips(for: colorName)
        playSound("Basso")
    }

    func moveClip(_ clip: Clip, from sourceColor: String, to targetColor: String) {
        clips[sourceColor]?.removeAll { $0.id == clip.id }

        var targetClips = clips[targetColor] ?? []
        // Insert preserving newest-first order so the cap below always trims
        // the oldest clip — never the clip the user just moved.
        let insertionIndex = targetClips.firstIndex { $0.timestamp <= clip.timestamp } ?? targetClips.count
        targetClips.insert(clip, at: insertionIndex)

        if targetClips.count > Self.maxClipsPerColor,
           let dropIndex = targetClips.indices.reversed().first(where: { targetClips[$0].id != clip.id }) {
            targetClips.remove(at: dropIndex)
        }
        clips[targetColor] = targetClips

        storageManager.rewriteClips(clips[sourceColor] ?? [], for: sourceColor)
        storageManager.rewriteClips(targetClips, for: targetColor)
        playSound("Pop")
    }

    func copyToPasteboard(_ text: String) {
        suppressNextClipboardCapture = true
        lastCapturedText = text
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func switchToColor(_ color: NibColor, announce: Bool = true) {
        let alreadyActive = activeColor.name == color.name
        guard !alreadyActive || viewedColor.name != color.name else {
            return
        }

        viewedColor = color

        // Only reassign activeColor when it actually changes — its didSet
        // fires the toast, sound, and menubar redraw.
        if !alreadyActive {
            if !announce {
                toastGate.suppressNext(.color)
            }
            activeColor = color
        }
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

        clips[colorName]?[index] = Clip(
            text: trimmedText,
            timestamp: clip.timestamp,
            url: clip.url,
            appName: clip.appName,
            screenshotPath: clip.screenshotPath,
            id: clip.id
        )

        if let colorClips = clips[colorName] {
            storageManager.rewriteClips(colorClips, for: colorName)
        }

        playSound("Pop")
    }

    func exportClipsAsMarkdown(for colorName: String) {
        guard let colorClips = clips[colorName], !colorClips.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"

        var markdown = "# NibNab Export - \(colorName)\n"
        markdown += "Exported: \(formatter.string(from: Date()))\n\n"

        for clip in colorClips {
            markdown += "---\n"
            markdown += "### \(clip.appName)\n"
            markdown += "*\(formatter.string(from: clip.timestamp))*\n\n"
            markdown += "\(clip.text)\n\n"
        }

        presentExportPanel(defaultName: "\(exportFileStem(for: colorName))-clips.md", content: markdown)
    }

    func exportClipsAsPlainText(for colorName: String) {
        guard let colorClips = clips[colorName], !colorClips.isEmpty else { return }

        let plainText = colorClips.map(\.text).joined(separator: "\n\n---\n\n")
        presentExportPanel(defaultName: "\(exportFileStem(for: colorName))-clips.txt", content: plainText)
    }

    private func exportFileStem(for colorName: String) -> String {
        colorName.replacingOccurrences(of: "Highlighter ", with: "").lowercased()
    }

    private func presentExportPanel(defaultName: String, content: String) {
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
            } catch {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Export Failed"
                alert.informativeText = "Couldn't save to \(url.lastPathComponent): \(error.localizedDescription)"
                alert.runModal()
            }
        }
    }

    func showToast(_ message: String, color: NibColor) {
        if delegate?.popover.isShown == true {
            toastMessage = message
            toastColor = color

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
                // A newer toast may have replaced this one — leave it alone.
                guard self?.toastMessage == message else { return }
                self?.toastMessage = nil
                self?.toastColor = nil
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
