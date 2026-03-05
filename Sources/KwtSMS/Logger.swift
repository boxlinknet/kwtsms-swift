import Foundation

/// A single JSONL log entry for an API call.
struct LogEntry: Codable {
    let ts: String
    let endpoint: String
    let request: [String: String]
    let response: String
    let ok: Bool
    let error: String?
}

/// Mask the password field in an API request payload.
///
/// - Parameter payload: The original request dictionary.
/// - Returns: A copy with "password" replaced by "***".
func maskCredentials(_ payload: [String: Any]) -> [String: String] {
    var masked: [String: String] = [:]
    for (key, value) in payload {
        if key == "password" {
            masked[key] = "***"
        } else {
            masked[key] = "\(value)"
        }
    }
    return masked
}

/// Write a JSONL log entry to the specified log file.
///
/// Never throws or crashes the main flow. If writing fails (disk full, permissions, etc.),
/// the error is silently swallowed.
///
/// - Parameters:
///   - logFile: Path to the log file. If empty, logging is skipped.
///   - endpoint: The API endpoint name (e.g. "send", "balance").
///   - request: The request payload (password will be masked).
///   - responseBody: The raw response body string.
///   - ok: Whether the API call was successful.
///   - errorMessage: Optional error message for network/parse failures.
func writeLog(
    logFile: String,
    endpoint: String,
    request: [String: Any],
    responseBody: String,
    ok: Bool,
    errorMessage: String?
) {
    guard !logFile.isEmpty else { return }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let ts = formatter.string(from: Date())

    let entry = LogEntry(
        ts: ts,
        endpoint: endpoint,
        request: maskCredentials(request),
        response: responseBody,
        ok: ok,
        error: errorMessage
    )

    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(entry)
        guard var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"

        let url: URL
        if logFile.hasPrefix("/") {
            url = URL(fileURLWithPath: logFile)
        } else {
            url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent(logFile)
        }

        if FileManager.default.fileExists(atPath: url.path) {
            let fileHandle = try FileHandle(forWritingTo: url)
            defer { try? fileHandle.close() }
            fileHandle.seekToEndOfFile()
            if let lineData = line.data(using: .utf8) {
                fileHandle.write(lineData)
            }
        } else {
            try line.write(to: url, atomically: true, encoding: .utf8)
        }
    } catch {
        // Never crash the main flow. Logging failure is silently swallowed.
    }
}
