import AppKit
import Carbon
import Foundation

struct HotKeyCode: Codable, Equatable {
    var isSingleKey: Bool {
        let parts = description.components(separatedBy: " + ")
        return parts.count == 1
    }

    let keyCode: UInt16
    let modifierFlags: NSEvent.ModifierFlags?

    private enum CodingKeys: String, CodingKey {
        case modifierFlags
        case keyCode
    }

    init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags? = nil) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags?.intersection(.deviceIndependentFlagsMask)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        if let rawValue = try container.decodeIfPresent(UInt.self, forKey: .modifierFlags) {
            modifierFlags = NSEvent.ModifierFlags(rawValue: rawValue)
        } else {
            modifierFlags = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        if let flags = modifierFlags {
            try container.encode(flags.rawValue, forKey: .modifierFlags)
        }
    }

    var description: String {
        var parts: [String] = []
        if let flags = modifierFlags {
            if flags.contains(.command) { parts.append("⌘") }
            if flags.contains(.option) { parts.append("⌥") }
            if flags.contains(.control) { parts.append("⌃") }
            if flags.contains(.shift) { parts.append("⇧") }
            if flags.contains(.function) { parts.append("Fn") }
        }
        if let keyString = keyCodeToString(keyCode), !parts.contains(keyString) {
            parts.append(keyString)
        }
        return parts.isEmpty ? "None" : parts.joined(separator: " + ")
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Control: return "⌃"
        case kVK_Command: return "⌘"
        case kVK_Shift: return "⇧"
        case kVK_Option: return "⌥"
        case kVK_Function: return "Fn"
        case kVK_RightControl: return "⌃"
        case kVK_RightCommand: return "⌘"
        case kVK_RightShift: return "⇧"
        case kVK_RightOption: return "⌥"
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        default: return nil
        }
    }

    static func == (lhs: HotKeyCode, rhs: HotKeyCode) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.modifierFlags == rhs.modifierFlags
    }
}

enum KeyState {
    case listening
    case keyDown
    case keyUp
}

extension Notification.Name {
    static let keyStateChanged = Notification.Name("keyStateChanged")
}

class KeyStateModel: ObservableObject {
    static let shared = KeyStateModel()
    @Published private(set) var state: KeyState = .listening {
        didSet {
            NotificationCenter.default.post(
                name: .keyStateChanged,
                object: self,
                userInfo: ["state": state]
            )
        }
    }

    private let settings: SettingsManager

    init(settings: SettingsManager = .shared) {
        self.settings = settings
        setupKeyMonitor()
    }

    private func setupKeyMonitor() {
        // Global monitor for when app is not focused
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) {
            [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor for when app is focused
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) {
            [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let currentFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hotkey = settings.recordingHotkey

        switch event.type {
        case .keyDown:
            handleKeyDown(flags: currentFlags, keyCode: event.keyCode, hotkey: hotkey)
        case .keyUp:
            handleKeyUp(flags: currentFlags, keyCode: event.keyCode, hotkey: hotkey)
        case .flagsChanged:
            handleFlagsChanged(flags: currentFlags, keyCode: event.keyCode, hotkey: hotkey)
        default:
            break
        }
    }

    private func handleKeyDown(flags: NSEvent.ModifierFlags, keyCode: UInt16, hotkey: HotKeyCode) {
        switch state {
        case .listening:
            if hotkey.keyCode == keyCode && flags == hotkey.modifierFlags {
                state = .keyDown
            }
        default:
            break
        }
    }

    private func handleKeyUp(flags: NSEvent.ModifierFlags, keyCode: UInt16, hotkey: HotKeyCode) {
        guard state == .keyDown else { return }

        let hotkeyCode = HotKeyCode(keyCode: keyCode, modifierFlags: flags)

        if hotkeyCode == hotkey {
            transitionToKeyUp()
        }
    }

    private func handleFlagsChanged(flags: NSEvent.ModifierFlags, keyCode: UInt16, hotkey: HotKeyCode) {
        if !hotkey.isSingleKey {
            if state == .keyDown && flags == hotkey.modifierFlags {
                transitionToKeyUp()
            }
        } else {
            if state == .keyDown && keyCode == hotkey.keyCode {
                transitionToKeyUp()
            } else if state == .listening && keyCode == hotkey.keyCode {
                state = .keyDown
            }
        }
    }

    private func transitionToKeyUp() {
        state = .keyUp
        DispatchQueue.main.async { [weak self] in
            self?.state = .listening
        }
    }
}
