import Cocoa
import SwiftUI
import ApplicationServices
import ServiceManagement
import Carbon.HIToolbox

// ===================================================================
// NIBNAB - Color-coded clipboard collector
// Your clipboard deserves better
// ===================================================================

// MARK: - Color Theme
struct NibColor {
    let name: String
    let hex: String
    let nsColor: NSColor

    static let yellow = NibColor(
        name: "Highlighter Yellow",
        hex: "#FFEB3B",
        nsColor: NSColor(red: 1.0, green: 0.922, blue: 0.231, alpha: 1.0)
    )

    static let orange = NibColor(
        name: "Highlighter Orange",
        hex: "#f68717",
        nsColor: NSColor(red: 0.965, green: 0.529, blue: 0.090, alpha: 1.0)
    )

    static let pink = NibColor(
        name: "Highlighter Pink",
        hex: "#f60474",
        nsColor: NSColor(red: 0.965, green: 0.016, blue: 0.455, alpha: 1.0)
    )

    static let purple = NibColor(
        name: "Highlighter Purple",
        hex: "#8717f6",
        nsColor: NSColor(red: 0.529, green: 0.090, blue: 0.965, alpha: 1.0)
    )

    static let all = [yellow, orange, pink, purple]
}

// MARK: - Gradient Colors
struct NibGradients {
    static let yellow = LinearGradient(
        colors: [Color(red: 1.0, green: 0.922, blue: 0.231), Color(red: 0.95, green: 0.872, blue: 0.181)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let orange = LinearGradient(
        colors: [Color(red: 0.965, green: 0.529, blue: 0.090), Color(red: 0.915, green: 0.479, blue: 0.040)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pink = LinearGradient(
        colors: [Color(red: 0.965, green: 0.016, blue: 0.455), Color(red: 0.915, green: 0.0, blue: 0.405)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let purple = LinearGradient(
        colors: [Color(red: 0.529, green: 0.090, blue: 0.965), Color(red: 0.479, green: 0.040, blue: 0.915)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Main App
@main
struct NibNabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var appState: AppState!
    var eventMonitor: EventMonitor?
    var autoCopyMonitor: AutoCopyMonitor?
    private var hotKeyRefs: [EventHotKeyRef?] = Array(repeating: nil, count: 5)

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Create status item first
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(handleMenubarClick(_:))
        }

        // Create app state and set delegate
        appState = AppState()
        appState.delegate = self

        // Update icon now that delegate is set
        updateMenubarIcon()

        // Setup popover
        let contentView = ContentView()
            .environmentObject(appState)

        popover.contentSize = NSSize(width: 480, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)

        // Setup event monitor
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strongSelf = self, strongSelf.popover.isShown {
                strongSelf.closePopover()
            }
        }

        // Initialize auto-copy monitor
        autoCopyMonitor = AutoCopyMonitor { [weak self] selectedText in
            guard let self = self else { return }
            let sourceApp = self.appState.getCurrentAppName()
            // Auto-save to active color instead of showing picker
            self.appState.saveClip(selectedText, to: self.appState.activeColor, from: sourceApp)
            self.pulseMenubarIcon()
        }

        // Start clipboard monitoring if enabled (for Cmd+C)
        if appState.isMonitoring {
            appState.startClipboardMonitoring()
        }

        // Start auto-copy monitor (for text selection)
        autoCopyMonitor?.start()

        // Register global keyboard shortcut (Cmd+Shift+V)
        registerGlobalShortcut()
    }

    func registerGlobalShortcut() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let signature = OSType(0x4E42_4E42) // 'NBNB'

        // Register Cmd+Shift+V (Toggle window)
        let toggleID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            toggleID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefs[0]
        )

        // Register Cmd+Ctrl+1 (Yellow)
        let yellowID = EventHotKeyID(signature: signature, id: 2)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_1),
            UInt32(cmdKey | controlKey),
            yellowID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefs[1]
        )

        // Register Cmd+Ctrl+2 (Orange)
        let orangeID = EventHotKeyID(signature: signature, id: 3)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_2),
            UInt32(cmdKey | controlKey),
            orangeID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefs[2]
        )

