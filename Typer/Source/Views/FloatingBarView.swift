import AppKit
import ApplicationServices
import AVFoundation
import Carbon.HIToolbox.Events
import Cocoa
import CoreGraphics
import SwiftUI

struct IconButtonStyle: ButtonStyle {
    var isRecording: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20))
            .foregroundColor(isRecording ? .red.opacity(0.9) : .white)
            .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
}

struct LoadingDotsView: View {
    @State private var dotOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 3) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
                    .opacity(dotOffset == CGFloat(index) ? 1 : 0.3)
            }
        }
        .onAppear {
            withAnimation(Animation.linear(duration: 1).repeatForever()) {
                dotOffset = dotOffset < 2 ? dotOffset + 1 : 0
            }
        }
    }
}

struct FloatingBarView: View {
    @State private var isLoading = false
    @State private var isCommandMode = false
    @State private var isRecording = false
    @State private var isHovering = false
    @State private var audioRecorder: AVAudioRecorder?
    @StateObject private var audioMeter = AudioMeter()
    @State private var recordingDuration: TimeInterval = 0
    @State private var permissionGranted = false
    @State private var accessibilityEnabled = false
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var textService = TextService.shared
    @State private var showingStageBoard = false
    @State private var stageResult: String = ""
    @State private var stageWindow: NSWindow?

    private let transcriptor = Transcriptor()
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    let audioFilename: URL = {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("recording.m4a")
        FileManager.default.createFile(atPath: tempFile.path, contents: nil, attributes: nil)
        return tempFile
    }()

