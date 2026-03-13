import XCTest
@testable import KwtSMS

final class PhoneTests: XCTestCase {

    // MARK: - normalizePhone()

    func testStripsPlus() {
        XCTAssertEqual(normalizePhone("+96598765432"), "96598765432")
    }

    func testStripsDoubleZero() {
        XCTAssertEqual(normalizePhone("0096598765432"), "96598765432")
    }

    func testStripsSpaces() {
        XCTAssertEqual(normalizePhone("965 9876 5432"), "96598765432")
    }

    func testStripsDashes() {
        XCTAssertEqual(normalizePhone("965-9876-5432"), "96598765432")
    }

    func testStripsDots() {
        XCTAssertEqual(normalizePhone("965.9876.5432"), "96598765432")
    }

    func testStripsParentheses() {
        XCTAssertEqual(normalizePhone("(965) 98765432"), "96598765432")
    }

    func testStripsSlashes() {
        XCTAssertEqual(normalizePhone("965/9876/5432"), "96598765432")
    }

    func testStripsMixedSeparators() {
        XCTAssertEqual(normalizePhone("+00965 (9876)-5432"), "96598765432")
    }

    func testArabicIndicDigits() {
        XCTAssertEqual(normalizePhone("\u{0669}\u{0666}\u{0665}\u{0669}\u{0668}\u{0667}\u{0666}\u{0665}\u{0664}\u{0663}\u{0662}"), "96598765432")
    }

    func testExtendedArabicIndicDigits() {
        XCTAssertEqual(normalizePhone("\u{06F9}\u{06F6}\u{06F5}\u{06F9}\u{06F8}\u{06F7}\u{06F6}\u{06F5}\u{06F4}\u{06F3}\u{06F2}"), "96598765432")
    }

    func testStripsLeadingZeros() {
        XCTAssertEqual(normalizePhone("0096598765432"), "96598765432")
    }

    func testStripsSingleLeadingZero() {
        XCTAssertEqual(normalizePhone("098765432"), "98765432")
    }

    func testEmptyString() {
        XCTAssertEqual(normalizePhone(""), "")
    }

    func testOnlySpaces() {
        XCTAssertEqual(normalizePhone("   "), "")
    }

    func testOnlyLetters() {
        XCTAssertEqual(normalizePhone("abcdef"), "")
    }

    func testAlreadyClean() {
        XCTAssertEqual(normalizePhone("96598765432"), "96598765432")
    }

    // MARK: - Domestic trunk prefix stripping

    func testSaudiTrunkPrefix() {
        // 9660559123456 -> 966559123456 (strip the 0 after 966)
        XCTAssertEqual(normalizePhone("9660559123456"), "966559123456")
    }

    func testSaudiTrunkPrefixWithPlus() {
        XCTAssertEqual(normalizePhone("+9660559123456"), "966559123456")
    }

    func testSaudiTrunkPrefixWith00() {
        XCTAssertEqual(normalizePhone("009660559123456"), "966559123456")
    }

    func testUAETrunkPrefix() {
        // 9710501234567 -> 971501234567
        XCTAssertEqual(normalizePhone("9710501234567"), "971501234567")
    }

    func testEgyptTrunkPrefix() {
        // 20010xxxxxxx -> 2010xxxxxxx
        XCTAssertEqual(normalizePhone("2001012345678"), "201012345678")
    }

    func testKuwaitNoTrunkPrefix() {
        // Kuwait numbers don't use trunk prefix, should not be modified
        XCTAssertEqual(normalizePhone("96598765432"), "96598765432")
    }

    // MARK: - findCountryCode()

    func testFindCountryCode3Digit() {
        XCTAssertEqual(findCountryCode("96598765432"), "965")
    }

    func testFindCountryCode2Digit() {
        XCTAssertEqual(findCountryCode("201012345678"), "20")
    }

    func testFindCountryCode1Digit() {
        XCTAssertEqual(findCountryCode("12125551234"), "1")
    }

    func testFindCountryCodeUnknown() {
        XCTAssertNil(findCountryCode("99912345678"))
    }

    func testFindCountryCodeLongestMatch() {
        // 965 is 3-digit and should match before any 2 or 1-digit code
        XCTAssertEqual(findCountryCode("96598765432"), "965")
    }

    // MARK: - validatePhoneFormat()

    func testValidKuwaitFormat() {
        let result = validatePhoneFormat("96598765432")
        XCTAssertTrue(result.valid)
    }

