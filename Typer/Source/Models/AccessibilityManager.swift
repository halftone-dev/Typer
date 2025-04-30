import AppKit
import ApplicationServices

indirect enum AXPredicate {
    case attribute(String, String) // (attributeName, value)
    case attributeContains(String, String)
    case hasChild(AXPredicate)
    case hasDescendant(AXPredicate)
    case hasParent(AXPredicate)
    case and([AXPredicate])
    case or([AXPredicate])
    case not(AXPredicate)
}

// Query builder with fluent interface
class AXQuery {
    private var predicates: [AXPredicate] = []

    static func where_(_ predicate: AXPredicate) -> AXQuery {
        let query = AXQuery()
        query.predicates.append(predicate)
        return query
    }

    func and(_ predicate: AXPredicate) -> AXQuery {
        predicates.append(predicate)
        return self
    }

    func or(_ predicate: AXPredicate) -> AXQuery {
        predicates.append(.or([predicates.removeLast(), predicate]))
        return self
    }

    var predicate: AXPredicate {
        if predicates.count == 1 {
            return predicates[0]
        }
        return .and(predicates)
    }
}

class AccessibilityManager {
    static let shared = AccessibilityManager()
    private let systemWideElement: AXUIElement

    private init() {
        systemWideElement = AXUIElementCreateSystemWide()
    } // Singleton

    // MARK: - Public Methods

    func checkAccessibilityPermissions() -> Bool {
        let accessibilityEnabled = AXIsProcessTrusted()
        print(accessibilityEnabled ? "Accessibility enabled" : "Accessibility disabled")
        return accessibilityEnabled
    }

    func insertText(_ text: String) {
        let bundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        print("Current application: \(bundleIdentifier)")
        insertTextViaPaste(text)

        // if AppBehavior.pastePreferred.contains(bundleIdentifier) {
        //    insertTextViaPaste(text)
        // } else if !insertTextViaAX(text) {
        //    insertTextViaPaste(text)

        // }
    }

    func getFocusedApplicationTitle() -> String? {
        guard let appElement = getFocusedApplication() else { return nil }

        return getElementTitle(from: appElement)
    }

    func getFocusedWindowTitle() -> String? {
        guard let appElement = getFocusedWindow() else { return nil }

        return getElementTitle(from: appElement)
    }

    func getTextContexts() -> (before: String, selected: String, after: String)? {
        guard let element = getFocusedElement() else { return nil }

        // Try to get selected text range
        var selectedRangeValue: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeValue
        )

        if let fullText = getElementText(from: element),
           rangeResult == .success
        {
            let selectedRange = selectedRangeValue as! AXValue
            var range = CFRange(location: 0, length: 0)
            AXValueGetValue(selectedRange, .cfRange, &range)

            // Check if range is within bounds
            if range.location < 0 || range.location + range.length > fullText.count {
                return nil
            }

            // Check if string index arithmetic would be out of bounds
            if fullText.distance(from: fullText.startIndex, to: fullText.endIndex) < range.location + range.length {
                return nil
            }

            let before = String(fullText.prefix(range.location))
            let selected = String(
                fullText[
                    fullText.index(
                        fullText.startIndex, offsetBy: range.location
                    ) ..< (fullText.index(
                        fullText.startIndex, offsetBy: range.location + range.length
                    ))
                ])
            let after = String(fullText.suffix(fullText.count - (range.location + range.length)))

            return (before: before, selected: selected, after: after)
        }

