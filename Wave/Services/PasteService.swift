import AppKit
import ApplicationServices
import Carbon.HIToolbox

struct PasteService {
    static func paste(text: String) {
        pasteViaKeyboard(text)
    }

    private static func pasteViaKeyboard(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Preserve whatever was on the clipboard
        let previousItems = pasteboard.pasteboardItems?.compactMap { item -> [NSPasteboard.PasteboardType: Data]? in
            var dataMap: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dataMap[type] = data }
            }
            return dataMap.isEmpty ? nil : dataMap
        }

        pasteboard.clearContents()
        // Write with ConcealedType so clipboard managers skip recording this transient write
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        pasteboard.writeObjects([item])

        // Simulate Cmd+V
        let src = CGEventSource(stateID: .hidSystemState)
        let vKey = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        // Restore clipboard after the keystroke has been processed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pasteboard.clearContents()
            if let items = previousItems, !items.isEmpty {
                for dataMap in items {
                    let newItem = NSPasteboardItem()
                    for (type, data) in dataMap { newItem.setData(data, forType: type) }
                    pasteboard.writeObjects([newItem])
                }
            }
        }
    }

    @MainActor
    static func getSelectedText() async -> String? {
        let pasteboard = NSPasteboard.general

        // Save current clipboard state
        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> [NSPasteboard.PasteboardType: Data]? in
            var dataMap: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dataMap[type] = data }
            }
            return dataMap.isEmpty ? nil : dataMap
        }
        let savedChangeCount = pasteboard.changeCount

        // Brief pre-delay so the user's held hotkey modifier doesn't collide with
        // the synthetic Cmd+C (Electron/JVM apps read hardware modifier state directly).
        try? await Task.sleep(for: .milliseconds(20))

        // Simulate Cmd+C — works in every app (browsers, Electron, Terminal)
        let src = CGEventSource(stateID: .hidSystemState)
        let cKey = CGKeyCode(kVK_ANSI_C)
        let down = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags   = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        // Poll the pasteboard up to ~300ms instead of a fixed sleep —
        // JVM/Electron apps can take 100–250ms to land on the system pasteboard.
        let pollStart = Date()
        let pollTimeout: TimeInterval = 0.3
        while pasteboard.changeCount == savedChangeCount,
              Date().timeIntervalSince(pollStart) < pollTimeout {
            try? await Task.sleep(for: .milliseconds(15))
        }

        // Only read if the clipboard actually changed (i.e. something was selected)
        let text: String?
        if pasteboard.changeCount != savedChangeCount {
            text = pasteboard.string(forType: .string)
        } else {
            text = nil
        }

        // Restore original clipboard
        pasteboard.clearContents()
        if let items = savedItems, !items.isEmpty {
            for dataMap in items {
                let newItem = NSPasteboardItem()
                for (type, data) in dataMap { newItem.setData(data, forType: type) }
                pasteboard.writeObjects([newItem])
            }
        }

        return text?.isEmpty == false ? text : nil
    }

    /// Chrome and Electron apps only expose their accessibility tree (and so
    /// their focused text field) once an assistive app asks for it.
    static func enableAccessibilityInFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    /// Returns true if the focused UI element accepts text input
    /// (e.g. user has cursor in a text field, text area, search bar).
    static func hasEditableFocus() -> Bool {
        enableAccessibilityInFrontmostApp()
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement else { return false }
        let axElement = element as! AXUIElement

        // Primary signal: role suggests an editable field
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &role) == .success,
           let roleString = role as? String {
            let editableRoles: Set<String> = [
                "AXTextField",
                "AXTextArea",
                "AXComboBox",
                "AXSearchField",
            ]
            if editableRoles.contains(roleString) { return true }
        }

        // Fallback: element lets us set its value (works for some browser inputs)
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(axElement, kAXValueAttribute as CFString, &settable)
        return settable.boolValue
    }
}
