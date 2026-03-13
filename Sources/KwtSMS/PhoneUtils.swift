import Foundation

// MARK: - Phone validation rules

/// Validation rule for a country's phone numbers.
public struct PhoneRule {
    /// Valid local number lengths (digits after country code).
    public let localLengths: [Int]
    /// Valid first digit(s) of local number for mobile. Empty means any starting digit accepted.
    public let mobileStartDigits: [String]

    public init(localLengths: [Int], mobileStartDigits: [String] = []) {
        self.localLengths = localLengths
        self.mobileStartDigits = mobileStartDigits
    }
}

/// Phone number validation rules by country code.
/// Validates local number length and mobile starting digits.
///
/// localLengths: valid digit count(s) AFTER country code
/// mobileStartDigits: valid first character(s) of the local number
/// Countries not listed here pass through with generic E.164 validation (7-15 digits).
public let phoneRules: [String: PhoneRule] = [
    // === GCC ===
    "965": PhoneRule(localLengths: [8], mobileStartDigits: ["4", "5", "6", "9"]),       // Kuwait
    "966": PhoneRule(localLengths: [9], mobileStartDigits: ["5"]),                       // Saudi Arabia
    "971": PhoneRule(localLengths: [9], mobileStartDigits: ["5"]),                       // UAE
    "973": PhoneRule(localLengths: [8], mobileStartDigits: ["3", "6"]),                  // Bahrain
    "974": PhoneRule(localLengths: [8], mobileStartDigits: ["3", "5", "6", "7"]),        // Qatar
    "968": PhoneRule(localLengths: [8], mobileStartDigits: ["7", "9"]),                  // Oman
    // === Levant ===
    "962": PhoneRule(localLengths: [9], mobileStartDigits: ["7"]),                       // Jordan
    "961": PhoneRule(localLengths: [7, 8], mobileStartDigits: ["3", "7", "8"]),          // Lebanon
    "970": PhoneRule(localLengths: [9], mobileStartDigits: ["5"]),                       // Palestine
    "964": PhoneRule(localLengths: [10], mobileStartDigits: ["7"]),                      // Iraq
    "963": PhoneRule(localLengths: [9], mobileStartDigits: ["9"]),                       // Syria
    // === Other Arab ===
    "967": PhoneRule(localLengths: [9], mobileStartDigits: ["7"]),                       // Yemen
    "20":  PhoneRule(localLengths: [10], mobileStartDigits: ["1"]),                      // Egypt
    "218": PhoneRule(localLengths: [9], mobileStartDigits: ["9"]),                       // Libya
    "216": PhoneRule(localLengths: [8], mobileStartDigits: ["2", "4", "5", "9"]),        // Tunisia
    "212": PhoneRule(localLengths: [9], mobileStartDigits: ["6", "7"]),                  // Morocco
    "213": PhoneRule(localLengths: [9], mobileStartDigits: ["5", "6", "7"]),             // Algeria
    "249": PhoneRule(localLengths: [9], mobileStartDigits: ["9"]),                       // Sudan
    // === Non-Arab Middle East ===
    "98":  PhoneRule(localLengths: [10], mobileStartDigits: ["9"]),                      // Iran
    "90":  PhoneRule(localLengths: [10], mobileStartDigits: ["5"]),                      // Turkey
    "972": PhoneRule(localLengths: [9], mobileStartDigits: ["5"]),                       // Israel
    // === South Asia ===
    "91":  PhoneRule(localLengths: [10], mobileStartDigits: ["6", "7", "8", "9"]),       // India
    "92":  PhoneRule(localLengths: [10], mobileStartDigits: ["3"]),                      // Pakistan
    "880": PhoneRule(localLengths: [10], mobileStartDigits: ["1"]),                      // Bangladesh
    "94":  PhoneRule(localLengths: [9], mobileStartDigits: ["7"]),                       // Sri Lanka
    "960": PhoneRule(localLengths: [7], mobileStartDigits: ["7", "9"]),                  // Maldives
    // === East Asia ===
    "86":  PhoneRule(localLengths: [11], mobileStartDigits: ["1"]),                      // China
    "81":  PhoneRule(localLengths: [10], mobileStartDigits: ["7", "8", "9"]),            // Japan
    "82":  PhoneRule(localLengths: [10], mobileStartDigits: ["1"]),                      // South Korea
    "886": PhoneRule(localLengths: [9], mobileStartDigits: ["9"]),                       // Taiwan
    // === Southeast Asia ===
    "65":  PhoneRule(localLengths: [8], mobileStartDigits: ["8", "9"]),                  // Singapore
    "60":  PhoneRule(localLengths: [9, 10], mobileStartDigits: ["1"]),                   // Malaysia
    "62":  PhoneRule(localLengths: [9, 10, 11, 12], mobileStartDigits: ["8"]),           // Indonesia
    "63":  PhoneRule(localLengths: [10], mobileStartDigits: ["9"]),                      // Philippines
    "66":  PhoneRule(localLengths: [9], mobileStartDigits: ["6", "8", "9"]),             // Thailand
    "84":  PhoneRule(localLengths: [9], mobileStartDigits: ["3", "5", "7", "8", "9"]),   // Vietnam
    "95":  PhoneRule(localLengths: [9], mobileStartDigits: ["9"]),                       // Myanmar
    "855": PhoneRule(localLengths: [8, 9], mobileStartDigits: ["1", "6", "7", "8", "9"]),// Cambodia
    "976": PhoneRule(localLengths: [8], mobileStartDigits: ["6", "8", "9"]),             // Mongolia
    // === Europe ===
    "44":  PhoneRule(localLengths: [10], mobileStartDigits: ["7"]),                      // UK
    "33":  PhoneRule(localLengths: [9], mobileStartDigits: ["6", "7"]),                  // France
    "49":  PhoneRule(localLengths: [10, 11], mobileStartDigits: ["1"]),                  // Germany
    "39":  PhoneRule(localLengths: [10], mobileStartDigits: ["3"]),                      // Italy
    "34":  PhoneRule(localLengths: [9], mobileStartDigits: ["6", "7"]),                  // Spain
    "31":  PhoneRule(localLengths: [9], mobileStartDigits: ["6"]),                       // Netherlands
    "32":  PhoneRule(localLengths: [9]),                                                  // Belgium
    "41":  PhoneRule(localLengths: [9], mobileStartDigits: ["7"]),                       // Switzerland
    "43":  PhoneRule(localLengths: [10], mobileStartDigits: ["6"]),                      // Austria
    "47":  PhoneRule(localLengths: [8], mobileStartDigits: ["4", "9"]),                  // Norway
    "48":  PhoneRule(localLengths: [9]),                                                  // Poland
    "30":  PhoneRule(localLengths: [10], mobileStartDigits: ["6"]),                      // Greece
    "420": PhoneRule(localLengths: [9], mobileStartDigits: ["6", "7"]),                  // Czech Republic
    "46":  PhoneRule(localLengths: [9], mobileStartDigits: ["7"]),                       // Sweden
    "45":  PhoneRule(localLengths: [8]),                                                  // Denmark
    "40":  PhoneRule(localLengths: [9], mobileStartDigits: ["7"]),                       // Romania
    "36":  PhoneRule(localLengths: [9]),                                                  // Hungary
    "380": PhoneRule(localLengths: [9]),                                                  // Ukraine
    // === Americas ===
    "1":   PhoneRule(localLengths: [10]),                                                 // USA/Canada
    "52":  PhoneRule(localLengths: [10]),                                                 // Mexico
    "55":  PhoneRule(localLengths: [11]),                                                 // Brazil
    "57":  PhoneRule(localLengths: [10], mobileStartDigits: ["3"]),                      // Colombia
    "54":  PhoneRule(localLengths: [10], mobileStartDigits: ["9"]),                      // Argentina
    "56":  PhoneRule(localLengths: [9], mobileStartDigits: ["9"]),                       // Chile
    "58":  PhoneRule(localLengths: [10], mobileStartDigits: ["4"]),                      // Venezuela
    "51":  PhoneRule(localLengths: [9], mobileStartDigits: ["9"]),                       // Peru
    "593": PhoneRule(localLengths: [9], mobileStartDigits: ["9"]),                       // Ecuador
    "53":  PhoneRule(localLengths: [8], mobileStartDigits: ["5", "6"]),                  // Cuba
    // === Africa ===
    "27":  PhoneRule(localLengths: [9], mobileStartDigits: ["6", "7", "8"]),             // South Africa
    "234": PhoneRule(localLengths: [10], mobileStartDigits: ["7", "8", "9"]),            // Nigeria
    "254": PhoneRule(localLengths: [9], mobileStartDigits: ["1", "7"]),                  // Kenya
    "233": PhoneRule(localLengths: [9], mobileStartDigits: ["2", "5"]),                  // Ghana
    "251": PhoneRule(localLengths: [9], mobileStartDigits: ["7", "9"]),                  // Ethiopia
    "255": PhoneRule(localLengths: [9], mobileStartDigits: ["6", "7"]),                  // Tanzania
    "256": PhoneRule(localLengths: [9], mobileStartDigits: ["7"]),                       // Uganda
    "237": PhoneRule(localLengths: [9], mobileStartDigits: ["6"]),                       // Cameroon
    "225": PhoneRule(localLengths: [10]),                                                 // Ivory Coast
    "221": PhoneRule(localLengths: [9], mobileStartDigits: ["7"]),                       // Senegal
    "252": PhoneRule(localLengths: [9], mobileStartDigits: ["6", "7"]),                  // Somalia
    "250": PhoneRule(localLengths: [9], mobileStartDigits: ["7"]),                       // Rwanda
    // === Oceania ===
    "61":  PhoneRule(localLengths: [9], mobileStartDigits: ["4"]),                       // Australia
    "64":  PhoneRule(localLengths: [8, 9, 10], mobileStartDigits: ["2"]),                // New Zealand
]

