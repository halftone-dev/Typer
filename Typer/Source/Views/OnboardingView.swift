import AVFoundation
import SwiftUI

struct OnboardingView: View {
    @State private var microphoneGranted = false
    @State private var accessibilityGranted = false
    @Environment(\.dismiss) var dismiss

    // Add observer for app activation
    @State private var observer: Any?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Welcome to Typer!")
                .font(.title2)
                .bold()

            Text("Before you can enjoy Typer, we need to ask you for permissions.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 16) {
                PermissionRow(
                    icon: "mic",
                    title: "Microphone Permission",
                    description: "Typer needs microphone access to record your voice for transcription.",
                    isGranted: microphoneGranted,
                    action: openSystemPreferencesForMicrophonePermission
                )

                PermissionRow(
                    icon: "keyboard",
                    title: "Accessibility Permission",
                    description: "Typer needs accessibility access to type text for you.",
                    isGranted: accessibilityGranted,
                    action: openSystemPreferencesForAccessibility
                )
            }
            .padding()

            Spacer()

            VStack(spacing: 12) {
                Button(action: completeOnboarding) {
                    Text("Let's Start!")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!microphoneGranted || !accessibilityGranted)
            }
            .padding()
            .padding(.bottom, 12) // Add extra bottom padding
        }
        .accentColor(.blue)
        .frame(width: 400, height: 600)
        .onAppear {
            checkPermissions()
            setupObserver()
        }
        .onDisappear {
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    private func checkPermissions() {
        // Check microphone permission
        microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

        // Check accessibility permission
        accessibilityGranted = AccessibilityManager.shared.checkAccessibilityPermissions()
    }

    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                microphoneGranted = granted
            }
        }
    }

    private func setupObserver() {
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            checkPermissions()
        }
    }

    private func openSystemPreferencesForMicrophonePermission() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    private func openSystemPreferencesForAccessibility() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func completeOnboarding() {
        if microphoneGranted && accessibilityGranted {
            // Close onboarding window
            dismiss()

            // Post notification to show floating bar
            NotificationCenter.default.post(name: Notification.Name("ShowFloatingBar"), object: nil)
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isGranted ? .green : .gray)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !isGranted {
                    Button(action: action) {
                        Text("Grant Access")
                            .font(.subheadline)
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()

            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGranted ? .green : .red)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
