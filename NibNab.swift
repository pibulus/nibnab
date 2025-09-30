import Cocoa
import SwiftUI
import ApplicationServices

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
        hex: "#FFE800",
        nsColor: NSColor(red: 1.0, green: 0.910, blue: 0.0, alpha: 1.0)
    )

    static let orange = NibColor(
        name: "Highlighter Orange",
        hex: "#FF8C00",
        nsColor: NSColor(red: 1.0, green: 0.549, blue: 0.0, alpha: 1.0)
    )

    static let pink = NibColor(
        name: "Highlighter Pink",
        hex: "#FF48B0",
        nsColor: NSColor(red: 1.0, green: 0.282, blue: 0.690, alpha: 1.0)
    )

    static let purple = NibColor(
        name: "Highlighter Purple",
        hex: "#9370DB",
        nsColor: NSColor(red: 0.576, green: 0.439, blue: 0.859, alpha: 1.0)
    )

    static let all = [yellow, orange, pink, purple]
}

// MARK: - Gradient Colors
struct NibGradients {
    static let yellow = LinearGradient(
        colors: [Color(red: 1.0, green: 0.910, blue: 0.0), Color(red: 0.95, green: 0.86, blue: 0.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let orange = LinearGradient(
        colors: [Color(red: 1.0, green: 0.549, blue: 0.0), Color(red: 0.95, green: 0.50, blue: 0.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pink = LinearGradient(
        colors: [Color(red: 1.0, green: 0.282, blue: 0.690), Color(red: 0.95, green: 0.25, blue: 0.65)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let purple = LinearGradient(
        colors: [Color(red: 0.576, green: 0.439, blue: 0.859), Color(red: 0.53, green: 0.40, blue: 0.80)],
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
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var appState: AppState!
    var eventMonitor: EventMonitor?
    var autoCopyMonitor: AutoCopyMonitor?
    var colorPickerWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create app state
        appState = AppState()
        appState.delegate = self

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "highlighter", accessibilityDescription: "NibNab")
            button.action = #selector(togglePopover)
        }

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
            self.showColorPicker(for: selectedText, from: sourceApp)
        }

        // Start clipboard monitoring
        appState.startMonitoring()
    }

    @objc func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
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

    func showColorPicker(for text: String, from sourceApp: String) {
        // Create color picker overlay window
        let picker = ColorPickerView(text: text) { [weak self] color in
            self?.appState.saveClip(text, to: color, from: sourceApp)
            self?.colorPickerWindow?.close()
            self?.colorPickerWindow = nil
        }

        let hostingController = NSHostingController(rootView: picker)

        colorPickerWindow = NSWindow(contentViewController: hostingController)
        colorPickerWindow?.level = .floating
        colorPickerWindow?.styleMask = [.borderless]
        colorPickerWindow?.backgroundColor = .clear
        colorPickerWindow?.isOpaque = false
        colorPickerWindow?.hasShadow = true

        // Position near mouse
        if let mouseLocation = NSEvent.mouseLocation as NSPoint? {
            colorPickerWindow?.setFrameOrigin(NSPoint(x: mouseLocation.x - 100, y: mouseLocation.y - 50))
        }

        colorPickerWindow?.orderFrontRegardless()

        // Auto-close after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.colorPickerWindow?.close()
            self?.colorPickerWindow = nil
        }
    }

    func handleAutoCopyToggle(_ enabled: Bool) {
        print("🎯 Auto-copy toggle changed to: \(enabled)")
        if enabled {
            print("🚀 Starting auto-copy monitor...")
            autoCopyMonitor?.start()
        } else {
            print("🛑 Stopping auto-copy monitor...")
            autoCopyMonitor?.stop()
        }
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
        // Check if accessibility permissions are granted
        guard AXIsProcessTrusted() else {
            print("🔴 NibNab: Not trusted yet, showing our own dialog...")

            // Show our own cute dialog instead of trying to open settings
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "✨ NibNab needs permission!"
                alert.informativeText = "To auto-copy selections:\n\n1. Open System Settings\n2. Go to Privacy & Security → Accessibility\n3. Toggle NibNab ON\n\nI'll wait for you! 💜"
                alert.alertStyle = .informational
                alert.icon = NSImage(systemSymbolName: "highlighter", accessibilityDescription: "NibNab")
                alert.addButton(withTitle: "OK, I'll do it!")
                alert.addButton(withTitle: "Maybe Later")

                if alert.runModal() == .alertFirstButtonReturn {
                    // Just start polling - don't try to open settings
                    self.pollForAccessibilityPermission()
                }
            }
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
    @Published var selectedColor: NibColor = NibColor.yellow
    @Published var isMonitoring = true
    @Published var autoCopyOnHighlight = false {
        didSet {
            delegate?.handleAutoCopyToggle(autoCopyOnHighlight)
        }
    }
    @Published var clips: [String: [Clip]] = [:]

    weak var delegate: AppDelegate?
    private var pasteboardObserver: Timer?
    private var lastChangeCount: Int = 0
    private let storageManager = StorageManager()

    init() {
        // Initialize clips for each color
        for color in NibColor.all {
            clips[color.name] = storageManager.loadClips(for: color.name)
        }
    }

    func startMonitoring() {
        guard isMonitoring else { return }

        let pasteboard = NSPasteboard.general
        lastChangeCount = pasteboard.changeCount

        // Check clipboard on background queue
        pasteboardObserver = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if pasteboard.changeCount != self.lastChangeCount {
                    self.lastChangeCount = pasteboard.changeCount
                    self.handleClipboardChange()
                }
            }
        }
    }

    func stopMonitoring() {
        pasteboardObserver?.invalidate()
        pasteboardObserver = nil
    }

    private func handleClipboardChange() {
        guard let string = NSPasteboard.general.string(forType: .string) else { return }

        // Don't capture empty strings
        guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Capture the current frontmost app BEFORE showing color picker
        let sourceApp = getCurrentAppName()

        // Show color picker with source app info
        delegate?.showColorPicker(for: string, from: sourceApp)
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
    let id: UUID = UUID()
    let text: String
    let timestamp: Date
    let url: String?
    let appName: String
    var screenshotPath: String?
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
                        colors: [Color(red: 1.0, green: 0.282, blue: 0.690),
                                Color(red: 1.0, green: 0.282, blue: 0.690).opacity(0.8)],
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
    @State private var selectedTab: String = "Highlighter Yellow"
    @State private var hoveredTab: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.549, blue: 0.0),
                                        Color(red: 1.0, green: 0.282, blue: 0.690)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("NibNab")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.549, blue: 0.0),
                                        Color(red: 1.0, green: 0.282, blue: 0.690)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                Spacer()

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text("Monitor")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        Toggle("", isOn: $appState.isMonitoring)
                            .toggleStyle(NibToggleStyle())
                    }

                    Divider()
                        .frame(height: 16)
                        .opacity(0.3)

                    HStack(spacing: 4) {
                        Text("Auto-copy")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        Toggle("", isOn: $appState.autoCopyOnHighlight)
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

            // Color Tabs
            HStack(spacing: 24) {
                ForEach(NibColor.all, id: \.name) { color in
                    ColorTab(
                        color: color,
                        isSelected: selectedTab == color.name,
                        isHovered: hoveredTab == color.name,
                        action: { selectedTab = color.name }
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredTab = hovering ? color.name : nil
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .padding(.horizontal, 16)
            )

            // Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let clips = appState.clips[selectedTab], !clips.isEmpty {
                        ForEach(clips) { clip in
                            ClipView(clip: clip)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 64, weight: .light))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.71, blue: 0.655).opacity(0.6),
                                                Color(red: 0.659, green: 0.855, blue: 0.863).opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

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
                Text("Collecting since today")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.yellow)
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