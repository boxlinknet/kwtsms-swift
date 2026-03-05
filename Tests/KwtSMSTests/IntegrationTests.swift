import XCTest
@testable import KwtSMS

/// Integration tests that hit the live kwtSMS API with test mode enabled.
///
/// These tests require SWIFT_USERNAME and SWIFT_PASSWORD environment variables.
/// All sends use test_mode=true so no credits are consumed and no messages are delivered.
///
/// Run: SWIFT_USERNAME=user SWIFT_PASSWORD=pass swift test --filter IntegrationTests
final class IntegrationTests: XCTestCase {

    private var sms: KwtSMS!
    private var hasCredentials: Bool = false

    override func setUp() async throws {
        let username = ProcessInfo.processInfo.environment["SWIFT_USERNAME"] ?? ""
        let password = ProcessInfo.processInfo.environment["SWIFT_PASSWORD"] ?? ""

        if username.isEmpty || password.isEmpty {
            hasCredentials = false
            return
        }

        hasCredentials = true
        sms = KwtSMS(
            username: username,
            password: password,
            testMode: true,
            logFile: ""  // no log file during tests
        )
    }

    private func skipIfNoCredentials() throws {
        if !hasCredentials {
            throw XCTSkip("SWIFT_USERNAME / SWIFT_PASSWORD not set")
        }
    }

    // MARK: - verify()

    func testVerifyWithValidCredentials() async throws {
        try skipIfNoCredentials()
        let result = await sms.verify()
        XCTAssertTrue(result.ok, "verify() should succeed with valid credentials: \(result.error ?? "")")
        XCTAssertNotNil(result.balance)
        XCTAssertTrue(result.balance! >= 0)
    }

    func testVerifyWithWrongCredentials() async throws {
        try skipIfNoCredentials()
        let badSms = KwtSMS(username: "wrong_user", password: "wrong_pass", testMode: true, logFile: "")
        let result = await badSms.verify()
        XCTAssertFalse(result.ok)
        XCTAssertNotNil(result.error)
    }

    // MARK: - balance()

    func testBalanceReturnsNumber() async throws {
        try skipIfNoCredentials()
        let balance = await sms.balance()
        XCTAssertNotNil(balance)
        XCTAssertTrue(balance! >= 0)
    }

    // MARK: - send()

    func testSendToValidKuwaitNumber() async throws {
        try skipIfNoCredentials()
        let result = await sms.send(mobile: "96598765432", message: "Test from Swift client")
        // With test mode, the API should accept it (result OK) or return a known error
        // The number may not be real, so ERR006 is also acceptable
        XCTAssertTrue(["OK", "ERROR"].contains(result.result))
        if result.result == "OK" {
            XCTAssertNotNil(result.msgId)
        }
    }

    func testSendWithPlusPrefix() async throws {
        try skipIfNoCredentials()
        let result = await sms.send(mobile: "+96598765432", message: "Test normalization")
        // Should normalize and send, not crash
        XCTAssertTrue(["OK", "ERROR"].contains(result.result))
    }

    func testSendWith00Prefix() async throws {
        try skipIfNoCredentials()
        let result = await sms.send(mobile: "0096598765432", message: "Test normalization")
        XCTAssertTrue(["OK", "ERROR"].contains(result.result))
    }

    func testSendWithArabicDigits() async throws {
        try skipIfNoCredentials()
        let result = await sms.send(
            mobile: "\u{0669}\u{0666}\u{0665}\u{0669}\u{0668}\u{0667}\u{0666}\u{0665}\u{0664}\u{0663}\u{0662}",
            message: "Test Arabic digit normalization"
        )
        XCTAssertTrue(["OK", "ERROR"].contains(result.result))
    }

    func testSendToEmail() async throws {
        try skipIfNoCredentials()
        let result = await sms.send(mobile: "user@gmail.com", message: "Should fail")
        XCTAssertEqual(result.result, "ERROR")
        XCTAssertEqual(result.code, "ERR_INVALID_INPUT")
        XCTAssertFalse(result.invalid.isEmpty)
    }

    func testSendToTooShort() async throws {
        try skipIfNoCredentials()
        let result = await sms.send(mobile: "123", message: "Should fail")
        XCTAssertEqual(result.result, "ERROR")
        XCTAssertEqual(result.code, "ERR_INVALID_INPUT")
    }

