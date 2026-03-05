import Foundation

/// Normalize a phone number to kwtSMS-accepted format (digits only, international format).
///
/// Converts Arabic-Indic and Extended Arabic-Indic (Persian) digits to Latin,
/// strips all non-digit characters, and removes leading zeros.
///
/// - Parameter phone: Raw phone number string in any format.
/// - Returns: Normalized digits-only string (e.g. "96598765432").
public func normalizePhone(_ phone: String) -> String {
    var result = ""
    result.reserveCapacity(phone.count)

    for scalar in phone.unicodeScalars {
        let v = scalar.value
        // Arabic-Indic digits U+0660..U+0669 → 0..9
        if v >= 0x0660 && v <= 0x0669 {
            result.append(Character(UnicodeScalar(v - 0x0660 + 0x0030)!))
        }
        // Extended Arabic-Indic / Persian digits U+06F0..U+06F9 → 0..9
        else if v >= 0x06F0 && v <= 0x06F9 {
            result.append(Character(UnicodeScalar(v - 0x06F0 + 0x0030)!))
        }
        // Latin digit
        else if v >= 0x0030 && v <= 0x0039 {
            result.append(Character(scalar))
        }
        // Everything else is stripped (spaces, +, dashes, dots, parens, slashes, etc.)
    }

    // Strip leading zeros (handles 00 country code prefix)
    var startIndex = result.startIndex
    while startIndex < result.endIndex && result[startIndex] == "0" {
        startIndex = result.index(after: startIndex)
    }
    if startIndex == result.endIndex {
        return result.isEmpty ? "" : "0"
    }
    return String(result[startIndex...])
}

/// Structured result for a single phone number that failed local validation.
public struct InvalidEntry: Codable, Equatable, Sendable {
    /// The original input string.
    public let input: String
    /// The reason the input is invalid.
    public let error: String

    public init(input: String, error: String) {
        self.input = input
        self.error = error
    }
}

/// Validate a phone number input before sending to the API.
///
/// Returns a tuple of (valid, error, normalized). Never throws.
///
/// Validation rules:
/// - Empty/blank → "Phone number is required"
/// - Contains @ → email address error
/// - No digits after normalization → not a valid phone number
/// - Less than 7 digits → too short
/// - More than 15 digits → too long
///
/// - Parameter phone: Raw phone number string.
/// - Returns: Tuple of (isValid, errorMessage, normalizedNumber).
public func validatePhoneInput(_ phone: String) -> (valid: Bool, error: String?, normalized: String) {
    let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)

    if trimmed.isEmpty {
        return (false, "Phone number is required", "")
    }

    if trimmed.contains("@") {
        return (false, "'\(trimmed)' is an email address, not a phone number", "")
    }

    let normalized = normalizePhone(trimmed)

    if normalized.isEmpty || (normalized == "0" && !trimmed.contains(where: { $0 >= "1" && $0 <= "9" })) {
        return (false, "'\(trimmed)' is not a valid phone number, no digits found", "")
    }

    // Check if normalization resulted in just "0" (all zeros input)
    let digitCount = normalized.count

    if digitCount < 7 {
        let digitWord = digitCount == 1 ? "digit" : "digits"
        return (false, "'\(trimmed)' is too short (\(digitCount) \(digitWord), minimum is 7)", normalized)
    }

    if digitCount > 15 {
        return (false, "'\(trimmed)' is too long (\(digitCount) digits, maximum is 15)", normalized)
    }

    return (true, nil, normalized)
}

/// Deduplicate an array of normalized phone numbers, preserving order.
///
/// - Parameter phones: Array of normalized phone number strings.
/// - Returns: Array with duplicates removed, preserving first occurrence order.
public func deduplicatePhones(_ phones: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for phone in phones {
        if seen.insert(phone).inserted {
            result.append(phone)
        }
    }
    return result
}
