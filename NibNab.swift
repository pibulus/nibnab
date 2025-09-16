import Cocoa
import SwiftUI

// ===================================================================
// NIBNAB - Color-coded clipboard collector
// Nabbing the good bits since 2025
// ===================================================================

// MARK: - Color Theme
struct NibColor {
    let name: String
    let hex: String
    let nsColor: NSColor

    static let pink = NibColor(
        name: "Pink",
        hex: "#FF48B0",
        nsColor: NSColor(red: 1.0, green: 0.282, blue: 0.690, alpha: 1.0)
    )

    static let blue = NibColor(
        name: "Blue",
        hex: "#0078BF",
        nsColor: NSColor(red: 0, green: 0.471, blue: 0.749, alpha: 1.0)
    )

    static let yellow = NibColor(
        name: "Yellow",
        hex: "#FFE800",
        nsColor: NSColor(red: 1.0, green: 0.910, blue: 0, alpha: 1.0)
    )

    static let green = NibColor(
        name: "Green",
        hex: "#00A95C",
        nsColor: NSColor(red: 0, green: 0.663, blue: 0.361, alpha: 1.0)
    )

    static let all = [pink, blue, yellow, green]
}

// MARK: - Gradient Colors
struct NibGradients {
    static let pink = LinearGradient(
        colors: [Color(red: 1.0, green: 0.4, blue: 0.7), Color(red: 1.0, green: 0.2, blue: 0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let blue = LinearGradient(
        colors: [Color(red: 0.2, green: 0.6, blue: 1.0), Color(red: 0, green: 0.4, blue: 0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let yellow = LinearGradient(
        colors: [Color(red: 1.0, green: 0.95, blue: 0.2), Color(red: 1.0, green: 0.85, blue: 0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let green = LinearGradient(
        colors: [Color(red: 0.2, green: 0.8, blue: 0.5), Color(red: 0, green: 0.6, blue: 0.3)],
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

        popover.contentSize = NSSize(width: 420, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)

        // Setup event monitor
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strongSelf = self, strongSelf.popover.isShown {
                strongSelf.closePopover()
            }
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

    func showColorPicker(for text: String) {
        // Create color picker overlay window
        let picker = ColorPickerView(text: text) { [weak self] color in
            self?.appState.saveClip(text, to: color)
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

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var selectedColor: NibColor = NibColor.pink
    @Published var isMonitoring = true
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

        // Show color picker
        delegate?.showColorPicker(for: string)
    }

    func saveClip(_ text: String, to color: NibColor) {
        let clip = Clip(
            text: text,
            timestamp: Date(),
            url: getCurrentURL(),
            appName: getCurrentAppName()
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

    private func getCurrentAppName() -> String {
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

// MARK: - Main Content View
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: String = "Pink"
    @State private var hoveredTab: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(NibGradients.pink)
                    Text("NibNab")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(NibGradients.pink)
                }

                Spacer()

                Toggle("", isOn: $appState.isMonitoring)
                    .toggleStyle(SwitchToggleStyle())
                    .scaleEffect(0.7)

                Button(action: { NSApp.terminate(nil) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Color Tabs
            HStack(spacing: 12) {
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
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            // Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let clips = appState.clips[selectedTab], !clips.isEmpty {
                        ForEach(clips) { clip in
                            ClipView(clip: clip)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.3))
                            Text("No \(selectedTab.lowercased()) clips yet")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("Copy some text to get started")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(60)
                    }
                }
                .padding(12)
            }
            .frame(height: 280)

            // Footer
            HStack {
                Text("Nabbing the good bits")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
                Spacer()
                Text("\(appState.clips.values.reduce(0) { $0 + $1.count }) clips")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        }
        .background(Color(NSColor.windowBackgroundColor))
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
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(color.nsColor))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color(color.nsColor).opacity(0.3), radius: isSelected ? 4 : 2)

                Text(color.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color(color.nsColor).opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color(color.nsColor).opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
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
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer()

                Text(timeAgo(from: clip.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Text(clip.text.prefix(150) + (clip.text.count > 150 ? "..." : ""))
                .font(.system(size: 12))
                .lineLimit(3)
                .foregroundColor(.primary.opacity(0.9))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(isHovered ? 1.0 : 0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
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
        HStack(spacing: 16) {
            ForEach(NibColor.all, id: \.name) { color in
                Button(action: { onColorSelected(color) }) {
                    Circle()
                        .fill(Color(color.nsColor))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .shadow(color: Color(color.nsColor).opacity(0.5), radius: hoveredColor == color.name ? 8 : 4)
                        .scaleEffect(hoveredColor == color.name ? 1.2 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        hoveredColor = hovering ? color.name : nil
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
    }
}