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
        // ٩٦٥٩٨٧٦٥٤٣٢
        XCTAssertEqual(normalizePhone("\u{0669}\u{0666}\u{0665}\u{0669}\u{0668}\u{0667}\u{0666}\u{0665}\u{0664}\u{0663}\u{0662}"), "96598765432")
    }

    func testExtendedArabicIndicDigits() {
        // ۹۶۵۹۸۷۶۵۴۳۲ (Persian)
        XCTAssertEqual(normalizePhone("\u{06F9}\u{06F6}\u{06F5}\u{06F9}\u{06F8}\u{06F7}\u{06F6}\u{06F5}\u{06F4}\u{06F3}\u{06F2}"), "96598765432")
    }

    func testStripsLeadingZeros() {
        XCTAssertEqual(normalizePhone("0096598765432"), "96598765432")
    }

    func testStripsSingleLeadingZero() {
        // Local format with single leading zero (e.g. 098765432)
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

    // MARK: - validatePhoneInput()

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

    func testValidMinimum7Digits() {
        let (valid, error, _) = validatePhoneInput("1234567")
        XCTAssertTrue(valid)
        XCTAssertNil(error)
    }

    func testValidMaximum15Digits() {
        let (valid, error, _) = validatePhoneInput("123456789012345")
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
        // ٩٦٥٩٨٧٦٥٤٣٢ = 11 digits, should be valid
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