/// Country names by country code, for error messages.
let countryNames: [String: String] = [
    "965": "Kuwait", "966": "Saudi Arabia", "971": "UAE", "973": "Bahrain",
    "974": "Qatar", "968": "Oman", "962": "Jordan", "961": "Lebanon",
    "970": "Palestine", "964": "Iraq", "963": "Syria", "967": "Yemen",
    "20": "Egypt", "218": "Libya", "216": "Tunisia", "212": "Morocco",
    "213": "Algeria", "249": "Sudan", "98": "Iran", "90": "Turkey",
    "972": "Israel", "91": "India", "92": "Pakistan", "880": "Bangladesh",
    "94": "Sri Lanka", "960": "Maldives", "86": "China", "81": "Japan",
    "82": "South Korea", "886": "Taiwan", "65": "Singapore", "60": "Malaysia",
    "62": "Indonesia", "63": "Philippines", "66": "Thailand", "84": "Vietnam",
    "95": "Myanmar", "855": "Cambodia", "976": "Mongolia", "44": "UK",
    "33": "France", "49": "Germany", "39": "Italy", "34": "Spain",
    "31": "Netherlands", "32": "Belgium", "41": "Switzerland", "43": "Austria",
    "47": "Norway", "48": "Poland", "30": "Greece", "420": "Czech Republic",
    "46": "Sweden", "45": "Denmark", "40": "Romania", "36": "Hungary",
    "380": "Ukraine", "1": "USA/Canada", "52": "Mexico", "55": "Brazil",
    "57": "Colombia", "54": "Argentina", "56": "Chile", "58": "Venezuela",
    "51": "Peru", "593": "Ecuador", "53": "Cuba", "27": "South Africa",
    "234": "Nigeria", "254": "Kenya", "233": "Ghana", "251": "Ethiopia",
    "255": "Tanzania", "256": "Uganda", "237": "Cameroon", "225": "Ivory Coast",
    "221": "Senegal", "252": "Somalia", "250": "Rwanda", "61": "Australia",
    "64": "New Zealand",
]

