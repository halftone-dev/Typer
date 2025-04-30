import AVFoundation
import Foundation
import WhisperKit

enum TranscriptionError: Error {
    case pipelineNotInitialized
    case noTranscriptionResult
    case invalidConfiguration
    case modelsUnavailable
    case missingAPIKey(String)
}

protocol TranscriptionService {
    func transcribe(audioFile: URL) async throws -> String
}

class LocalTranscriptionService: TranscriptionService {
    private var whisperPipeline: WhisperKit?
    private var settingsObserver: Any?

    init() {
        // Start initialization if local model is selected as transcription service
        if SettingsManager.shared.transcriptionService == .local {
            Task {
                try? await initializeWhisperKit()
            }
        }

        // Observe settings changes
        settingsObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TranscriptionServiceChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                if SettingsManager.shared.transcriptionService == .local {
                    try? await self?.initializeWhisperKit()
                } else {
                    await self?.cleanup()
                }
            }
        }
    }

    deinit {
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func initializeWhisperKit() async throws {
        // Only initialize if not already initialized
        if whisperPipeline == nil {
            guard let modelPath = SettingsManager.findExistingModel() else {
                throw TranscriptionError.modelsUnavailable
            }

            let config = WhisperKitConfig(
                modelFolder: modelPath.path,
                load: true, // Ensure model loading
                download: false // Prevent automatic download
            )

            whisperPipeline = try await WhisperKit(config)
            print("WhisperKit initialized successfully with model path: \(modelPath.path)")
        }
    }

    private func cleanup() async {
        await whisperPipeline?.unloadModels()
        whisperPipeline = nil
        print("WhisperKit unloaded")
    }

    func transcribe(audioFile: URL) async throws -> String {
        guard SettingsManager.shared.transcriptionService == .local else {
            throw TranscriptionError.invalidConfiguration
        }

        // Initialize WhisperKit if needed
        if whisperPipeline == nil {
            try await initializeWhisperKit()
        }

        guard let pipeline = whisperPipeline else {
            throw TranscriptionError.pipelineNotInitialized
        }
        // let (language, langProbs) = try await pipeline.detectLangauge(
        //    audioArray: try AudioProcessor.loadAudioAsFloatArray(fromPath: audioFile.path)
        // )
        // print("Detected language: \(language)")
        // print("Language probabilities: \(langProbs)")

        let decodeOptions = DecodingOptions(
            task: .transcribe,
            language: nil,
            temperature: 0,
            usePrefillPrompt: false,
            usePrefillCache: false,
            detectLanguage: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            wordTimestamps: false,
            maxInitialTimestamp: nil,
            clipTimestamps: [],
            promptTokens: nil,
            prefixTokens: nil,
            suppressBlank: true,
            supressTokens: [],
            compressionRatioThreshold: nil,
            logProbThreshold: nil,
            firstTokenLogProbThreshold: nil,
            noSpeechThreshold: nil,
            concurrentWorkerCount: 1,
            chunkingStrategy: nil
        )

        let transcriptionResults = try await pipeline.transcribe(
            audioPath: audioFile.path,
            decodeOptions: decodeOptions
        )

        guard let transcription = transcriptionResults.first?.text else {
            throw TranscriptionError.noTranscriptionResult
        }

        return transcription
    }
}

class RemoteTranscriptionService: TranscriptionService {
    private let settings: SettingsManager

    init(settings: SettingsManager = .shared) {
        self.settings = settings
    }

    func transcribe(audioFile: URL) async throws -> String {
        // Determine service type based on settings
        let serviceType: AIServiceType
        let apiKey: String

        switch settings.transcriptionService {
        case .typer:
            serviceType = .typer
            guard !settings.typerApiKey.isEmpty else {
                throw TranscriptionError.missingAPIKey("Typer.to")
            }
            apiKey = settings.typerApiKey

        case .openai:
            serviceType = .openai
            guard !settings.openaiApiKey.isEmpty else {
                throw TranscriptionError.missingAPIKey("OpenAI")
            }
            apiKey = settings.openaiApiKey

        case .local:
            throw TranscriptionError.invalidConfiguration
        }

        return try await withCheckedThrowingContinuation { continuation in
            AIService.shared.transcribeAudio(
                from: audioFile,
                serviceType: serviceType,
                apiKey: apiKey
            ) { result in
                continuation.resume(with: result)
            }
        }
    }
}

class Transcriptor {
    private let localService: LocalTranscriptionService
    private let remoteService: RemoteTranscriptionService
    private let settings: SettingsManager
    private var serviceObserver: Any?

    init(settings: SettingsManager = .shared) {
        self.settings = settings
        localService = LocalTranscriptionService()
        remoteService = RemoteTranscriptionService(settings: settings)

        // Observe transcription service changes
        serviceObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TranscriptionServiceChanged"),
            object: nil,
            queue: .main
        ) { _ in
            print("Transcription service changed to: \(settings.transcriptionService.displayName)")
        }
    }

    deinit {
        if let observer = serviceObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func transcribe(audioFile: URL) async throws -> String {
        if settings.transcriptionService == .local {
            // Check if model is available before attempting to use it
            if case .downloaded = settings.localModelStatus {
                return try await localService.transcribe(audioFile: audioFile)
            } else {
                throw TranscriptionError.modelsUnavailable
            }
        } else {
            return try await remoteService.transcribe(audioFile: audioFile)
        }
    }
}
