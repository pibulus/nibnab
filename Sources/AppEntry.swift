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
    private var statusToastWindow: NSPanel?
    private var statusToastWorkItem: DispatchWorkItem?
    private var welcomeWindow: NSWindow?
    private var aboutWindow: NSWindow?

    func applicationWillTerminate(_ notification: Notification) {
        appState?.stopClipboardMonitoring()
        autoCopyMonitor?.stop()
        eventMonitor?.stop()
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
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

        if appState.launchAtLogin {
            try? SMAppService.mainApp.register()
        }

        autoCopyMonitor = AutoCopyMonitor { [weak self] selectedText in
            guard let self = self else { return }
            self.appState.suppressNextClipboardCapture = true
            let sourceApp = self.appState.getCurrentAppName()
            self.appState.saveClip(selectedText, to: self.appState.activeColor, from: sourceApp)
            self.pulseMenubarIcon()
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
            statusToastWindow?.orderOut(nil)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
            eventMonitor?.start()
        }
    }

    func closePopover() {
        popover.performClose(nil)
        eventMonitor?.stop()
    }

    func showStatusToast(message: String, color: NibColor) {
        statusToastWorkItem?.cancel()

        let toastView = StatusToastView(message: message, color: color)
        let hostingController = NSHostingController(rootView: toastView)

        if statusToastWindow == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 200, height: 56),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            panel.level = .statusBar
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.transient, .ignoresCycle, .canJoinAllSpaces]
            panel.isReleasedWhenClosed = false
            statusToastWindow = panel
        }

        statusToastWindow?.contentViewController = hostingController
        hostingController.view.layoutSubtreeIfNeeded()

        let fittingSize = hostingController.view.fittingSize
        let targetSize = NSSize(width: fittingSize.width, height: fittingSize.height)
        hostingController.preferredContentSize = targetSize
        statusToastWindow?.setContentSize(targetSize)

        if let button = statusItem.button,
           let window = button.window {
            var buttonRect = button.bounds
            buttonRect = button.convert(buttonRect, to: nil)
            let screenRect = window.convertToScreen(buttonRect)
            let x = screenRect.midX - (targetSize.width / 2)
            let y = screenRect.minY - targetSize.height - 12
            statusToastWindow?.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: targetSize), display: true)
        } else if let screenFrame = NSScreen.main?.visibleFrame {
            let x = screenFrame.maxX - targetSize.width - 20
            let y = screenFrame.maxY - targetSize.height - 40
            statusToastWindow?.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: targetSize), display: true)
        }

        statusToastWindow?.orderFrontRegardless()

        let workItem = DispatchWorkItem { [weak self] in
            self?.statusToastWindow?.orderOut(nil)
        }
        statusToastWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }

    func pulseMenubarIcon() {
        guard let button = statusItem.button else { return }

        // Enable layer-backing if not already enabled
        if button.layer == nil {
            button.wantsLayer = true
        }

        guard let buttonLayer = button.layer else { return }

        // Create animation layer
        let animationLayer = CALayer()
        animationLayer.frame = buttonLayer.bounds
        animationLayer.cornerRadius = min(buttonLayer.bounds.width, buttonLayer.bounds.height) / 2
        animationLayer.backgroundColor = appState.activeColor.nsColor.cgColor
        animationLayer.opacity = 0.0

        // Add as sublayer (don't replace the root layer!)
        buttonLayer.addSublayer(animationLayer)

        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0.0
        fadeIn.toValue = 0.4
        fadeIn.duration = 0.15
        fadeIn.autoreverses = true
        animationLayer.add(fadeIn, forKey: "pulse")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak button] in
            animationLayer.removeFromSuperlayer()
            // Ensure button updates its display after animation
            button?.needsDisplay = true
        }
    }

    func updateMenubarIcon() {
        guard let button = statusItem.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        guard let symbol = NSImage(systemSymbolName: "highlighter", accessibilityDescription: "NibNab")?
            .withSymbolConfiguration(config) else {
            return
        }

        let size = NSSize(width: 26, height: 24)
        let compositeImage = NSImage(size: size)

        compositeImage.lockFocus()

        // Draw highlighter icon with a bright tint using destination masking
        let iconRect = NSRect(x: 4, y: 4, width: 18, height: 18)
        NSColor.white.setFill()
        iconRect.fill()
        symbol.draw(in: iconRect, from: .zero, operation: .destinationIn, fraction: 1.0, respectFlipped: true, hints: nil)

        // Draw colored status dot
        let dotRect = NSRect(x: size.width - 10, y: 4, width: 8, height: 8)
        let dotPath = NSBezierPath(ovalIn: dotRect)
        appState.activeColor.nsColor.setFill()
        dotPath.fill()

        // Subtle outline for contrast on light/dark backgrounds
        NSColor.white.withAlphaComponent(0.9).setStroke()
        dotPath.lineWidth = 0.8
        dotPath.stroke()

        compositeImage.unlockFocus()
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

    func syncSelectionMonitoring() {
        guard autoCopyMonitor != nil else { return }

        if appState.isMonitoring && appState.autoCopyEnabled {
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

        let toggleID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_N),
            UInt32(cmdKey | controlKey),
            toggleID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefs[0]
        )

        let yellowID = EventHotKeyID(signature: signature, id: 2)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_1),
            UInt32(cmdKey | controlKey),
            yellowID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefs[1]
        )

        let orangeID = EventHotKeyID(signature: signature, id: 3)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_2),
            UInt32(cmdKey | controlKey),
            orangeID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefs[2]
        )

        let pinkID = EventHotKeyID(signature: signature, id: 4)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_3),
            UInt32(cmdKey | controlKey),
            pinkID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefs[3]
        )

        let purpleID = EventHotKeyID(signature: signature, id: 5)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_4),
            UInt32(cmdKey | controlKey),
            purpleID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefs[4]
        )

        let greenID = EventHotKeyID(signature: signature, id: 6)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_5),
            UInt32(cmdKey | controlKey),
            greenID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefs[5]
        )

        let monitoringID = EventHotKeyID(signature: signature, id: 7)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_M),
            UInt32(cmdKey | controlKey),
            monitoringID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRefs[6]
        )

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
            nil
        )
    }
}
