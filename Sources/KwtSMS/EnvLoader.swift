import Foundation

/// Load environment variables from a `.env` file.
///
/// Parsing rules:
/// - Ignores blank lines and lines starting with `#`
/// - Strips inline `# comments` from unquoted values
/// - Supports single-quoted and double-quoted values (preserves `#` inside quotes)
/// - Returns empty dictionary for missing files (never throws)
/// - Does NOT modify the process environment (read-only parsing)
///
/// - Parameter filePath: Path to the `.env` file. Defaults to `.env` in the current directory.
/// - Returns: Dictionary of key-value pairs.
public func loadEnvFile(_ filePath: String = ".env") -> [String: String] {
    let url: URL
    if filePath.hasPrefix("/") {
        url = URL(fileURLWithPath: filePath)
    } else {
        url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(filePath)
    }

    guard let data = try? Data(contentsOf: url),
          let contents = String(data: data, encoding: .utf8) else {
        return [:]
    }

    var result: [String: String] = [:]

    for line in contents.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Skip blank lines and comments
        if trimmed.isEmpty || trimmed.hasPrefix("#") {
            continue
        }

        // Find the first = sign
        guard let equalsIndex = trimmed.firstIndex(of: "=") else {
            continue
        }

        let key = String(trimmed[trimmed.startIndex..<equalsIndex])
            .trimmingCharacters(in: .whitespaces)
        var value = String(trimmed[trimmed.index(after: equalsIndex)...])
            .trimmingCharacters(in: .whitespaces)

        if key.isEmpty {
            continue
        }

        // Handle quoted values
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
           (value.hasPrefix("'") && value.hasSuffix("'")) {
            // Remove quotes
            value = String(value.dropFirst().dropLast())
        } else {
            // Strip inline comments for unquoted values (space + # + rest)
            if let commentRange = value.range(of: " #") {
                value = String(value[value.startIndex..<commentRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
            }
        }

        result[key] = value
    }

    return result
}
