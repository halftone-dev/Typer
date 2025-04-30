import SwiftUI
import WhisperKit

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            KeysSettingsView()
                .tabItem {
                    Label("Keys", systemImage: "keyboard")
                }
            PromptsSettingsView()
                .tabItem {
                    Label("Prompts", systemImage: "text.bubble")
                }
            ModelsSettingsView()
                .tabItem {
                    Label("API", systemImage: "network")
                }
        }
        .padding()
        .frame(width: 600, height: 400) // Increased width and height to accommodate the PromptsSettingsView
        .accentColor(.blue)
        .onAppear {
            /// This snippet locates the first window titled "Settings" from the available windows.
            /// - Note: When we bump the minimum development target to 15, remember to update
            ///         this setting in the Typer app to use the window level modifier.
            if let window = NSApplication.shared.windows.first(where: { $0.title == "Settings" }) {
                window.level = .floating
            }
        }
    }
}

/// "General" tab
struct GeneralSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Toggle("Hands-Free Mode", isOn: $settings.handfreeMode)
            Text("Press the selected hotkey once to start recording and again to stop.")
                .font(.caption)
                .foregroundColor(.gray)

            Toggle("Hide Typer app icon from the Dock", isOn: $settings.hideFromDock)
            Text("The app will only show on status bar. Restart the app to apply this change.")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .navigationTitle("Settings")
    }
}

/// "Keys" tab
struct KeysSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Text("Select a hotkey to use:")
                .font(.headline)
            RecordHotkeyButton(hotkey: $settings.recordingHotkey)
            // Additional key-related settings here
            Text("Press and hold the selected key (or tap once in Handsfree Mode) to record.")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .navigationTitle("Settings")
    }
}

/// "Models" tab
struct ModelsSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showTyperApiKey = false
    @State private var showOpenAIApiKey = false

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 5) {
                Group {
                    Text("Service Provider")
                        .font(.headline)

                    ForEach(SettingsManager.TranscriptionServiceType.allCases, id: \.self) { service in
                        Button(action: {
                            settings.transcriptionService = service
                        }) {
                            HStack {
                                Image(systemName: service.icon)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(service.displayName)
                                        .fontWeight(.medium)
                                    Text(service.description)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if settings.transcriptionService == service {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 4)
                    }
                }

                Divider()

                // Show API key configuration based on selected service
                if settings.transcriptionService == .typer {
                    apiKeySection(
                        title: "Typer API Key",
                        apiKey: $settings.typerApiKey,
                        showKey: $showTyperApiKey
                    )
                } else if settings.transcriptionService == .openai {
                    apiKeySection(
                        title: "OpenAI API Key",
                        apiKey: $settings.openaiApiKey,
                        showKey: $showOpenAIApiKey
                    )
                }

                if settings.transcriptionService == .local {
                    Group {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Note:")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Text("Local model only supports transcription and does not support prompts functionality (such as reformatting content with given prompt).")
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 5)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)

                        // Local Model Status section
                        Text("Local Model Status:")
                            .font(.headline)
                            .padding(.top, 5)

                        switch settings.localModelStatus {
                        case .notDownloaded:
                            HStack {
                                Text("Not Downloaded")
                                    .foregroundColor(.red)
                                Spacer()
                                Button("Download") {
                                    downloadModel()
                                }
                                .buttonStyle(.borderedProminent)
                            }

                        case .downloading:
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Downloading...")
                                ProgressView(value: settings.downloadProgress) {
                                    Text("\(Int(settings.downloadProgress * 100))%")
                                }
                            }

                        case let .downloaded(url):
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Downloaded")
                                    .foregroundColor(.green)
                                Text(url.path)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                        case let .error(message):
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Error: \(message)")
                                    .foregroundColor(.red)
                                Button("Retry Download") {
                                    downloadModel()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 5)
        }
        .onAppear {
            checkModelStatus()
        }
        .padding()
        .navigationTitle("API")
    }

    @ViewBuilder
    private func apiKeySection(title: String, apiKey: Binding<String>, showKey: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .fontWeight(.medium)

            HStack {
                if showKey.wrappedValue {
                    TextField("Enter API Key", text: apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    SecureField("Enter API Key", text: apiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Button(action: {
                    showKey.wrappedValue.toggle()
                }) {
                    Image(systemName: showKey.wrappedValue ? "eye.slash" : "eye")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }

            Text("Required for using selected service")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 5)
    }

    private var isModelAvailable: Bool {
        if case .downloaded = settings.localModelStatus {
            return true
        }
        return false
    }

    private func checkModelStatus() {
        settings.checkLocalModelStatus()
    }

    private func downloadModel() {
        settings.localModelStatus = .downloading

        Task {
            do {
                let modelUrl = try await WhisperKit.download(
                    variant: SettingsManager.modelName,
                    downloadBase: SettingsManager.modelDirectory,
                    useBackgroundSession: false
                ) { progress in
                    DispatchQueue.main.async {
                        settings.downloadProgress = Float(progress.fractionCompleted)
                    }
                }

                await MainActor.run {
                    settings.localModelStatus = .downloaded(modelUrl)
                }
            } catch {
                await MainActor.run {
                    settings.localModelStatus = .error(error.localizedDescription)
                }
            }
        }
    }
}
