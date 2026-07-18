import Cocoa
import SwiftUI
import ApplicationServices
import ServiceManagement
import Carbon.HIToolbox

@main
struct NibNabApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var appState: AppState!
    var eventMonitor: EventMonitor?
    var autoCopyMonitor: AutoCopyMonitor?
    private var localKeyMonitor: Any?
    private var hotKeyRefs: [EventHotKeyRef?] = Array(repeating: nil, count: 7)
    private var hotKeyHandlerRef: EventHandlerRef?

    private var welcomeWindow: NSWindow?
    private var aboutWindow: NSWindow?

    func applicationWillTerminate(_ notification: Notification) {
        appState?.stopClipboardMonitoring()
        autoCopyMonitor?.stop()
        eventMonitor?.stop()
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        for ref in hotKeyRefs {
            if let ref { UnregisterEventHotKey(ref) }
        }
        if let hotKeyHandlerRef { RemoveEventHandler(hotKeyHandlerRef) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(handleMenubarClick(_:))
        }

        appState = AppState()
        appState.delegate = self
        updateMenubarIcon()

        let popoverSize = NSSize(width: 600, height: 540)

        let contentView = ContentView()
            .environmentObject(appState)

        let hostingController = NSHostingController(rootView: contentView)
        hostingController.preferredContentSize = popoverSize

        popover.contentViewController = hostingController
        popover.contentSize = popoverSize
        popover.behavior = .transient

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strongSelf = self,
               strongSelf.popover.isShown,
               let button = strongSelf.statusItem.button,
               event?.windowNumber != button.window?.windowNumber {
                strongSelf.popover.performClose(event)
            }
        }
        eventMonitor?.start()

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 /* Escape */ && self?.popover.isShown == true {
                self?.closePopover()
                return nil
            }
            return event
        }

        registerGlobalShortcut()

        // Selection capture needs the Accessibility API, which sandboxed
        // (App Store) builds can never be granted — don't even create the
        // monitor there, so no dead permission prompt ever shows.
        if !SandboxInfo.isSandboxed {
            autoCopyMonitor = AutoCopyMonitor { [weak self] selectedText in
                guard let self = self else { return }
                self.appState.suppressNextClipboardCapture = true
                let sourceApp = self.appState.getCurrentAppName()
                self.appState.saveClip(selectedText, to: self.appState.activeColor, from: sourceApp)
                self.pulseMenuBarIcon()
            }
        }

        if appState.isMonitoring {
            appState.startClipboardMonitoring()
        }
        syncSelectionMonitoring()
    }

    @objc func handleMenubarClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showColorMenu()
        } else {
            togglePopover()
        }
    }

    func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
            // The popover auto-focuses the search field after SwiftUI's onAppear
            // has already run, leaving a blinking cursor — clear it once the
            // window has settled.
            DispatchQueue.main.async { [weak self] in
                self?.popover.contentViewController?.view.window?.makeFirstResponder(nil)
            }
            eventMonitor?.start()
        }
    }

    func closePopover() {
        popover.performClose(nil)
        eventMonitor?.stop()
    }

    func pulseMenuBarIcon(color: NibColor? = nil) {
        guard let button = statusItem.button else { return }
        let pulseColor = color ?? appState.activeColor

        if button.layer == nil { button.wantsLayer = true }
        guard let buttonLayer = button.layer else { return }

        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 1.0
        scaleAnim.toValue = 1.25
        scaleAnim.duration = 0.12
        scaleAnim.autoreverses = true
        buttonLayer.add(scaleAnim, forKey: "iconPop")

        let flashLayer = CALayer()
        flashLayer.frame = buttonLayer.bounds
        flashLayer.cornerRadius = buttonLayer.bounds.height / 2
        flashLayer.backgroundColor = pulseColor.nsColor.cgColor
        flashLayer.opacity = 0.0
        buttonLayer.addSublayer(flashLayer)

        let flashAnim = CAKeyframeAnimation(keyPath: "opacity")
        flashAnim.values = [0.0, 0.65, 0.0, 0.4, 0.0]
        flashAnim.keyTimes = [0.0, 0.15, 0.3, 0.45, 1.0]
        flashAnim.duration = 0.5

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            flashLayer.removeFromSuperlayer()
            button.needsDisplay = true
        }
        flashLayer.add(flashAnim, forKey: "flash")
        CATransaction.commit()
    }

    func updateMenubarIcon() {
        guard let button = statusItem.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        guard let symbol = NSImage(systemSymbolName: "highlighter", accessibilityDescription: "NibNab")?
            .withSymbolConfiguration(config) else {
            return
        }

        let size = NSSize(width: 26, height: 24)
        let dotColor = appState.activeColor.nsColor

        // Drawn via handler so it re-renders per appearance: labelColor makes
        // the glyph black on a light menubar and white on a dark one, while
        // the status dot keeps its real color (which is why isTemplate stays false).
        let compositeImage = NSImage(size: size, flipped: false) { _ in
            let iconRect = NSRect(x: 4, y: 4, width: 18, height: 18)
            NSColor.labelColor.setFill()
            iconRect.fill()
            symbol.draw(in: iconRect, from: .zero, operation: .destinationIn, fraction: 1.0, respectFlipped: true, hints: nil)

            let dotRect = NSRect(x: size.width - 10, y: 4, width: 8, height: 8)
            let dotPath = NSBezierPath(ovalIn: dotRect)
            dotColor.setFill()
            dotPath.fill()

            // Subtle outline so the dot reads on both menubar appearances
            NSColor.labelColor.withAlphaComponent(0.4).setStroke()
            dotPath.lineWidth = 0.8
            dotPath.stroke()
            return true
        }
        compositeImage.isTemplate = false

        button.image = compositeImage
        button.imagePosition = .imageOnly
    }

    func showColorMenu() {
        let menu = NSMenu()

        let colorShortcuts = ["⌘⌃1", "⌘⌃2", "⌘⌃3", "⌘⌃4", "⌘⌃5"]

        for (index, color) in NibColor.all.enumerated() {
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
            item.toolTip = "Keyboard shortcut: \(colorShortcuts[index])"
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.state = appState.launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        let soundItem = NSMenuItem(
            title: "Sound Effects",
            action: #selector(toggleSoundEffects),
            keyEquivalent: ""
        )
        soundItem.state = appState.soundEffectsEnabled ? .on : .off
        menu.addItem(soundItem)

        let autoCaptureItem = NSMenuItem(
            title: "Auto-Capture Clipboard",
            action: #selector(toggleAutoCapture),
            keyEquivalent: ""
        )
        autoCaptureItem.state = appState.isMonitoring ? .on : .off
        autoCaptureItem.toolTip = "Keyboard shortcut: ⌘⌃M"
        menu.addItem(autoCaptureItem)

        // Only offered where the Accessibility API can actually work
        // (non-sandboxed builds).
        if autoCopyMonitor != nil {
            let selectionItem = NSMenuItem(
                title: "Capture Text Selections",
                action: #selector(toggleSelectionCapture),
                keyEquivalent: ""
            )
            selectionItem.state = appState.selectionCaptureEnabled ? .on : .off
            selectionItem.toolTip = "Highlight text in any app to nab it (also copies it to your clipboard)"
            menu.addItem(selectionItem)
        }

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(
            title: "About NibNab...",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

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
            appState.switchToColor(color, announce: true)
        }
    }

    @objc func toggleLaunchAtLogin() {
        appState.launchAtLogin.toggle()
    }

    @objc func toggleSoundEffects() {
        appState.soundEffectsEnabled.toggle()
    }

    @objc func toggleAutoCapture() {
        if appState.isMonitoring {
            appState.setMonitoring(false, suppressToast: false)
        } else {
            appState.setMonitoring(true, suppressToast: false)
        }
    }

    @objc func toggleSelectionCapture() {
        appState.selectionCaptureEnabled.toggle()
    }

    func syncSelectionMonitoring() {
        guard autoCopyMonitor != nil else { return }

        if appState.isMonitoring && appState.selectionCaptureEnabled {
            autoCopyMonitor?.start()
        } else {
            autoCopyMonitor?.stop()
        }
    }

    func showWelcomeWindow() {
        if let welcomeWindow {
            welcomeWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let welcomeView = WelcomeView(onDismiss: { [weak self] in
            self?.welcomeWindow?.close()
        })
        .environmentObject(appState)

        welcomeWindow = makeAuxiliaryWindow(
            title: "Welcome to NibNab",
            contentViewController: NSHostingController(rootView: welcomeView),
            size: NSSize(width: 460, height: 480)
        )
    }

    @objc func showAbout() {
        if let aboutWindow {
            aboutWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let aboutSize = NSSize(width: 520, height: 620)
        let hostingController = NSHostingController(rootView: AboutView())
        hostingController.preferredContentSize = aboutSize

        aboutWindow = makeAuxiliaryWindow(
            title: "About NibNab",
            contentViewController: hostingController,
            size: aboutSize
        )
    }

    // Windows created in Swift must keep isReleasedWhenClosed = false — AppKit's
    // extra release on close plus ARC's own release over-releases and crashes.
    // The delegate holds the strong reference and drops it in windowWillClose.
    private func makeAuxiliaryWindow(
        title: String,
        contentViewController: NSViewController,
        size: NSSize
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentViewController = contentViewController
        window.setContentSize(size)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return window
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        // The deferred release below lets AppKit finish its close teardown
        // before ARC drops the last reference.
        if window == welcomeWindow {
            DispatchQueue.main.async { [weak self] in self?.welcomeWindow = nil }
        } else if window == aboutWindow {
            DispatchQueue.main.async { [weak self] in self?.aboutWindow = nil }
        }
    }

    private func registerGlobalShortcut() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let signature = OSType(0x4E42_4E42) // 'NBNB'

        // IDs map to actions in the handler below.
        let bindings: [(keyCode: Int, id: UInt32, label: String)] = [
            (kVK_ANSI_N, 1, "⌘⌃N toggle popover"),
            (kVK_ANSI_1, 2, "⌘⌃1 yellow"),
            (kVK_ANSI_2, 3, "⌘⌃2 orange"),
            (kVK_ANSI_3, 4, "⌘⌃3 pink"),
            (kVK_ANSI_4, 5, "⌘⌃4 purple"),
            (kVK_ANSI_5, 6, "⌘⌃5 green"),
            (kVK_ANSI_M, 7, "⌘⌃M toggle capture")
        ]

        for (index, binding) in bindings.enumerated() {
            let hotKeyID = EventHotKeyID(signature: signature, id: binding.id)
            let status = RegisterEventHotKey(
                UInt32(binding.keyCode),
                UInt32(cmdKey | controlKey),
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRefs[index]
            )
            if status != noErr {
                // Another app (window managers love ⌘⌃ digits) owns this
                // combo — the shortcut silently won't fire, so leave a trace.
                NSLog("NibNab: couldn't register global hotkey %@ (OSStatus %d)", binding.label, status)
            }
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, inEvent, userData) -> OSStatus in
                guard let userData else { return noErr }

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

                let selfPointer = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    switch hotKeyID.id {
                    case 1:
                        selfPointer.togglePopover()
                    case 2:
                        selfPointer.appState.switchToColor(NibColor.yellow)
                    case 3:
                        selfPointer.appState.switchToColor(NibColor.orange)
                    case 4:
                        selfPointer.appState.switchToColor(NibColor.pink)
                    case 5:
                        selfPointer.appState.switchToColor(NibColor.purple)
                    case 6:
                        selfPointer.appState.switchToColor(NibColor.green)
                    case 7:
                        selfPointer.toggleAutoCapture()
                    default:
                        break
                    }
                }

                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &hotKeyHandlerRef
        )
    }
}
