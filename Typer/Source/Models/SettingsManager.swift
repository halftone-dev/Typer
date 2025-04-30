import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    static let modelName = "large-v3_turbo"
    @Published var localModelStatus: LocalModelStatus = .notDownloaded
    @Published var downloadProgress: Float = 0.0

    static let shared = SettingsManager()

    @Published var useLocalModel: Bool {
        didSet {
            UserDefaults.standard.set(useLocalModel, forKey: "useLocalModel")
            NotificationCenter.default.post(
                name: NSNotification.Name("UseLocalModelChanged"),
                object: nil
            )
        }
    }

    @Published var handfreeMode: Bool {
        didSet {
            UserDefaults.standard.set(handfreeMode, forKey: "handfreeMode")
        }
    }

    @Published var recordingHotkey: HotKeyCode {
        didSet {
            if let encoded = try? JSONEncoder().encode(recordingHotkey) {
                UserDefaults.standard.set(encoded, forKey: "recordingHotkey")
            }
        }
    }

    @Published var hideFromDock: Bool {
        didSet {
            UserDefaults.standard.set(hideFromDock, forKey: "hideFromDock")
        }
    }

    @Published var customPrompts: [CustomPrompt] {
        didSet {
            if let encoded = try? JSONEncoder().encode(customPrompts) {
                UserDefaults.standard.set(encoded, forKey: "customPrompts")
            }
        }
    }

    @Published var typerApiKey: String {
        didSet {
            UserDefaults.standard.set(typerApiKey, forKey: "typerApiKey")
        }
    }

    @Published var openaiApiKey: String {
        didSet {
            UserDefaults.standard.set(openaiApiKey, forKey: "openaiApiKey")
        }
    }

    @Published var transcriptionService: TranscriptionServiceType {
        didSet {
            UserDefaults.standard.set(transcriptionService.rawValue, forKey: "transcriptionService")
            NotificationCenter.default.post(
                name: NSNotification.Name("TranscriptionServiceChanged"),
                object: nil
            )
        }
    }

    enum LocalModelStatus {
        case notDownloaded
        case downloading
        case downloaded(URL)
        case error(String)
    }

    enum TranscriptionServiceType: String, CaseIterable {
        case typer
        case openai
        case local

        var displayName: String {
            switch self {
            case .typer: return "Typer"
            case .openai: return "OpenAI"
            case .local: return "Local"
            }
        }

        var description: String {
            switch self {
            case .typer: return "Default remote service (requires API key)"
            case .openai: return "OpenAI API (requires API key)"
            case .local: return "On-device transcription (no internet required)"
            }
        }

        var icon: String {
            switch self {
            case .typer: return "cloud"
            case .openai: return "sparkles"
            case .local: return "desktopcomputer"
            }
        }
    }

    private init() {
        handfreeMode = UserDefaults.standard.bool(forKey: "handfreeMode")
        hideFromDock = UserDefaults.standard.bool(forKey: "hideFromDock")
        useLocalModel =
            UserDefaults.standard.bool(forKey: "useLocalModel") && Self.findExistingModel() != nil
        if let data = UserDefaults.standard.data(forKey: "recordingHotkey"),
           let decoded = try? JSONDecoder().decode(HotKeyCode.self, from: data)
        {
            recordingHotkey = decoded
        } else {
            // Use function key as default
            recordingHotkey = HotKeyCode(keyCode: 0x3F, modifierFlags: nil)
        }

        if let promptsData = UserDefaults.standard.data(forKey: "customPrompts"),
           let decodedPrompts = try? JSONDecoder().decode([CustomPrompt].self, from: promptsData)
        {
            customPrompts = decodedPrompts
        } else {
            // Default prompts
            customPrompts = [
                CustomPrompt(
                    title: "Improve",
                    systemPrompt: "You are a professional editor who improves writing quality.",
                    userPrompt: "Please improve this text for clarity and readability and only return the polished text:\n\n{{text}}",
                    iconName: "wand.and.stars",
                    isEnabled: true
                ),
            ]
        }

        if let apiKey = UserDefaults.standard.string(forKey: "typerApiKey") {
            typerApiKey = apiKey
        } else {
            typerApiKey = ""
        }

        if let apiKey = UserDefaults.standard.string(forKey: "openaiApiKey") {
            openaiApiKey = apiKey
        } else {
            openaiApiKey = ""
        }

        if let service = UserDefaults.standard.string(forKey: "transcriptionService"),
           let transcriptionService = TranscriptionServiceType(rawValue: service)
        {
            self.transcriptionService = transcriptionService
        } else {
            transcriptionService = .typer
        }
    }

    func checkLocalModelStatus() {
        if let modelPath = Self.findExistingModel() {
            localModelStatus = .downloaded(modelPath)
        } else {
            localModelStatus = .notDownloaded
        }
    }

    static func findExistingModel() -> URL? {
        guard let cacheBaseDir = modelDirectory else { return nil }

        let modelPath =
            cacheBaseDir
                .appendingPathComponent("models")
                .appendingPathComponent("argmaxinc")
                .appendingPathComponent("whisperkit-coreml")
                .appendingPathComponent("openai_whisper-\(modelName)")

        // Check if required model files exist
        let requiredFiles = [
            "AudioEncoder.mlmodelc",
            "MelSpectrogram.mlmodelc",
            "TextDecoder.mlmodelc",
            "TextDecoderContextPrefill.mlmodelc",
            "config.json",
            "generation_config.json",
        ]

        let allFilesExist = requiredFiles.allSatisfy { filename in
            FileManager.default.fileExists(atPath: modelPath.appendingPathComponent(filename).path)
        }

        return allFilesExist ? modelPath : nil
    }

    static var modelDirectory: URL? {
        // Get home directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        // HuggingFace cache directory
        return
            homeDir
                .appendingPathComponent(".cache")
                .appendingPathComponent("huggingface")
    }
}
