import Cocoa
import SwiftUI
import ServiceManagement

@MainActor
class AppState: ObservableObject {
    @Published var viewedColor: NibColor = NibColor.yellow
    @Published var activeColor: NibColor {
        didSet {
            UserDefaults.standard.set(activeColor.name, forKey: "activeColorName")
            delegate?.updateMenubarIcon()
            playSound("Pop")
            if suppressNextColorToast {
                suppressNextColorToast = false
            } else {
                showToast(activeColor.name.replacingOccurrences(of: "Highlighter ", with: ""), color: activeColor)
            }
        }
    }
    @Published var launchAtLogin = false {
        didSet {
            if launchAtLogin {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }
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
                showToast("Capturing ON", color: NibColor.green)
            } else {
                stopClipboardMonitoring()
                showToast("Capturing OFF", color: NibColor.orange)
            }
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
    private var suppressNextColorToast = false
    private let storageManager = StorageManager()

    var autoCopyEnabled: Bool {
        UserDefaults.standard.bool(forKey: "autoCopyEnabled")
    }

    init() {
        suppressNextColorToast = true

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

    func startClipboardMonitoring() {
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

                    if let text = pasteboard.string(forType: .string),
                       !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if text != self.lastCapturedText {
                            self.lastCapturedText = text
                            let sourceApp = self.getCurrentAppName()
                            self.saveClip(text, to: self.activeColor, from: sourceApp)
                            self.delegate?.pulseMenubarIcon()
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

        if clips[color.name]!.count > 100 {
            clips[color.name] = Array(clips[color.name]!.prefix(100))
        }

        storageManager.saveClip(clip, to: color.name)
        playSound("Purr")
    }

    func playSound(_ name: String) {
        guard soundEffectsEnabled else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            NSSound(named: name)?.play()
        }
    }

    private func getCurrentURL() -> String? {
        return nil
    }

    func getCurrentAppName() -> String {
        return NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
    }

    func deleteClip(_ clip: Clip, from colorName: String) {
        clips[colorName]?.removeAll { $0.id == clip.id }
        storageManager.deleteClip(clip, from: colorName)
        playSound("Tink")
    }

    func clearAllClips(for colorName: String) {
        clips[colorName] = []
        storageManager.deleteAllClips(for: colorName)
        playSound("Basso")
    }

    func moveClip(_ clip: Clip, from sourceColor: String, to targetColor: String, at index: Int? = nil) {
        clips[sourceColor]?.removeAll { $0.id == clip.id }

        if clips[targetColor] == nil {
            clips[targetColor] = []
        }

        if let index = index, index < clips[targetColor]!.count {
            clips[targetColor]!.insert(clip, at: index)
        } else {
            clips[targetColor]!.append(clip)
        }

        storageManager.deleteClip(clip, from: sourceColor)
        storageManager.saveClip(clip, to: targetColor)
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
        guard activeColor.name != color.name || viewedColor.name != color.name else {
            return
        }

        if !announce {
            suppressNextColorToast = true
        }

        viewedColor = color
        activeColor = color
    }

    func reorderClip(_ clip: Clip, in colorName: String, to index: Int) {
        guard var colorClips = clips[colorName] else { return }
        colorClips.removeAll { $0.id == clip.id }
        colorClips.insert(clip, at: min(index, colorClips.count))
        clips[colorName] = colorClips
        storageManager.rewriteClips(colorClips, for: colorName)
    }

    func updateClip(_ clip: Clip, newText: String, in colorName: String) {
        guard let index = clips[colorName]?.firstIndex(where: { $0.id == clip.id }) else { return }

        clips[colorName]?[index] = Clip(
            text: newText,
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

        let savePanel = NSSavePanel()
        let shortName = colorName.replacingOccurrences(of: "Highlighter ", with: "").lowercased()
        savePanel.nameFieldStringValue = "\(shortName)-clips.md"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? markdown.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    func exportClipsAsPlainText(for colorName: String) {
        guard let colorClips = clips[colorName], !colorClips.isEmpty else { return }

        var plainText = ""

        for (index, clip) in colorClips.enumerated() {
            plainText += clip.text

            if index < colorClips.count - 1 {
                plainText += "\n\n---\n\n"
            }
        }

        let savePanel = NSSavePanel()
        let shortName = colorName.replacingOccurrences(of: "Highlighter ", with: "").lowercased()
        savePanel.nameFieldStringValue = "\(shortName)-clips.txt"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.canCreateDirectories = true

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? plainText.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    func showToast(_ message: String, color: NibColor) {
        if delegate?.popover.isShown == true {
            toastMessage = message
            toastColor = color

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
                self?.toastMessage = nil
                self?.toastColor = nil
            }
        } else if let delegate {
            toastMessage = nil
            toastColor = nil
            delegate.showStatusToast(message: message, color: color)
        } else {
            toastMessage = message
            toastColor = color
        }
    }
}
