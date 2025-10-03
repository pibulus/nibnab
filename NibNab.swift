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
        hex: "#f5f617",
        nsColor: NSColor(red: 0.961, green: 0.965, blue: 0.090, alpha: 1.0)
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
        colors: [Color(red: 0.961, green: 0.965, blue: 0.090), Color(red: 0.91, green: 0.915, blue: 0.040)],
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
    private var hotKeyRef: EventHotKeyRef?

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

        popover.contentSize = NSSize(width: 440, height: 420)
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

        // Start clipboard monitoring (for Cmd+C)
        appState.startClipboardMonitoring()

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

        let hotKeyID = EventHotKeyID(signature: OSType(0x4E42_4E42), id: 1) // 'NBNB'

        // Register Cmd+Shift+V
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        // Install event handler
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                if userData != nil {
                    let selfPointer = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
                    DispatchQueue.main.async {
                        selfPointer.togglePopover()
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

        // Draw highlighter icon
        if let highlighter = NSImage(systemSymbolName: "highlighter", accessibilityDescription: "NibNab") {
            highlighter.draw(in: NSRect(x: 0, y: 0, width: 22, height: 22))
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

        for color in NibColor.all {
            let item = NSMenuItem(
                title: color.name,
                action: #selector(selectColor(_:)),
                keyEquivalent: ""
            )
            item.representedObject = color
            item.state = appState.activeColor.name == color.name ? .on : .off
            menu.addItem(item)
        }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func selectColor(_ sender: NSMenuItem) {
        if let color = sender.representedObject as? NibColor {
            appState.activeColor = color
        }
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

        // Brief scale animation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            button.animator().alphaValue = 0.5
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                button.animator().alphaValue = 1.0
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
    }

    private func getCurrentURL() -> String? {
        // TODO: Implement AppleScript to get browser URL
        return nil
    }

    func getCurrentAppName() -> String {
        return NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
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
        // For MVP, return empty array
        return []
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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.yellow)
                    Text("NibNab")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Color.yellow)
                }

                Spacer()

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("Auto-launch")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        Toggle("", isOn: $appState.launchAtLogin)
                            .toggleStyle(NibToggleStyle())
                    }

                    Button(action: { NSApp.terminate(nil) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
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
                    if let clips = appState.clips[appState.viewedColor.name], !clips.isEmpty {
                        ForEach(clips) { clip in
                            ClipView(clip: clip)
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
            HStack {
                Text(appState.clips.values.reduce(0) { $0 + $1.count } > 0 ? "Collected today" : "Collecting since today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.yellow)

                Spacer()

                // Color selector in footer
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
                    }
                }

                Spacer()

                Text("\(appState.clips.values.reduce(0) { $0 + $1.count }) clips")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.yellow)
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
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(clip.appName)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.659, green: 0.855, blue: 0.863))

                Spacer()

                Text(timeAgo(from: clip.timestamp))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
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