    func testSendToLetters() async throws {
        try skipIfNoCredentials()
        let result = await sms.send(mobile: "abcdefgh", message: "Should fail")
        XCTAssertEqual(result.result, "ERROR")
        XCTAssertEqual(result.code, "ERR_INVALID_INPUT")
    }

    func testSendMixedValidInvalid() async throws {
        try skipIfNoCredentials()
        let result = await sms.send(
            mobiles: ["96598765432", "user@email.com", "123"],
            message: "Test mixed input"
        )
        // Valid number should still be sent, invalid ones collected
        XCTAssertFalse(result.invalid.isEmpty)
        XCTAssertEqual(result.invalid.count, 2)
    }

    func testSendEmptyMessage() async throws {
        try skipIfNoCredentials()
        let result = await sms.send(mobile: "96598765432", message: "")
        XCTAssertEqual(result.result, "ERROR")
        XCTAssertEqual(result.code, "ERR009")
    }

    func testSendEmojiOnlyMessage() async throws {
        try skipIfNoCredentials()
        let result = await sms.send(mobile: "96598765432", message: "\u{1F600}\u{1F601}")
        XCTAssertEqual(result.result, "ERROR")
        XCTAssertEqual(result.code, "ERR009")
    }

    func testSendDeduplicatesNumbers() async throws {
        try skipIfNoCredentials()
        let result = await sms.send(
            mobiles: ["+96598765432", "0096598765432", "96598765432"],
            message: "Dedup test"
        )
        // All three normalize to the same number, should only send once
        XCTAssertTrue(["OK", "ERROR"].contains(result.result))
    }

    // MARK: - senderIds()

    func testSenderIdsReturnsList() async throws {
        try skipIfNoCredentials()
        let result = await sms.senderIds()
        XCTAssertEqual(result.result, "OK")
        XCTAssertFalse(result.senderIds.isEmpty, "Should have at least one sender ID")
    }

    // MARK: - coverage()

    func testCoverageReturnsPrefixes() async throws {
        try skipIfNoCredentials()
        let result = await sms.coverage()
        XCTAssertEqual(result.result, "OK")
        XCTAssertFalse(result.prefixes.isEmpty, "Should have at least one active prefix")
    }

    // MARK: - validate()

    func testValidateWithValidNumber() async throws {
        try skipIfNoCredentials()
        let result = await sms.validate(phones: ["96598765432"])
        // The number may end up in OK, ER, or NR depending on account configuration
        XCTAssertNil(result.error)
    }

    func testValidateWithInvalidInput() async throws {
        try skipIfNoCredentials()
        let result = await sms.validate(phones: ["user@email.com", "96598765432"])
        XCTAssertEqual(result.rejected.count, 1)
        XCTAssertTrue(result.rejected[0].error.contains("email"))
    }

    // MARK: - status()

    func testStatusWithFakeId() async throws {
        try skipIfNoCredentials()
        let result = await sms.status(msgId: "nonexistent_msg_id_12345")
        XCTAssertEqual(result.result, "ERROR")
        // Should get ERR029 (message does not exist)
    }

    // MARK: - deliveryReport()

    func testDlrWithFakeId() async throws {
        try skipIfNoCredentials()
        let result = await sms.deliveryReport(msgId: "nonexistent_msg_id_12345")
        XCTAssertEqual(result.result, "ERROR")
        // Should get ERR020 (message does not exist)
    }

    // MARK: - Wrong sender ID

    func testSendWithWrongSenderId() async throws {
        try skipIfNoCredentials()
        let username = ProcessInfo.processInfo.environment["SWIFT_USERNAME"]!
        let password = ProcessInfo.processInfo.environment["SWIFT_PASSWORD"]!
        let badSender = KwtSMS(
            username: username,
            password: password,
            senderId: "NONEXISTENT-SENDER-12345",
            testMode: true,
            logFile: ""
        )
        let result = await badSender.send(mobile: "96598765432", message: "Wrong sender test")
        // Expect ERROR with ERR008 or similar
        if result.result == "ERROR" {
            XCTAssertNotNil(result.action ?? result.description)
        }
    }

    // MARK: - Cached balance

    func testCachedBalanceUpdatedAfterVerify() async throws {
        try skipIfNoCredentials()
        let initial = await sms.cachedBalance
        XCTAssertNil(initial) // no API call yet

        _ = await sms.verify()
        let cached = await sms.cachedBalance
        XCTAssertNotNil(cached)
    }
}
