import AppKit
import AVFoundation
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var panel: NSPanel!
    var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_: Notification) {
        // Check permissions first
        let microphoneGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let accessibilityGranted = AccessibilityManager.shared.checkAccessibilityPermissions()

        // Show onboarding and hide panel if permissions aren't granted
        if !microphoneGranted || !accessibilityGranted {
            showOnboarding()
            setupFloatingPanel()
            panel?.orderOut(nil) // Hide the panel initially
        } else {
            setupFloatingPanel()
            panel?.orderFront(nil)
        }

        // Add observer for showing floating bar
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showFloatingBar),
            name: Notification.Name("ShowFloatingBar"),
            object: nil
        )
    }

    @objc private func showFloatingBar() {
        panel?.orderFront(nil)
    }

    private func setupFloatingPanel() {
        // Set activation policy based on settings
        NSApp.setActivationPolicy(
            SettingsManager.shared.hideFromDock ? .accessory : .regular
        )

        let contentView = FloatingBarView()

        // Get main screen dimensions
        let screenRect = NSScreen.main?.visibleFrame ?? .zero
        let panelWidth: CGFloat = 120
        let panelHeight: CGFloat = 40
        let padding: CGFloat = 10

        // Calculate center-top position
        let initialRect = NSRect(
            x: (screenRect.width - panelWidth) / 2 + screenRect.minX,
            y: screenRect.maxY - panelHeight - padding,
            width: panelWidth,
            height: panelHeight
        )

        panel = NSPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )

        panel.isFloatingPanel = true
        panel.isMovable = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.alphaValue = 0.8
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        panel.contentView = NSHostingView(rootView: contentView)
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
        panel.titleVisibility = .hidden

        // Load saved window frame
        if let savedFrame = UserDefaults.standard.string(forKey: "windowFrame") {
            panel.setFrame(NSRectFromString(savedFrame), display: true)
        }
    }

    func windowDidMove(_: Notification) {
        let frameString = NSStringFromRect(panel.frame)
        UserDefaults.standard.set(frameString, forKey: "windowFrame")
    }

    private func showOnboarding() {
        let onboardingView = OnboardingView()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.contentView = NSHostingView(rootView: onboardingView)
        window.title = "Welcome to Typer"
        window.makeKeyAndOrderFront(nil)

        onboardingWindow = window
    }
}