/// Find the country code prefix from a normalized phone number.
/// Tries 3-digit codes first, then 2-digit, then 1-digit (longest match wins).
public func findCountryCode(_ normalized: String) -> String? {
    if normalized.count >= 3 {
        let cc3 = String(normalized.prefix(3))
        if phoneRules[cc3] != nil { return cc3 }
    }
    if normalized.count >= 2 {
        let cc2 = String(normalized.prefix(2))
        if phoneRules[cc2] != nil { return cc2 }
    }
    if normalized.count >= 1 {
        let cc1 = String(normalized.prefix(1))
        if phoneRules[cc1] != nil { return cc1 }
    }
    return nil
}

/// Validate a normalized phone number against country-specific format rules.
/// Checks local number length and mobile starting digits.
/// Numbers with no matching country rules pass through (generic E.164 only).
public func validatePhoneFormat(_ normalized: String) -> (valid: Bool, error: String?) {
    guard let cc = findCountryCode(normalized) else {
        return (true, nil)
    }
    guard let rule = phoneRules[cc] else {
        return (true, nil)
    }

    let local = String(normalized.dropFirst(cc.count))
    let country = countryNames[cc] ?? "+\(cc)"

    if !rule.localLengths.contains(local.count) {
        let expected = rule.localLengths.map(String.init).joined(separator: " or ")
        return (false, "Invalid \(country) number: expected \(expected) digits after +\(cc), got \(local.count)")
    }

    if !rule.mobileStartDigits.isEmpty {
        let hasValidPrefix = rule.mobileStartDigits.contains(where: { local.hasPrefix($0) })
        if !hasValidPrefix {
            let prefixes = rule.mobileStartDigits.joined(separator: ", ")
            return (false, "Invalid \(country) mobile number: after +\(cc) must start with \(prefixes)")
        }
    }

    return (true, nil)
}

// MARK: - Normalization

/// Normalize a phone number to kwtSMS-accepted format (digits only, international format).
///
/// Converts Arabic-Indic and Extended Arabic-Indic (Persian) digits to Latin,
/// strips all non-digit characters, removes leading zeros, and strips domestic
/// trunk prefix (e.g. 9660559... becomes 966559...).
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
    result = String(result[startIndex...])

    // Strip domestic trunk prefix (leading 0 after country code)
    // e.g. 9660559... -> 966559..., 97105x -> 9715x, 20010x -> 2010x
    if let cc = findCountryCode(result) {
        let local = String(result.dropFirst(cc.count))
        if local.hasPrefix("0") {
            var stripped = local
            while stripped.hasPrefix("0") {
                stripped = String(stripped.dropFirst())
            }
            result = cc + stripped
        }
    }

    return result
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

    // Validate against country-specific format rules (length + mobile prefix)
    let formatCheck = validatePhoneFormat(normalized)
    if !formatCheck.valid {
        return (false, formatCheck.error, normalized)
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