    var body: some View {
        ZStack {
            // Hover detection area
            Color.clear
                .frame(width: 120, height: 40)
                .contentShape(Rectangle())

            // Content
            if isLoading {
                // Loading state background
                Color(red: 29 / 255, green: 33 / 255, blue: 42 / 255)
                    .frame(width: 80, height: 40)
                    .cornerRadius(15)

                LoadingDotsView()
                    .frame(width: 40, height: 40)
            } else if isRecording || isHovering {
                // Active or hover state with buttons
                ZStack {
                    // This background will automatically size to the content
                    Color(red: 29 / 255, green: 33 / 255, blue: 42 / 255)
                        .cornerRadius(15)

                    HStack(spacing: 8) {
                        // Regular dictation button
                        if !isRecording || !isCommandMode {
                            Button(action: {
                                isCommandMode = false
                                if isRecording {
                                    stopRecording()
                                } else {
                                    startRecording()
                                }
                            }) {
                                Image(systemName: isRecording && !isCommandMode ? "stop.circle.fill" : "mic")
                                    .font(.system(size: 18))
                            }
                            .buttonStyle(IconButtonStyle(isRecording: isRecording && !isCommandMode))
                        }

                        // Command mode button
                        if !isRecording || isCommandMode {
                            Button(action: {
                                isCommandMode = true
                                if isRecording {
                                    stopRecording()
                                } else {
                                    startRecording()
                                }
                            }) {
                                Image(systemName: isRecording && isCommandMode ? "stop.circle.fill" : "sparkles")
                                    .font(.system(size: 18))
                            }
                            .buttonStyle(IconButtonStyle(isRecording: isRecording && isCommandMode))
                        }

                        if isRecording {
                            WaveformView(samples: audioMeter.soundSamples)
                                .frame(width: 50, height: 24)
                                .fixedSize()

                            // Cancel button instead of recording duration
                            Button(action: {
                                cancelRecording()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            // Vertical divider before custom prompt buttons
                            if !settings.customPrompts.filter(\.isEnabled).isEmpty {
                                Rectangle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 1, height: 18)
                                    .padding(.horizontal, 2)
                            }

                            // Custom prompt buttons - always show them
                            ForEach(settings.customPrompts.filter(\.isEnabled), id: \.id) { prompt in
                                Button(action: {
                                    performCustomPromptAction(prompt)
                                }) {
                                    Image(systemName: prompt.iconName)
                                        .font(.system(size: 18))
                                }
                                .buttonStyle(IconButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .frame(height: 40)
                .fixedSize(horizontal: true, vertical: false) // This makes the ZStack take the exact size needed by its content
            } else {
                // Inactive state - horizontal bar with white border
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 29 / 255, green: 33 / 255, blue: 42 / 255))
                    .frame(width: 40, height: 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .onTapGesture {
                        startRecording()
                    }
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeInOut(duration: 0.2), value: isRecording)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .onReceive(timer) { _ in
            if isRecording {
                recordingDuration += 0.1
            }
        }
        .onAppear {
            monitorFnKey()
        }
    }

    func startRecording() {
        print("Start recording to: \(audioFilename)")

        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC), // Audio format
            AVSampleRateKey: 12_000, // Sample rate
            AVNumberOfChannelsKey: 1, // Number of channels
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue, // Audio quality
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true
            print("Started recording to: \(audioFilename)")
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }

        audioMeter.startMonitoring(audioRecorder!)
        recordingDuration = 0
    }

    func stopRecording() {
        print("Stop recording")

        audioMeter.stopMonitoring()
        recordingDuration = 0

        let recordingDuration = audioRecorder?.currentTime ?? 0
        audioRecorder?.stop()
        isRecording = false

        // Dismiss if recording is too short
        if recordingDuration < 0.5 {
            print("Recording too short, discarding")
            return
        }

        // Log file information
        // Enable this line to log recording for development purposes
        // logRecordingInfo()

        // Start transcription process
        Task {
            do {
                isLoading = true
                let transcribedText = try await transcriptor.transcribe(audioFile: audioFilename)
                await MainActor.run {
                    print("Transcribed text: \(transcribedText)")
                    handleTranscribedText(transcribedText)
                }
            } catch {
                print("Transcription failed: \(error)")
                isLoading = false
            }
        }
    }

    private func logRecordingInfo() {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: audioFilename.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            print("Recording stopped")
            print("File exists: \(FileManager.default.fileExists(atPath: audioFilename.path))")
            print("File size: \(fileSize) bytes")
            print("File path: \(audioFilename.path)")
        } catch {
            print("Error getting file attributes: \(error.localizedDescription)")
        }
    }

    func monitorFnKey() {
        let _ = KeyStateModel.shared
        NotificationCenter.default.addObserver(
            forName: .keyStateChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let state = notification.userInfo?["state"] as? KeyState {
                if settings.handfreeMode {
                    if state == .keyDown {
                        if self.isRecording {
                            self.stopRecording()
                        } else {
                            self.startRecording()
                        }
                    }
                } else {
                    if state == .keyDown {
                        if !self.isRecording {
                            self.startRecording()
                        }
                    } else if state == .keyUp {
                        if self.isRecording {
                            self.stopRecording()
                        }
                    }
                }
            }
        }
    }

    private func handleTranscribedText(_ text: String) {
        if isCommandMode {
            Task {
                if let selectedText = textService.getSelectedText() {
                    do {
                        isLoading = true
                        let result = try await getAIResponse(selectedText, instruction: text)

                        await MainActor.run {
                            showStageBoard(with: result)
                            isRecording = false
                            isCommandMode = false
                            isLoading = false
                        }
                    } catch {
                        print("AI request failed: \(error)")
                        isLoading = false
                    }
                } else {
                    print("No context can be found during command mode.")
                    isLoading = false
                }
            }
        } else {
            textService.insertText(text)
            isLoading = false
        }
    }

    private func getAIResponse(_ context: String, instruction: String) async throws -> String {
        let settings = SettingsManager.shared
        let serviceType: AIServiceType
        let apiKey: String

        // Choose service type and API key based on settings
        if !settings.typerApiKey.isEmpty {
            serviceType = .typer
            apiKey = settings.typerApiKey
        } else if !settings.openaiApiKey.isEmpty {
            serviceType = .openai
            apiKey = settings.openaiApiKey
        } else {
            // Default to typer with empty key (will fail gracefully)
            serviceType = .typer
            apiKey = ""
        }

        return try await withCheckedThrowingContinuation { continuation in
            AIService.shared.transform(
                context: context,
                instruction: instruction,
                serviceType: serviceType,
                apiKey: apiKey
            ) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func performCustomPromptAction(_ prompt: CustomPrompt) {
        print("Performing action for custom prompt: \(prompt.title)")
        Task {
            if let selectedText = textService.getSelectedText() {
                do {
                    isLoading = true

                    // Replace {{text}} placeholder with selected text
                    let userPrompt = prompt.userPrompt.replacingOccurrences(of: "{{text}}", with: selectedText)
                    let result = try await getAIResponse(
                        userPrompt,
                        instruction: prompt.systemPrompt
                    )

                    await MainActor.run {
                        showStageBoard(with: result)
                        isLoading = false
                    }
                } catch {
                    print("AI request failed: \(error)")
                    isLoading = false
                }
            }
        }
    }

    private func cancelRecording() {
        print("Recording cancelled")

        audioMeter.stopMonitoring()
        recordingDuration = 0

        // Simply stop the recorder without starting transcription
        audioRecorder?.stop()
        isRecording = false
        isCommandMode = false
    }

    private func showStageBoard(with result: String) {
        stageResult = result

        // Store the current focused app/window for later use
        let focusedApp = NSWorkspace.shared.frontmostApplication
        let focusedWindow = getFocusedWindow()

        // Create and configure window if it doesn't exist
        if stageWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
                styleMask: [.borderless, .nonactivatingPanel], // nonactivatingPanel is key here
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.backgroundColor = .clear
            window.isOpaque = false
            window.alphaValue = 0.9
            window.hasShadow = true
            window.isMovable = true
            window.isMovableByWindowBackground = true
            stageWindow = window
        }

        // Update window content
        stageWindow?.contentView = NSHostingView(rootView: ResultStageView(
            result: result,
            onApply: {
                // Reactivate the original app before updating text
                focusedApp?.activate(options: .activateIgnoringOtherApps)

                // Small delay to ensure focus is restored
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textService.updateText(result)
                    stageWindow?.close()
                }
            },
            onCancel: {
                focusedApp?.activate(options: .activateIgnoringOtherApps)
                stageWindow?.close()
            }
        ))

        // Position window near the cursor
        if let screenFrame = NSScreen.main?.visibleFrame,
           let window = stageWindow
        {
            let mouseLocation = NSEvent.mouseLocation
            var windowFrame = window.frame

            // Position the window below and to the right of the cursor
            windowFrame.origin.x = min(mouseLocation.x, screenFrame.maxX - windowFrame.width)
            windowFrame.origin.y = max(mouseLocation.y - windowFrame.height, screenFrame.minY)

            window.setFrame(windowFrame, display: true)
        }

        stageWindow?.makeKeyAndOrderFront(nil)
    }

    // Helper function to get focused window
    private func getFocusedWindow() -> NSWindow? {
        return NSApplication.shared.windows.first { $0.isKeyWindow }
    }
}
