import Foundation

class TranscriptionLogger {
    static let shared = TranscriptionLogger()

    private let fileManager = FileManager.default
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private var csvURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("transcription_logs.csv")
    }

    private init() {
        createCSVIfNeeded()
    }

    private func createCSVIfNeeded() {
        if !fileManager.fileExists(atPath: csvURL.path) {
            let header = "timestamp,app_context,raw_transcript,formatted_text\n"
            try? header.write(to: csvURL, atomically: true, encoding: .utf8)
        }
    }

    struct TranscriptionEntry: Codable {
        let timestamp: Date
        let appContext: String
        let rawTranscript: String
        let formattedText: String

        func toCSVLine() -> String {
            // Escape quotes and commas in the text fields
            let escapedRaw = rawTranscript.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedFormatted = formattedText.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedContext = appContext.replacingOccurrences(of: "\"", with: "\"\"")

            return
                "\"\(TranscriptionLogger.shared.dateFormatter.string(from: timestamp))\",\"\(escapedContext)\",\"\(escapedRaw)\",\"\(escapedFormatted)\"\n"
        }
    }

    func logTranscription(
        rawTranscript: String,
        formattedText: String,
        appContext: String = "unknown"
    ) {
        let entry = TranscriptionEntry(
            timestamp: Date(),
            appContext: appContext,
            rawTranscript: rawTranscript,
            formattedText: formattedText
        )

        do {
            let csvLine = entry.toCSVLine()
            if let data = csvLine.data(using: .utf8) {
                let fileHandle = try FileHandle(forWritingTo: csvURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
                print("Logged transcription to: \(csvURL.path)")
            }
        } catch {
            print("Error logging transcription: \(error.localizedDescription)")
        }
    }

    func getLogFileURL() -> URL {
        return csvURL
    }

    // Utility method to read all logs
    func readLogs() -> [TranscriptionEntry] {
        do {
            let content = try String(contentsOf: csvURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            // Skip header line and empty lines
            return lines.dropFirst().compactMap { line -> TranscriptionEntry? in
                let components = line.components(separatedBy: ",")
                guard components.count >= 4 else { return nil }

                // Remove quotes and unescape contents
                let timestamp = dateFormatter.date(from: components[0].trim("\"")) ?? Date()
                let context = components[1].trim("\"").replacingOccurrences(of: "\"\"", with: "\"")
                let raw = components[2].trim("\"").replacingOccurrences(of: "\"\"", with: "\"")
                let formatted = components[3].trim("\"").replacingOccurrences(
                    of: "\"\"", with: "\"")

                return TranscriptionEntry(
                    timestamp: timestamp,
                    appContext: context,
                    rawTranscript: raw,
                    formattedText: formatted
                )
            }
        } catch {
            print("Error reading logs: \(error.localizedDescription)")
            return []
        }
    }
}

// String extension for helper method
extension String {
    func trim(_ character: Character) -> String {
        return trimmingCharacters(in: CharacterSet(charactersIn: String(character)))
    }
}
