import SwiftUI

struct RecordHotkeyButton: View {
    @Binding var hotkey: HotKeyCode
    @State private var isRecording = false

    var body: some View {
        Group {
            if isRecording {
                KeyRecorder(hotkey: $hotkey, isRecording: $isRecording)
                    .frame(height: 30)
                    .padding(.horizontal, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
            } else {
                Button(action: { isRecording = true }) {
                    HStack {
                        Text(hotkey.description)
                        Spacer()
                    }
                    .frame(height: 30)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct KeyRecorder: View {
    @Binding var hotkey: HotKeyCode
    @Binding var isRecording: Bool
    @StateObject private var keyState = KeyStateModel.shared
    @State private var currentHotKey: HotKeyCode?
    @State private var isPending: Bool = false

    var body: some View {
        Text(currentHotKey == nil ? "Press keys now" : currentHotKey?.description ?? "")
            .foregroundColor(currentHotKey == nil ? .gray : .primary)
            .frame(maxWidth: .infinity)
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
                    handleKeyEvent(event)
                    return nil
                }
            }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecording else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode

        switch event.type {
        case .flagsChanged:
            if !isPending {
                currentHotKey = HotKeyCode(keyCode: keyCode, modifierFlags: flags)
                isPending = true
            } else {
                if let current = currentHotKey {
                    hotkey = current
                    isPending = false
                    isRecording = false
                }
            }
        case .keyDown:
            if !flags.isEmpty {
                currentHotKey = HotKeyCode(keyCode: keyCode, modifierFlags: flags)
            }
        case .keyUp:
            if let current = currentHotKey, keyCode == current.keyCode {
                hotkey = current
                isPending = false
                isRecording = false
            }
        default:
            break
        }
    }
}
