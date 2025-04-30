import SwiftUI

@main
struct TyperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var updaterViewModel = UpdaterViewModel()
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showExportSuccess = false
    @State private var exportError: String?

    var body: some Scene {
        MenuBarExtra("Typer", image: "typer") {
            Button("About Typer") {
                NSApp.orderFrontStandardAboutPanel()
            }
            Button("Check for Updates...", action: updaterViewModel.checkForUpdates)
            Divider()

            // Use SettingsLink for macOS 14+, fallback to Button for macOS 13
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Text("Settings")
                }
            } else {
                Button("Settings") {
                    openSettings()
                }
            }

            Divider()
            Button("Export Log Report...") {
                exportLog()
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }

        Settings {
            SettingsView()
        }
    }

    // This function manually opens the settings window for macOS 13
    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)

        // If the above doesn't work, try this alternative approach
        if NSApp.windows.first(where: { $0.title == "Settings" }) == nil {
            let settingsWindowController = NSWindowController(
                window: NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                    styleMask: [.titled, .closable, .resizable],
                    backing: .buffered,
                    defer: false
                )
            )

            settingsWindowController.window?.contentView = NSHostingView(rootView: SettingsView())
            settingsWindowController.window?.title = "Settings"
            settingsWindowController.window?.level = .floating
            settingsWindowController.window?.center()
            settingsWindowController.showWindow(nil)
        }
    }

    private func exportLog() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.text]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "typer-log-\(Date().ISO8601Format()).txt"

        savePanel.begin { result in
            if result == .OK {
                let sourceURL = Logger.shared.getLogFileURL()
                if let destinationURL = savePanel.url {
                    do {
                        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                        showExportSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showExportSuccess = false
                        }
                    } catch {
                        exportError = error.localizedDescription
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            exportError = nil
                        }
                    }
                }
            }
        }
    }
}
