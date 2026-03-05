import Foundation

/// Clean a message for SMS delivery via kwtSMS.
///
/// Performs the following in order:
/// 1. Convert Arabic-Indic and Extended Arabic-Indic digits to Latin
/// 2. Remove emojis (all known emoji Unicode ranges)
/// 3. Remove hidden invisible characters (zero-width space, BOM, soft hyphen, etc.)
/// 4. Remove directional formatting characters
/// 5. Remove C0 and C1 control characters (preserving newline and tab)
/// 6. Strip HTML tags
///
/// Arabic text is fully preserved. Only digits, emojis, invisible chars, control chars, and HTML are affected.
///
/// - Parameter text: Raw message text.
/// - Returns: Cleaned message safe for kwtSMS delivery.
public func cleanMessage(_ text: String) -> String {
    var result = ""
    result.reserveCapacity(text.count)

    for scalar in text.unicodeScalars {
        let v = scalar.value

        // 1. Convert Arabic-Indic digits U+0660..U+0669 → 0..9
        if v >= 0x0660 && v <= 0x0669 {
            result.unicodeScalars.append(UnicodeScalar(v - 0x0660 + 0x0030)!)
            continue
        }

        // 2. Convert Extended Arabic-Indic / Persian digits U+06F0..U+06F9 → 0..9
        if v >= 0x06F0 && v <= 0x06F9 {
            result.unicodeScalars.append(UnicodeScalar(v - 0x06F0 + 0x0030)!)
            continue
        }

        // 3. Remove emojis
        if isEmoji(v) {
            continue
        }

        // 4. Remove hidden invisible characters
        if isHiddenInvisible(v) {
            continue
        }

        // 5. Remove directional formatting characters
        if isDirectionalFormatting(v) {
            continue
        }

        // 6. Remove C0 and C1 control characters, but preserve \n (U+000A) and \t (U+0009)
        if isControlChar(v) {
            continue
        }

        result.unicodeScalars.append(scalar)
    }

    // 7. Strip HTML tags
    result = stripHTMLTags(result)

    return result
}

// MARK: - Private helpers

private func isEmoji(_ v: UInt32) -> Bool {
    // Mahjong, domino tiles
    if v >= 0x1F000 && v <= 0x1F02F { return true }
    // Playing cards
    if v >= 0x1F0A0 && v <= 0x1F0FF { return true }
    // Regional indicator symbols / flag components
    if v >= 0x1F1E0 && v <= 0x1F1FF { return true }
    // Misc symbols and pictographs
    if v >= 0x1F300 && v <= 0x1F5FF { return true }
    // Emoticons
    if v >= 0x1F600 && v <= 0x1F64F { return true }
    // Transport and map
    if v >= 0x1F680 && v <= 0x1F6FF { return true }
    // Alchemical symbols
    if v >= 0x1F700 && v <= 0x1F77F { return true }
    // Geometric shapes extended
    if v >= 0x1F780 && v <= 0x1F7FF { return true }
    // Supplemental arrows
    if v >= 0x1F800 && v <= 0x1F8FF { return true }
    // Supplemental symbols and pictographs
    if v >= 0x1F900 && v <= 0x1F9FF { return true }
    // Chess symbols
    if v >= 0x1FA00 && v <= 0x1FA6F { return true }
    // Symbols and pictographs extended
    if v >= 0x1FA70 && v <= 0x1FAFF { return true }
    // Misc symbols
    if v >= 0x2600 && v <= 0x26FF { return true }
    // Dingbats
    if v >= 0x2700 && v <= 0x27BF { return true }
    // Variation selectors (emoji style modifiers)
    if v >= 0xFE00 && v <= 0xFE0F { return true }
    // Combining enclosing keycap
    if v == 0x20E3 { return true }
    // Tags block (subdivision flag sequences)
    if v >= 0xE0000 && v <= 0xE007F { return true }

    return false
}

private func isHiddenInvisible(_ v: UInt32) -> Bool {
    switch v {
    case 0x200B: return true  // Zero-width space
    case 0x200C: return true  // Zero-width non-joiner
    case 0x200D: return true  // Zero-width joiner
    case 0x2060: return true  // Word joiner
    case 0x00AD: return true  // Soft hyphen
    case 0xFEFF: return true  // BOM
    case 0xFFFC: return true  // Object replacement character
    default: return false
    }
}

private func isDirectionalFormatting(_ v: UInt32) -> Bool {
    switch v {
    case 0x200E: return true  // Left-to-right mark
    case 0x200F: return true  // Right-to-left mark
    default: break
    }
    // LRE, RLE, PDF, LRO, RLO
    if v >= 0x202A && v <= 0x202E { return true }
    // LRI, RLI, FSI, PDI
    if v >= 0x2066 && v <= 0x2069 { return true }
    return false
}

private func isControlChar(_ v: UInt32) -> Bool {
    // C0 controls (except TAB U+0009 and LF U+000A)
    if v >= 0x0000 && v <= 0x001F && v != 0x0009 && v != 0x000A {
        return true
    }
    // DEL
    if v == 0x007F { return true }
    // C1 controls
    if v >= 0x0080 && v <= 0x009F { return true }
    return false
}

private func stripHTMLTags(_ text: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: "<[^>]*>", options: []) else {
        return text
    }
    let range = NSRange(text.startIndex..., in: text)
    return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
}