    func testInvalidKuwaitLengthTooShort() {
        let result = validatePhoneFormat("9659876543")  // 7 local digits, needs 8
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.error!.contains("Kuwait"))
        XCTAssertTrue(result.error!.contains("8 digits"))
    }

    func testInvalidKuwaitMobilePrefix() {
        let result = validatePhoneFormat("96512345678")  // starts with 1, not valid mobile
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.error!.contains("Kuwait"))
        XCTAssertTrue(result.error!.contains("must start with"))
    }

    func testValidSaudiFormat() {
        let result = validatePhoneFormat("966559123456")
        XCTAssertTrue(result.valid)
    }

    func testInvalidSaudiMobilePrefix() {
        let result = validatePhoneFormat("966359123456")  // starts with 3, Saudi needs 5
        XCTAssertFalse(result.valid)
        XCTAssertTrue(result.error!.contains("Saudi"))
    }

    func testValidUAEFormat() {
        let result = validatePhoneFormat("971501234567")
        XCTAssertTrue(result.valid)
    }

    func testValidUSFormat() {
        // USA has no mobile prefix restriction, length only
        let result = validatePhoneFormat("12125551234")
        XCTAssertTrue(result.valid)
    }

    func testUnknownCountryPassesThrough() {
        let result = validatePhoneFormat("99912345678")
        XCTAssertTrue(result.valid)
    }

    func testValidEgyptFormat() {
        let result = validatePhoneFormat("201012345678")
        XCTAssertTrue(result.valid)
    }

    func testValidBelgiumLengthOnly() {
        // Belgium has no mobile prefix restriction
        let result = validatePhoneFormat("32412345678")
        XCTAssertTrue(result.valid)
    }

    func testKuwaitAllValidPrefixes() {
        // 4x, 5x, 6x, 9x are all valid Kuwait mobile prefixes
        for prefix in ["4", "5", "6", "9"] {
            let number = "965\(prefix)1234567"
            let result = validatePhoneFormat(number)
            XCTAssertTrue(result.valid, "Kuwait prefix \(prefix) should be valid")
        }
    }

    // MARK: - validatePhoneInput() (integrated with format validation)

    func testValidKuwaitNumber() {
        let (valid, error, normalized) = validatePhoneInput("96598765432")
        XCTAssertTrue(valid)
        XCTAssertNil(error)
        XCTAssertEqual(normalized, "96598765432")
    }

    func testValidWithPlusPrefix() {
        let (valid, error, normalized) = validatePhoneInput("+96598765432")
        XCTAssertTrue(valid)
        XCTAssertNil(error)
        XCTAssertEqual(normalized, "96598765432")
    }

    func testValidWith00Prefix() {
        let (valid, error, normalized) = validatePhoneInput("0096598765432")
        XCTAssertTrue(valid)
        XCTAssertNil(error)
        XCTAssertEqual(normalized, "96598765432")
    }

    func testValidGenericNumber() {
        // Unknown country code, passes generic validation (7-15 digits)
        let (valid, error, _) = validatePhoneInput("9991234567")
        XCTAssertTrue(valid)
        XCTAssertNil(error)
    }

    func testEmptyInput() {
        let (valid, error, _) = validatePhoneInput("")
        XCTAssertFalse(valid)
        XCTAssertEqual(error, "Phone number is required")
    }

    func testBlankInput() {
        let (valid, error, _) = validatePhoneInput("   ")
        XCTAssertFalse(valid)
        XCTAssertEqual(error, "Phone number is required")
    }

    func testEmailAddress() {
        let (valid, error, _) = validatePhoneInput("user@gmail.com")
        XCTAssertFalse(valid)
        XCTAssertTrue(error!.contains("email address"))
    }

    func testNoDigitsFound() {
        let (valid, error, _) = validatePhoneInput("abcdef")
        XCTAssertFalse(valid)
        XCTAssertTrue(error!.contains("no digits found"))
    }

    func testTooShort() {
        let (valid, error, _) = validatePhoneInput("123")
        XCTAssertFalse(valid)
        XCTAssertTrue(error!.contains("too short"))
        XCTAssertTrue(error!.contains("3 digits"))
    }

    func testTooShortSingularDigit() {
        let (valid, error, _) = validatePhoneInput("1")
        XCTAssertFalse(valid)
        XCTAssertTrue(error!.contains("1 digit"))
    }

    func testTooLong() {
        let (valid, error, _) = validatePhoneInput("1234567890123456")
        XCTAssertFalse(valid)
        XCTAssertTrue(error!.contains("too long"))
        XCTAssertTrue(error!.contains("16 digits"))
    }

    func testArabicDigitsValidation() {
        let (valid, error, normalized) = validatePhoneInput("\u{0669}\u{0666}\u{0665}\u{0669}\u{0668}\u{0667}\u{0666}\u{0665}\u{0664}\u{0663}\u{0662}")
        XCTAssertTrue(valid)
        XCTAssertNil(error)
        XCTAssertEqual(normalized, "96598765432")
    }

    func testLeadingAndTrailingWhitespace() {
        let (valid, _, normalized) = validatePhoneInput("  96598765432  ")
        XCTAssertTrue(valid)
        XCTAssertEqual(normalized, "96598765432")
    }

    func testSaudiWithTrunkPrefix() {
        // 9660559123456 should normalize to 966559123456 and pass validation
        let (valid, error, normalized) = validatePhoneInput("9660559123456")
        XCTAssertTrue(valid)
        XCTAssertNil(error)
        XCTAssertEqual(normalized, "966559123456")
    }

    func testSaudiWithPlusTrunkPrefix() {
        let (valid, error, normalized) = validatePhoneInput("+9660559123456")
        XCTAssertTrue(valid)
        XCTAssertNil(error)
        XCTAssertEqual(normalized, "966559123456")
    }

    func testInvalidKuwaitPrefixViaValidateInput() {
        // 96512345678: prefix 1 is not valid for Kuwait mobile
        let (valid, error, _) = validatePhoneInput("96512345678")
        XCTAssertFalse(valid)
        XCTAssertTrue(error!.contains("Kuwait"))
    }

    func testInvalidSaudiLengthViaValidateInput() {
        // 96655912345: only 8 local digits, Saudi needs 9
        let (valid, error, _) = validatePhoneInput("96655912345")
        XCTAssertFalse(valid)
        XCTAssertTrue(error!.contains("Saudi"))
    }

    // MARK: - deduplicatePhones()

    func testDeduplicatePreservesOrder() {
        let result = deduplicatePhones(["111", "222", "111", "333", "222"])
        XCTAssertEqual(result, ["111", "222", "333"])
    }

    func testDeduplicateNoDuplicates() {
        let result = deduplicatePhones(["111", "222", "333"])
        XCTAssertEqual(result, ["111", "222", "333"])
    }

    func testDeduplicateEmpty() {
        let result = deduplicatePhones([])
        XCTAssertEqual(result, [])
    }
}
