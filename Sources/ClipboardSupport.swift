import Cocoa
import ApplicationServices

// The App Store build runs sandboxed, where the Accessibility API is dead on
// arrival: the permission prompt never appears, the app can't be added in
// System Settings, and AXIsProcessTrusted can never become true. Selection
// capture is disabled entirely in sandboxed builds — clipboard capture only.
enum SandboxInfo {
    static let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
}

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

extension AXUIElement {
    static var focusedElement: AXUIElement? {
        systemWide.element(for: kAXFocusedUIElementAttribute)
    }

    var selectedText: String? {
        rawValue(for: kAXSelectedTextAttribute) as? String
    }

    var ownerPID: pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(self, &pid) == .success ? pid : nil
    }

    private static var systemWide = AXUIElementCreateSystemWide()

    private func element(for attribute: String) -> AXUIElement? {
        guard let rawValue = rawValue(for: attribute),
              CFGetTypeID(rawValue) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(rawValue, to: AXUIElement.self)
    }

    private func rawValue(for attribute: String) -> AnyObject? {
        var rawValue: AnyObject?
        let error = AXUIElementCopyAttributeValue(self, attribute as CFString, &rawValue)
        return error == .success ? rawValue : nil
    }
}

class AutoCopyMonitor {
    private var timer: Timer?
    private var permissionPollTimer: Timer?
    private var lastCapturedSelection: String?
    private var pendingSelection: String?
    private let selectionHandler: (String) -> Void

    init(onTextSelected: @escaping (String) -> Void) {
        self.selectionHandler = onTextSelected
    }

    deinit {
        stop()
    }

    func start() {
        guard timer == nil, permissionPollTimer == nil else { return }

        // Check if we already have accessibility permission (don't prompt every time!)
        let isTrusted = AXIsProcessTrusted()

        guard isTrusted else {
            // Only prompt once when permission is actually needed
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            pollForAccessibilityPermission()
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForSelectedText()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
        lastCapturedSelection = nil
        pendingSelection = nil
    }

    private func checkForSelectedText() {
        guard let focusedElement = AXUIElement.focusedElement else { return }

        // Never capture selections made inside NibNab's own UI (edit modals,
        // search field) — that would re-save clips and clobber the clipboard.
        if focusedElement.ownerPID == ProcessInfo.processInfo.processIdentifier { return }

        guard let selectedText = focusedElement.selectedText,
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              selectedText != lastCapturedSelection else { return }

        // Debounce: only capture once the selection has held steady for a
        // full poll cycle, so drag-selecting doesn't spray partial clips.
        guard selectedText == pendingSelection else {
            pendingSelection = selectedText
            return
        }

        pendingSelection = nil
        lastCapturedSelection = selectedText

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedText, forType: .string)

        selectionHandler(selectedText)
    }

    private func pollForAccessibilityPermission() {
        var pollCount = 0
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            pollCount += 1

            if AXIsProcessTrusted() {
                timer.invalidate()
                self?.permissionPollTimer = nil
                self?.start()
            } else if pollCount > 120 {
                timer.invalidate()
                self?.permissionPollTimer = nil
            }
        }
    }
}