        // Register Cmd+Ctrl+3 (Pink)
        let pinkID = EventHotKeyID(signature: signature, id: 4)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_3),
            UInt32(cmdKey | controlKey),
            pinkID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefs[3]
        )

        // Register Cmd+Ctrl+4 (Purple)
        let purpleID = EventHotKeyID(signature: signature, id: 5)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_4),
            UInt32(cmdKey | controlKey),
            purpleID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefs[4]
        )

        // Install event handler
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, inEvent, userData) -> OSStatus in
                if userData != nil {
                    var hotKeyID = EventHotKeyID()
                    GetEventParameter(
                        inEvent,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotKeyID
                    )

                    let selfPointer = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
                    DispatchQueue.main.async {
                        switch hotKeyID.id {
                        case 1: // Cmd+Shift+V - Toggle
                            selfPointer.togglePopover()
                        case 2: // Cmd+Ctrl+1 - Yellow
                            selfPointer.appState.activeColor = NibColor.yellow
                        case 3: // Cmd+Ctrl+2 - Orange
                            selfPointer.appState.activeColor = NibColor.orange
                        case 4: // Cmd+Ctrl+3 - Pink
                            selfPointer.appState.activeColor = NibColor.pink
                        case 5: // Cmd+Ctrl+4 - Purple
                            selfPointer.appState.activeColor = NibColor.purple
                        default:
                            break
                        }
                    }
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )
    }

    @objc func handleMenubarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showColorMenu()
        } else {
            togglePopover()
        }
    }

    @objc func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func updateMenubarIcon() {
        guard let button = statusItem.button else { return }

        // Create icon with colored dot
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)

        image.lockFocus()

        // Draw highlighter icon in white
        if let highlighter = NSImage(systemSymbolName: "highlighter", accessibilityDescription: "NibNab") {
            NSColor.white.setFill()
            let iconRect = NSRect(x: 0, y: 0, width: 22, height: 22)

            // Tint the icon white
            highlighter.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            NSColor.white.set()
            iconRect.fill(using: .sourceAtop)
        }

        // Draw colored dot in bottom right
        let dotRect = NSRect(x: 14, y: 2, width: 8, height: 8)
        let dotPath = NSBezierPath(ovalIn: dotRect)
        appState.activeColor.nsColor.setFill()
        dotPath.fill()

        // White outline for visibility
        NSColor.white.setStroke()
        dotPath.lineWidth = 1.5
        dotPath.stroke()

        image.unlockFocus()
        image.isTemplate = false

        button.image = image
    }

    func showColorMenu() {
        let menu = NSMenu()

        // Color selection items
        for color in NibColor.all {
            // Create colored circle image
            let size = NSSize(width: 16, height: 16)
            let image = NSImage(size: size)
            image.lockFocus()

            let circle = NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 12, height: 12))
            color.nsColor.setFill()
            circle.fill()

            NSColor.white.setStroke()
            circle.lineWidth = 1
            circle.stroke()

            image.unlockFocus()

            let shortName = color.name.replacingOccurrences(of: "Highlighter ", with: "")
            let item = NSMenuItem(
                title: shortName,
                action: #selector(selectColor(_:)),
                keyEquivalent: ""
            )
            item.image = image
            item.representedObject = color
            item.state = appState.activeColor.name == color.name ? .on : .off
            menu.addItem(item)
        }

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Launch at Login toggle
        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.state = appState.launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        // Sound Effects toggle
        let soundItem = NSMenuItem(
            title: "Sound Effects",
            action: #selector(toggleSoundEffects),
            keyEquivalent: ""
        )
        soundItem.state = appState.soundEffectsEnabled ? .on : .off
        menu.addItem(soundItem)

        // About
        let aboutItem = NSMenuItem(
            title: "About NibNab...",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        menu.addItem(aboutItem)

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit NibNab",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func selectColor(_ sender: NSMenuItem) {
        if let color = sender.representedObject as? NibColor {
            appState.activeColor = color
        }
    }

    @objc func toggleLaunchAtLogin() {
        appState.launchAtLogin.toggle()
    }

    @objc func toggleSoundEffects() {
        appState.soundEffectsEnabled.toggle()
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About NibNab"
        alert.informativeText = """
        A highlighter for your digital life 🎨

        Hey, I'm Pablo. I build tools with personality.

        NibNab captures everything you copy and organizes it by color—because your clipboard deserves better than Cmd+V into Notes.app.

        Auto-capture, export options, zero cloud BS. It's quick, it's local, it works forever.

        Check out more of my work:
        🌐 github.com/pibulus

        Version 1.0 • Made in Bangkok ☕
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            eventMonitor?.start()
        }
    }

    func closePopover() {
        popover.performClose(nil)
        eventMonitor?.stop()
    }

    func pulseMenubarIcon() {
        guard let button = statusItem.button else { return }

        // Create a colored overlay effect
        let overlay = NSView(frame: button.bounds)
        overlay.wantsLayer = true
        overlay.layer?.backgroundColor = appState.activeColor.nsColor.cgColor
        overlay.layer?.cornerRadius = button.bounds.width / 2
        overlay.alphaValue = 0
        button.addSubview(overlay)

        // Animate: color flash + fade
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            overlay.animator().alphaValue = 0.6
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3
                overlay.animator().alphaValue = 0
            }, completionHandler: {
                overlay.removeFromSuperview()
            })
        })
    }

}

// MARK: - Event Monitor
class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

// MARK: - AXUIElement Extension
extension AXUIElement {
    static var focusedElement: AXUIElement? {
        systemWide.element(for: kAXFocusedUIElementAttribute)
    }

    var selectedText: String? {
        rawValue(for: kAXSelectedTextAttribute) as? String
    }

    private static var systemWide = AXUIElementCreateSystemWide()

    private func element(for attribute: String) -> AXUIElement? {
        guard let rawValue = rawValue(for: attribute),
              CFGetTypeID(rawValue) == AXUIElementGetTypeID() else { return nil }
        // Safe to force cast - we've verified the CFTypeID above
        return (rawValue as! AXUIElement)
    }

    private func rawValue(for attribute: String) -> AnyObject? {
        var rawValue: AnyObject?
        let error = AXUIElementCopyAttributeValue(self, attribute as CFString, &rawValue)
        return error == .success ? rawValue : nil
    }
}

// MARK: - Auto Copy Monitor
class AutoCopyMonitor {
    private var timer: Timer?
    private var lastSelectedText: String?
    private let selectionHandler: (String) -> Void

    init(onTextSelected: @escaping (String) -> Void) {
        self.selectionHandler = onTextSelected
    }

    deinit {
        stop()
    }

    func start() {
        // Use the system prompt which includes "Open System Settings" button
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        guard isTrusted else {
            print("🔴 NibNab: Showing system accessibility prompt...")
            // System dialog shown - poll for permission grant
            pollForAccessibilityPermission()
            return
        }

        print("🟢 NibNab: Accessibility trusted! Starting monitor...")

        // Check for selected text every 0.5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForSelectedText()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastSelectedText = nil
    }

    private func checkForSelectedText() {
        guard let selectedText = AXUIElement.focusedElement?.selectedText,
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              selectedText != lastSelectedText else { return }

        lastSelectedText = selectedText

        // Copy to clipboard and trigger our handler
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedText, forType: .string)

        selectionHandler(selectedText)
    }

    private func pollForAccessibilityPermission() {
        var pollCount = 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            pollCount += 1
            print("🔵 Poll #\(pollCount): Checking accessibility...")

            if AXIsProcessTrusted() {
                timer.invalidate()
                print("✅ NibNab: Accessibility permissions granted after \(pollCount) checks!")
                self?.start() // Try to start again now that we have permission
            } else if pollCount > 120 { // Stop after 2 minutes
                timer.invalidate()
                print("❌ NibNab: Gave up polling after 2 minutes")
            }
        }
    }
}


// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var viewedColor: NibColor = NibColor.yellow
    @Published var activeColor: NibColor {
        didSet {
            // Persist active color
            UserDefaults.standard.set(activeColor.name, forKey: "activeColorName")
            // Update menubar icon
            delegate?.updateMenubarIcon()
            // Play soft sound feedback (create new instance each time for overlapping playback)
            if soundEffectsEnabled, let sound = NSSound(named: "Pop") {
                sound.play()
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
            } else {
                stopClipboardMonitoring()
            }
        }
    }
    @Published var clips: [String: [Clip]] = [:]

    weak var delegate: AppDelegate?
    private var clipboardTimer: Timer?
    private var lastChangeCount: Int = 0
    private let storageManager = StorageManager()

    init() {
        // Load persisted active color
        if let savedColorName = UserDefaults.standard.string(forKey: "activeColorName"),
           let savedColor = NibColor.all.first(where: { $0.name == savedColorName }) {
            activeColor = savedColor
        } else {
            activeColor = NibColor.yellow
        }

        // Load sound effects preference (default: enabled)
        soundEffectsEnabled = UserDefaults.standard.object(forKey: "soundEffectsEnabled") as? Bool ?? true

        // Load monitoring state (default: enabled)
        isMonitoring = UserDefaults.standard.object(forKey: "isMonitoring") as? Bool ?? true

        // Initialize clips for each color
        for color in NibColor.all {
            clips[color.name] = storageManager.loadClips(for: color.name)
        }

        // Check current launch at login status
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func startClipboardMonitoring() {
        let pasteboard = NSPasteboard.general
        lastChangeCount = pasteboard.changeCount

        // Monitor clipboard changes every 0.5 seconds
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if pasteboard.changeCount != self.lastChangeCount {
                    self.lastChangeCount = pasteboard.changeCount

                    // Get clipboard text
                    if let text = pasteboard.string(forType: .string),
                       !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Save to active color
                        let sourceApp = self.getCurrentAppName()
                        self.saveClip(text, to: self.activeColor, from: sourceApp)
                        self.delegate?.pulseMenubarIcon()
                    }
                }
            }
        }
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

        // Limit to 100 clips per color
        if clips[color.name]!.count > 100 {
            clips[color.name] = Array(clips[color.name]!.prefix(100))
        }

        storageManager.saveClip(clip, to: color.name)

        // Play clip capture sound
        if soundEffectsEnabled, let sound = NSSound(named: "Pop") {
            sound.play()
        }
    }

    private func getCurrentURL() -> String? {
        // TODO: Implement AppleScript to get browser URL
        return nil
    }

    func getCurrentAppName() -> String {
        return NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
    }

    func deleteClip(_ clip: Clip, from colorName: String) {
        clips[colorName]?.removeAll { $0.id == clip.id }
        // TODO: Also delete from markdown file

        // Play clip delete sound
        if soundEffectsEnabled, let sound = NSSound(named: "Tink") {
            sound.play()
        }
    }

    func exportClipsAsMarkdown(for colorName: String) {
        guard let colorClips = clips[colorName], !colorClips.isEmpty else { return }

        // Format as markdown with metadata
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

        // Save with file picker
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

        // Format as plain text - just clips with separators
        var plainText = ""

        for (index, clip) in colorClips.enumerated() {
            plainText += clip.text

            // Add separator unless it's the last clip
            if index < colorClips.count - 1 {
                plainText += "\n\n---\n\n"
            }
        }

        // Save with file picker
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
}

// MARK: - Clip Model
struct Clip: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let url: String?
    let appName: String
    var screenshotPath: String?

    init(text: String, timestamp: Date, url: String?, appName: String, screenshotPath: String? = nil) {
        self.id = UUID()
        self.text = text
        self.timestamp = timestamp
        self.url = url
        self.appName = appName
        self.screenshotPath = screenshotPath
    }
}

// MARK: - Storage Manager
class StorageManager {
    private let baseURL: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        baseURL = home.appendingPathComponent(".nibnab")

        // Create directories
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

        for color in NibColor.all {
            let colorDir = baseURL.appendingPathComponent(color.name.lowercased())
            try? FileManager.default.createDirectory(at: colorDir, withIntermediateDirectories: true)
        }
    }

    func saveClip(_ clip: Clip, to colorName: String) {
        let colorDir = baseURL.appendingPathComponent(colorName.lowercased())
        let fileName = "\(colorName.lowercased())_clips.md"
        let fileURL = colorDir.appendingPathComponent(fileName)

        // Format as markdown
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        var markdown = "\n---\n"
        markdown += "### \(clip.appName)"
        if let url = clip.url {
            markdown += " | [\(url)](\(url))"
        }
        markdown += "\n"
        markdown += "\(formatter.string(from: clip.timestamp)) Bangkok\n\n"
        markdown += "\(clip.text)\n"

        // Append to file
        if let data = markdown.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
    }

    func loadClips(for colorName: String) -> [Clip] {
        let colorDir = baseURL.appendingPathComponent(colorName.lowercased())
        let fileName = "\(colorName.lowercased())_clips.md"
        let fileURL = colorDir.appendingPathComponent(fileName)

        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }

        var clips: [Clip] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        // Split by "---" separator to get individual clip sections
        let sections = content.components(separatedBy: "\n---\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for section in sections {
            let lines = section.components(separatedBy: "\n")
            guard lines.count >= 3 else { continue }

            var appName = ""
            var url: String? = nil
            var timestamp = Date()
            var text = ""

            var lineIndex = 0

            // Parse header line (### AppName | [url](url))
            for (index, line) in lines.enumerated() {
                if line.hasPrefix("###") {
                    lineIndex = index
                    let headerContent = line.replacingOccurrences(of: "###", with: "").trimmingCharacters(in: .whitespaces)

                    // Check for URL in format: AppName | [url](url)
                    if headerContent.contains("|") {
                        let parts = headerContent.components(separatedBy: "|")
                        appName = parts[0].trimmingCharacters(in: .whitespaces)

                        // Extract URL from markdown link [text](url)
                        if let urlPart = parts.last,
                           let urlStart = urlPart.range(of: "](")?.upperBound,
                           let urlEnd = urlPart.range(of: ")", range: urlStart..<urlPart.endIndex)?.lowerBound {
                            url = String(urlPart[urlStart..<urlEnd])
                        }
                    } else {
                        appName = headerContent
                    }
                    break
                }
            }

            // Parse timestamp line (next line after header)
            if lineIndex + 1 < lines.count {
                let timestampLine = lines[lineIndex + 1].trimmingCharacters(in: .whitespaces)
                // Remove " Bangkok" suffix if present
                let dateString = timestampLine.replacingOccurrences(of: " Bangkok", with: "")
                if let parsedDate = formatter.date(from: dateString) {
                    timestamp = parsedDate
                }
            }

            // Parse text content (everything after empty line following timestamp)
            if lineIndex + 2 < lines.count {
                let textLines = Array(lines[(lineIndex + 2)...])
                text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Create clip if we have valid data
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

        // Sort by timestamp descending (newest first)
        return clips.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Custom Toggle Style
struct NibToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ?
                    LinearGradient(
                        colors: [Color.white,
                                Color.white.opacity(0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 40, height: 24)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .offset(x: configuration.isOn ? 8 : -8)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedClip: Clip?
    @State private var sortOrder: SortOrder = .newestFirst
    @State private var searchText = ""
    @State private var sortHovered = false
    @State private var exportHovered = false
    @State private var toggleHovered = false
    @FocusState private var searchFocused: Bool

    enum SortOrder {
        case newestFirst, oldestFirst, byAppName, byLength
    }

    var sortedClips: [Clip] {
        guard let clips = appState.clips[appState.viewedColor.name] else { return [] }

        // Filter by search first
        let filteredClips = searchText.isEmpty ? clips : clips.filter {
            $0.text.localizedCaseInsensitiveContains(searchText) ||
            $0.appName.localizedCaseInsensitiveContains(searchText)
        }

        // Then sort
        switch sortOrder {
        case .newestFirst:
            return filteredClips.sorted { $0.timestamp > $1.timestamp }
        case .oldestFirst:
            return filteredClips.sorted { $0.timestamp < $1.timestamp }
        case .byAppName:
            return filteredClips.sorted { $0.appName < $1.appName }
        case .byLength:
            return filteredClips.sorted { $0.text.count > $1.text.count }
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .center, spacing: 16) {
                    // Left: Title
                    HStack(spacing: 10) {
                        Image(systemName: "highlighter")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(appState.activeColor.nsColor))
                        Text("NibNab")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(Color(appState.activeColor.nsColor))
                            .fixedSize()
                    }

                    Spacer()

                    // Center: Search field
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))

                        TextField("Search clips...", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .frame(width: 110)
                            .focused($searchFocused)
                            .onAppear {
                                // Prevent auto-focus on appear
                                searchFocused = false
                            }

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)

                    Spacer()

                    HStack(alignment: .center, spacing: 12) {
                        // Sort and Export buttons with hover effects
                        HStack(spacing: 16) {
                            Menu {
                                Button("Newest First") { sortOrder = .newestFirst }
                                Button("Oldest First") { sortOrder = .oldestFirst }
                                Button("By App Name") { sortOrder = .byAppName }
                                Button("By Length") { sortOrder = .byLength }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(sortHovered ? 1.0 : 0.7))
                                    .scaleEffect(sortHovered ? 1.2 : 1.0)
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .help("Sort clips")
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    sortHovered = hovering
                                }
                            }

                            Menu {
                                Button("Export as Markdown...") {
                                    appState.exportClipsAsMarkdown(for: appState.activeColor.name)
                                }
                                Button("Export as Plain Text...") {
                                    appState.exportClipsAsPlainText(for: appState.activeColor.name)
                                }
                            } label: {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(exportHovered ? 1.0 : 0.7))
                                    .scaleEffect(exportHovered ? 1.2 : 1.0)
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .help("Export clips")
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    exportHovered = hovering
                                }
                            }
                        }

                        Divider()
                            .frame(height: 16)
                            .opacity(0.3)

                        // Active/Inactive Toggle
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(toggleHovered ? 0.2 : 0.0))
                                .frame(width: 52, height: 32)

                            Toggle("", isOn: $appState.isMonitoring)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .scaleEffect(toggleHovered ? 0.75 : 0.7)
                                .help(appState.isMonitoring ? "Monitoring active - Click to pause" : "Monitoring paused - Click to activate")
                        }
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                toggleHovered = hovering
                            }
                        }
                    }
                }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.9), Color.black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Divider()

            // Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if !sortedClips.isEmpty {
                        ForEach(sortedClips) { clip in
                            ClipView(clip: clip)
                                .onTapGesture {
                                    selectedClip = clip
                                }
                                .contextMenu {
                                    Button(action: {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(clip.text, forType: .string)
                                    }) {
                                        Label("Copy", systemImage: "doc.on.clipboard")
                                    }

                                    Button(action: {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            appState.deleteClip(clip, from: appState.viewedColor.name)
                                        }
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 64, weight: .light))
                                .foregroundColor(Color.white.opacity(0.3))

                            VStack(spacing: 8) {
                                Text("Nothing nabbed yet")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.8))
                                Text("Copy something good")
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.5))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .padding(.top, 40)
                    }
                }
                .padding(12)
            }
            .frame(height: 280)

            // Footer
            ZStack {
                let activeShortName = appState.activeColor.name.replacingOccurrences(of: "Highlighter ", with: "")
                let viewedClipCount = appState.clips[appState.viewedColor.name]?.count ?? 0

                // Side labels (don't affect center positioning)
                HStack {
                    Text("Active: \(activeShortName)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(appState.activeColor.nsColor))

                    Spacer()

                    Text("\(viewedClipCount) clips")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(appState.activeColor.nsColor))
                }

                // Color selector - absolutely centered
                HStack(spacing: 8) {
                    ForEach(NibColor.all, id: \.name) { color in
                        Button(action: {
                            appState.viewedColor = color
                            appState.activeColor = color
                        }) {
                            Circle()
                                .fill(Color(color.nsColor))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: appState.activeColor.name == color.name ? 3 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                        .help("Switch to \(color.name)")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.6), Color.black.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .background(
            ZStack {
                Color.black.opacity(0.85)
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.063, blue: 0.941).opacity(0.05),
                        Color(red: 0, green: 0.831, blue: 1.0).opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )

            // Detail view overlay (replaces .sheet which doesn't work in popovers)
            if let clip = selectedClip {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            selectedClip = nil
                        }
                    }

                ClipDetailView(clip: clip) {
                    withAnimation {
                        selectedClip = nil
                    }
                }
                .environmentObject(appState)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
}

// MARK: - Color Tab Component
struct ColorTab: View {
    let color: NibColor
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(color.nsColor))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 4 : (isHovered ? 2 : 0))
                )
                .overlay(
                    // Selected indicator - inner ring
                    Circle()
                        .stroke(Color.black.opacity(0.2), lineWidth: isSelected ? 2 : 0)
                        .frame(width: 24, height: 24)
                )
                .scaleEffect(isHovered ? 1.15 : (isSelected ? 1.1 : 1.0))
                .shadow(color: isSelected ? Color.black.opacity(0.3) : (isHovered ? Color.black.opacity(0.1) : Color.clear), radius: isSelected ? 4 : 2, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Clip View Component
struct ClipView: View {
    let clip: Clip
    @EnvironmentObject var appState: AppState
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(clip.appName)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.659, green: 0.855, blue: 0.863))

                Spacer()

                // Timestamp with padding to avoid overlap with hover buttons
                Text(timeAgo(from: clip.timestamp))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
                    .padding(.trailing, isHovered ? 50 : 0) // Make room for buttons when hovered
            }

            Text(clip.text.prefix(150) + (clip.text.count > 150 ? "..." : ""))
                .font(.system(size: 12))
                .lineLimit(3)
                .foregroundColor(Color.white.opacity(0.9))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: isHovered ?
                            [Color.white.opacity(0.15), Color.white.opacity(0.1)] :
                            [Color.white.opacity(0.08), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.71, blue: 0.655).opacity(0.2),
                                Color(red: 0.659, green: 0.855, blue: 0.863).opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(
            Group {
                if isHovered {
                    HStack(spacing: 6) {
                        // Copy button
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(clip.text, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)

                        // Delete button
                        Button(action: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                appState.deleteClip(clip, from: appState.viewedColor.name)
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(6)
                }
            },
            alignment: .topTrailing
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval/60))m ago" }
        if interval < 86400 { return "\(Int(interval/3600))h ago" }
        return "\(Int(interval/86400))d ago"
    }
}

// MARK: - Clip Detail View
struct ClipDetailView: View {
    let clip: Clip
    let onDismiss: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var copyHovered = false
    @State private var deleteHovered = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(clip.appName)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.659, green: 0.855, blue: 0.863))

                    Text(formatDate(clip.timestamp))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.5))
                }

                Spacer()

                Button(action: { onDismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.black.opacity(0.9))

            // Content
            ScrollView {
                Text(clip.text)
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.9))
                    .textSelection(.enabled)
                    .padding()
            }
            .background(Color.black.opacity(0.7))

            // Footer with actions
            HStack(spacing: 12) {
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(clip.text, forType: .string)
                    onDismiss()
                }) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
                .padding(10)
                .background(Color.white.opacity(copyHovered ? 0.3 : 0.2))
                .cornerRadius(8)
                .scaleEffect(copyHovered ? 1.05 : 1.0)
                .help("Copy to clipboard")
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        copyHovered = hovering
                    }
                }

                Button(action: {
                    onDismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        appState.deleteClip(clip, from: appState.viewedColor.name)
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                }
                .buttonStyle(.plain)
                .padding(10)
                .background(Color.white.opacity(deleteHovered ? 0.25 : 0.15))
                .cornerRadius(8)
                .scaleEffect(deleteHovered ? 1.05 : 1.0)
                .help("Delete clip")
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        deleteHovered = hovering
                    }
                }

                Spacer()

                Text("\(clip.text.count) characters")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding()
            .background(Color.black.opacity(0.9))
        }
        .frame(width: 500, height: 400)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Color Picker View
struct ColorPickerView: View {
    let text: String
    let onColorSelected: (NibColor) -> Void
    @State private var hoveredColor: String? = nil

    var body: some View {
        HStack(spacing: 20) {
            ForEach(NibColor.all, id: \.name) { color in
                Button(action: { onColorSelected(color) }) {
                    Circle()
                        .fill(Color(color.nsColor))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        )
                        .scaleEffect(hoveredColor == color.name ? 1.15 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        hoveredColor = hovering ? color.name : nil
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        )
    }
}