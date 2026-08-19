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
            play(.switchColor, frequency: Weightless.scale[degree + 2])
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
    private var undoSnapshot: (colorName: String, clips: [Clip], what: String)?

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
    private let storageManager = StorageManager()

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
            url: nil, // browser URL capture needs per-browser scripting entitlements
            appName: sourceApp
        )

        if clips[color.name] == nil {
            clips[color.name] = []
        }
        invalidateUndo()
        clips[color.name]?.insert(clip, at: 0)

        if var colorClips = clips[color.name], colorClips.count > Self.maxClipsPerColor {
            colorClips = Array(colorClips.prefix(Self.maxClipsPerColor))
            clips[color.name] = colorClips
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

    func play(_ sound: NibSound, frequency: Float? = nil) {
        guard soundEffectsEnabled else { return }
        WeightlessPlayer.shared.play(cue: sound.cue, frequency: frequency)
    }

    func getCurrentAppName() -> String {
        return NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
    }

    private func snapshotForUndo(_ colorName: String, what: String) {
        undoSnapshot = (colorName, clips[colorName] ?? [], what)
        canUndo = true
    }

    private func invalidateUndo() {
        undoSnapshot = nil
        canUndo = false
        toastUndoable = false
    }

    func undoLast() {
        guard let snapshot = undoSnapshot else { return }
        clips[snapshot.colorName] = snapshot.clips
        storageManager.rewriteClips(snapshot.clips, for: snapshot.colorName)
        undoSnapshot = nil
        canUndo = false
        play(.open)
        showToast("Undid \(snapshot.what)", color: activeColor)
    }

    func deleteClip(_ clip: Clip, from colorName: String) {
        snapshotForUndo(colorName, what: "delete")
        clips[colorName]?.removeAll { $0.id == clip.id }
        storageManager.rewriteClips(clips[colorName] ?? [], for: colorName)
        play(.delete)
        showToast("Clip deleted", color: activeColor, undoable: true)
    }

    func clearAllClips(for colorName: String) {
        snapshotForUndo(colorName, what: "clear all")
        let clearedCount = undoSnapshot?.clips.count ?? 0
        clips[colorName] = []
        storageManager.deleteAllClips(for: colorName)
        play(.delete)
        showToast("Cleared \(clearedCount) clips", color: activeColor, undoable: true)
    }

    func moveClip(_ clip: Clip, from sourceColor: String, to targetColor: String) {
        invalidateUndo()
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
        play(.switchColor)
    }

    func reorderClip(_ clip: Clip, in colorName: String, to targetIndex: Int) {
        invalidateUndo()
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

        snapshotForUndo(colorName, what: "merge all")

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
        ) { [weak self] in
            self?.clearAllClips(for: colorName)
        }
    }

    func mergeClip(_ source: Clip, into target: Clip, in colorName: String) {
        snapshotForUndo(colorName, what: "merge")
        guard var colorClips = clips[colorName],
              let targetIndex = colorClips.firstIndex(of: target) else { return }

        let mergedText = target.text + "\n" + source.text
        let merged = Clip(
            text: mergedText,
            timestamp: Date(),
            url: target.url ?? source.url,
            appName: target.appName,
            order: target.order,
            id: target.id
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
            id: clip.id
        )

        if let colorClips = clips[colorName] {
            storageManager.rewriteClips(colorClips, for: colorName)
        }

        play(.capture)
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

    private func presentExportPanel(defaultName: String, content: String, onSuccess: (() -> Void)? = nil) {
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
                onSuccess?()
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
