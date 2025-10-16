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
class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var appState: AppState!
    var eventMonitor: EventMonitor?
    var autoCopyMonitor: AutoCopyMonitor?
    private var hotKeyRefs: [EventHotKeyRef?] = Array(repeating: nil, count: 7)

    func applicationWillTerminate(_ notification: Notification) {
        appState?.stopClipboardMonitoring()
        autoCopyMonitor?.stop()
        eventMonitor?.stop()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(handleMenubarClick(_:))
        }

        appState = AppState()
        appState.delegate = self
        updateMenubarIcon()

        let contentView = ContentView()
            .environmentObject(appState)

        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: contentView)
        popover.contentSize = NSSize(width: 460, height: 520)
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

        if appState.autoCopyEnabled && autoCopyMonitor != nil {
            autoCopyMonitor?.start()
        }
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
            eventMonitor?.start()
        }
    }

    func closePopover() {
        popover.performClose(nil)
        eventMonitor?.stop()
    }

    func pulseMenubarIcon() {
        guard let button = statusItem.button else { return }
        let animationLayer = CALayer()
        animationLayer.frame = CGRect(x: 0, y: 0, width: 18, height: 18)
        animationLayer.cornerRadius = 9
        animationLayer.backgroundColor = appState.activeColor.nsColor.cgColor
        animationLayer.opacity = 0.0
        button.layer = CALayer()
        button.layer?.addSublayer(animationLayer)

        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0.0
        fadeIn.toValue = 0.4
        fadeIn.duration = 0.1
        fadeIn.autoreverses = true
        animationLayer.add(fadeIn, forKey: "pulse")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            animationLayer.removeFromSuperlayer()
        }
    }

    func updateMenubarIcon() {
        guard let button = statusItem.button else { return }

        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if let highlighterImage = NSImage(systemSymbolName: "pencil.tip", accessibilityDescription: "NibNab")?.withSymbolConfiguration(config) {
            let size = NSSize(width: 22, height: 22)
            let compositeImage = NSImage(size: size)

            compositeImage.lockFocus()

            // Draw highlighter icon
            let iconRect = NSRect(x: 3, y: 5, width: 16, height: 16)
            highlighterImage.draw(in: iconRect)

            // Draw colored dot indicator
            let dotRect = NSRect(x: 15, y: 3, width: 7, height: 7)
            let dotPath = NSBezierPath(ovalIn: dotRect)
            appState.activeColor.nsColor.setFill()
            dotPath.fill()

            compositeImage.unlockFocus()
            compositeImage.isTemplate = true
            button.image = compositeImage
        }
    }

    func showColorMenu() {
        let menu = NSMenu()

        for color in NibColor.all {
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
            appState.activeColor = color
            appState.viewedColor = color
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
            appState.isMonitoring = false
            autoCopyMonitor?.stop()
        } else {
            appState.isMonitoring = true
            autoCopyMonitor?.start()
        }
    }

    func showWelcomeWindow() {
        let welcomeView = WelcomeView(onDismiss: {
            NSApp.keyWindow?.close()
        })
        .environmentObject(appState)

        let hostingController = NSHostingController(rootView: welcomeView)

        let welcomeWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        welcomeWindow.title = "Welcome to NibNab"
        welcomeWindow.contentViewController = hostingController
        welcomeWindow.center()
        welcomeWindow.isReleasedWhenClosed = true
        welcomeWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showAbout() {
        let aboutView = AboutView()
        let hostingController = NSHostingController(rootView: aboutView)

        let aboutWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        aboutWindow.title = "About NibNab"
        aboutWindow.contentViewController = hostingController
        aboutWindow.center()
        aboutWindow.isReleasedWhenClosed = false
        aboutWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
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
            UInt32(cmdKey | shiftKey),
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
            UInt32(cmdKey | shiftKey),
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
                        selfPointer.appState.activeColor = NibColor.yellow
                    case 3:
                        selfPointer.appState.activeColor = NibColor.orange
                    case 4:
                        selfPointer.appState.activeColor = NibColor.pink
                    case 5:
                        selfPointer.appState.activeColor = NibColor.purple
                    case 6:
                        selfPointer.appState.activeColor = NibColor.green
                    case 7:
                        selfPointer.appState.isMonitoring.toggle()
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
