import AppKit
import Foundation
import SwiftUI

protocol TextInsertionTarget {
    func insertText(_ text: String)
}

class TextService: ObservableObject {
    static let shared = TextService()

    @Published private(set) var activeTarget: TextInsertionTarget?

    func setActiveTarget(_ target: TextInsertionTarget?) {
        activeTarget = target
    }

    func getSelectedText() -> String? {
        // Get selected text from system-wide context
        if let contexts = AccessibilityManager.shared.getTextContexts() {
            return contexts.selected.isEmpty ? nil : contexts.selected
        }

        // Fallback: Try using clipboard to get selected text
        let pasteboard = NSPasteboard.general
        let originalContent = pasteboard.string(forType: .string)

        // Clear the pasteboard to ensure we can detect new content
        pasteboard.clearContents()

        // Execute Command+C silently to copy selected text
        AccessibilityManager.shared.simulateCommandC()

        // Small delay to ensure pasteboard is updated
        usleep(50_000) // 50ms

        // Check if we have new content
        let newContent = pasteboard.string(forType: .string)

        // Restore original clipboard content
        pasteboard.clearContents()
        if let originalContent = originalContent {
            pasteboard.setString(originalContent, forType: .string)
        }

        // If we got new content different from original, return it
        if let newContent = newContent, newContent != originalContent, !newContent.isEmpty {
            return newContent
        }

        return nil
    }

    func insertText(_ text: String) {
        if let target = activeTarget {
            // If we have an active target (like custom instruction input), use it
            target.insertText(text)
        } else {
            SystemWideTarget().insertText(text)
        }
    }

    func updateText(_ text: String) {
        insertText(text)
    }
}

// MARK: - Built-in Targets

class CustomInstructionTarget: TextInsertionTarget {
    @Binding var instruction: String

    init(instruction: Binding<String>) {
        _instruction = instruction
    }

    func insertText(_ text: String) {
        instruction = text
    }
}

class SystemWideTarget: TextInsertionTarget {
    func insertText(_ text: String) {
        AccessibilityManager.shared.insertText(text)
    }
}