        return nil
    }

    // MARK: - Insertion Methods

    private func insertTextViaAX(_ text: String) -> Bool {
        guard checkAccessibilityPermissions() else {
            print("Accessibility permissions not granted")
            return false
        }

        guard let element = getFocusedElement() else {
            return false
        }

        if AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        ) == .success {
            print("Successfully inserted text using AXSelectedText")
            return true
        }
        return false
    }

    private func insertTextViaPaste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousContent = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        simulateCommandV()

        // Restore previous clipboard content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let previousContent = previousContent {
                pasteboard.clearContents()
                pasteboard.setString(previousContent, forType: .string)
            }
        }
    }

    private func simulateCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let vKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

        vKeyDown?.flags = .maskCommand
        vKeyUp?.flags = .maskCommand

        vKeyDown?.post(tap: .cghidEventTap)
        vKeyUp?.post(tap: .cghidEventTap)
    }

    // Silent Command+C simulation (no sound)
    func simulateCommandC() {
        // Create a silent event source
        let source = CGEventSource(stateID: .hidSystemState)

        // Create the 'C' key events (key code 8 for 'C')
        let cKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let cKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)

        // Add Command modifier
        cKeyDown?.flags = .maskCommand
        cKeyUp?.flags = .maskCommand

        // Post the events to simulate Command+C
        cKeyDown?.post(tap: .cghidEventTap)
        cKeyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Context Methods

    private func getFocusedApplication() -> AXUIElement? {
        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )

        guard appResult == .success else {
            print("Failed to get focused application")
            return nil
        }
        let appElement = focusedApp as! AXUIElement
        return appElement
    }

    private func getFocusedWindow() -> AXUIElement? {
        guard let appElement = getFocusedApplication() else { return nil }

        var focusedWindow: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        guard windowResult == .success else {
            print("Failed to get focused window")
            return nil
        }

        let element = focusedWindow as! AXUIElement
        return element
    }

    private func getFocusedElement() -> AXUIElement? {
        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success else {
            print("Failed to get focused element: \(focusResult)")
            return nil
        }

        let element = focusedElement as! AXUIElement
        return element
    }

    private func getElementTitle(from element: AXUIElement) -> String? {
        var titleValue: AnyObject?
        if AXUIElementCopyAttributeValue(
            element,
            kAXTitleAttribute as CFString,
            &titleValue
        ) == .success,
            let title = titleValue as? String
        {
            return title
        }
        return nil
    }

    private func getElementText(from element: AXUIElement) -> String? {
        var valueResult: AnyObject?
        let valueStatus = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &valueResult
        )

        if valueStatus == .success,
           let fullText = valueResult as? String
        {
            return fullText
        }
        return nil
    }

    func getElementInfo(from element: AXUIElement) -> [String: String] {
        var info: [String: String] = [:]

        // List of attributes to check
        let attributesToCheck = [
            kAXDescriptionAttribute,
            kAXTitleAttribute,
            kAXValueAttribute,
            kAXRoleDescriptionAttribute,
            kAXIdentifierAttribute,
        ]

        for attribute in attributesToCheck {
            var attributeValue: AnyObject?
            if AXUIElementCopyAttributeValue(
                element,
                attribute as CFString,
                &attributeValue
            ) == .success,
                let value = attributeValue as? String
            {
                info[attribute] = value
            }
        }

        return info
    }

    func exploreElementsWithInfo() {
        guard let app = getFocusedApplication() else { return }

        func traverse(_ element: AXUIElement, level: Int = 0) {
            let indent = String(repeating: "  ", count: level)
            let info = getElementInfo(from: element)

            if !info.isEmpty {
                print("\(indent)Element Info:")
                for (attribute, value) in info {
                    print("\(indent)  \(attribute): \(value)")
                }
            }

            var childrenValue: AnyObject?
            if AXUIElementCopyAttributeValue(
                element, kAXChildrenAttribute as CFString, &childrenValue
            ) == .success,
                let children = childrenValue as? [AXUIElement]
            {
                children.forEach { traverse($0, level: level + 1) }
            }
        }

        traverse(app)
    }

    // Example code to get the WhatsApp recipient name
    // let query = AXQuery.where_(.attribute(kAXRoleDescriptionAttribute, "heading"))
    //    .and(.hasParent(.attribute(kAXRoleDescriptionAttribute, "Nav bar")))
    // let elements = AccessibilityManager.shared.findElements(matching: query)

    // if elements.count >= 2,
    //    let description = AccessibilityManager.shared.getDescription(from: elements[1])
    // {
    //    print("Description: \(description)")
    // }
    func findElements(matching query: AXQuery) -> [AXUIElement] {
        guard let app = getFocusedApplication() else { return [] }
        return findElements(in: app, matching: query.predicate)
    }

    private func findElements(in element: AXUIElement, matching predicate: AXPredicate)
        -> [AXUIElement]
    {
        var results: [AXUIElement] = []

        if matches(element: element, predicate: predicate) {
            results.append(element)
        }

        // Recurse through children
        var childrenValue: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
            == .success,
            let children = childrenValue as? [AXUIElement]
        {
            for child in children {
                results.append(contentsOf: findElements(in: child, matching: predicate))
            }
        }

        return results
    }

    private func matches(element: AXUIElement, predicate: AXPredicate) -> Bool {
        switch predicate {
        case let .attribute(name, value):
            return getAttributeValue(element, name) == value

        case let .attributeContains(name, value):
            return getAttributeValue(element, name)?.contains(value) ?? false

        case let .hasChild(childPredicate):
            var childrenValue: AnyObject?
            guard
                AXUIElementCopyAttributeValue(
                    element, kAXChildrenAttribute as CFString, &childrenValue
                ) == .success,
                let children = childrenValue as? [AXUIElement]
            else {
                return false
            }
            return children.contains(where: { matches(element: $0, predicate: childPredicate) })

        case let .hasDescendant(descendantPredicate):
            var childrenValue: AnyObject?
            guard
                AXUIElementCopyAttributeValue(
                    element, kAXChildrenAttribute as CFString, &childrenValue
                ) == .success,
                let children = childrenValue as? [AXUIElement]
            else {
                return false
            }
            return children.contains(where: {
                matches(element: $0, predicate: descendantPredicate)
                    || matches(element: $0, predicate: .hasDescendant(descendantPredicate))
            })

        case let .hasParent(parentPredicate):
            var parentValue: AnyObject?
            guard
                AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentValue)
                == .success
            else {
                return false
            }
            let parent = parentValue as! AXUIElement
            return matches(element: parent, predicate: parentPredicate)

        case let .and(predicates):
            return predicates.allSatisfy { matches(element: element, predicate: $0) }

        case let .or(predicates):
            return predicates.contains { matches(element: element, predicate: $0) }

        case let .not(predicate):
            return !matches(element: element, predicate: predicate)
        }
    }

    private func getAttributeValue(_ element: AXUIElement, _ attributeName: String) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attributeName as CFString, &value) == .success
        else {
            return nil
        }
        return value as? String
    }
}

extension AccessibilityManager {
    func getAttribute(_ attributeName: String, from element: AXUIElement) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            element,
            attributeName as CFString,
            &value
        )

        if result == .success {
            return value as? String
        } else {
            print("Failed to get attribute '\(attributeName)': \(result)")
            return nil
        }
    }
}

// For convenience, let's also add some common attribute getters
extension AccessibilityManager {
    func getRole(from element: AXUIElement) -> String? {
        getAttribute(kAXRoleAttribute, from: element)
    }

    func getTitle(from element: AXUIElement) -> String? {
        getAttribute(kAXTitleAttribute, from: element)
    }

    func getDescription(from element: AXUIElement) -> String? {
        getAttribute(kAXDescriptionAttribute, from: element)
    }

    func getValue(from element: AXUIElement) -> String? {
        getAttribute(kAXValueAttribute, from: element)
    }
}

// MARK: - App Behavior Configuration

private enum AppBehavior {
    static let pastePreferred = Set([
        "com.microsoft.VSCode",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.apple.Safari",
        // "com.google.Chrome",
        "md.obsidian",
        "net.whatsapp.WhatsApp",
    ])

    static let accessibilityPreferred = Set([
        "com.apple.TextEdit",
        "com.apple.Notes",
    ])
}
