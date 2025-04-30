import Foundation

final class Logger {
    static let shared = Logger()
    private let logFile: URL
    private var fileHandle: FileHandle?
    private let dateFormatter: DateFormatter

    private init() {
        let logDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Typer")
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)

        logFile = logDirectory.appendingPathComponent("typer.log")
        if !FileManager.default.fileExists(atPath: logFile.path) {
            FileManager.default.createFile(atPath: logFile.path, contents: nil)
        }

        fileHandle = try? FileHandle(forWritingTo: logFile)

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }

    func debug(_ message: String, file: String = #file, line: Int = #line) {
        log(message, level: "DEBUG", file: file, line: line)
    }

    func info(_ message: String, file: String = #file, line: Int = #line) {
        log(message, level: "INFO", file: file, line: line)
    }

    func error(_ message: String, file: String = #file, line: Int = #line) {
        log(message, level: "ERROR", file: file, line: line)
    }

    private func log(_ message: String, level: String, file: String, line: Int) {
        let timestamp = dateFormatter.string(from: Date())
        let filename = (file as NSString).lastPathComponent
        let logMessage = "\(timestamp) [\(level)] [\(filename):\(line)] \(message)\n"

        fileHandle?.write(logMessage.data(using: .utf8) ?? Data())
    }

    func getLogFileURL() -> URL {
        return logFile
    }

    deinit {
        fileHandle?.closeFile()
    }
}
