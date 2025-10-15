import Cocoa
import ApplicationServices

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
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        guard isTrusted else {
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
        lastSelectedText = nil
    }

    private func checkForSelectedText() {
        guard let selectedText = AXUIElement.focusedElement?.selectedText,
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              selectedText != lastSelectedText else { return }

        lastSelectedText = selectedText

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedText, forType: .string)

        selectionHandler(selectedText)
    }

    private func pollForAccessibilityPermission() {
        var pollCount = 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            pollCount += 1

            if AXIsProcessTrusted() {
                timer.invalidate()
                self?.start()
            } else if pollCount > 120 {
                timer.invalidate()
            }
        }
    }
}
