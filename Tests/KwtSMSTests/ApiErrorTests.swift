import XCTest
@testable import KwtSMS

final class ApiErrorTests: XCTestCase {

    // MARK: - enrichError()

    func testEnrichesKnownErrorCode() {
        let response: [String: Any] = [
            "result": "ERROR",
            "code": "ERR003",
            "description": "Authentication error, username or password are not correct."
        ]
        let enriched = enrichError(response)
        XCTAssertNotNil(enriched["action"] as? String)
        XCTAssertTrue((enriched["action"] as! String).contains("KWTSMS_USERNAME"))
    }

    func testEnrichesAllKnownCodes() {
        let knownCodes = [
            "ERR001", "ERR002", "ERR003", "ERR004", "ERR005", "ERR006", "ERR007",
            "ERR008", "ERR009", "ERR010", "ERR011", "ERR012", "ERR013",
            "ERR019", "ERR020", "ERR021", "ERR022", "ERR023", "ERR024",
            "ERR025", "ERR026", "ERR027", "ERR028", "ERR029", "ERR030",
            "ERR031", "ERR032", "ERR033", "ERR_INVALID_INPUT"
        ]
        for code in knownCodes {
            let response: [String: Any] = ["result": "ERROR", "code": code, "description": "Test"]
            let enriched = enrichError(response)
            XCTAssertNotNil(enriched["action"] as? String, "Missing action for \(code)")
        }
    }

    func testUnknownErrorCodeNoAction() {
        let response: [String: Any] = [
            "result": "ERROR",
            "code": "ERR999",
            "description": "Unknown error"
        ]
        let enriched = enrichError(response)
        XCTAssertNil(enriched["action"] as? String)
        XCTAssertEqual(enriched["description"] as? String, "Unknown error")
    }

    func testDoesNotEnrichOKResponse() {
        let response: [String: Any] = [
            "result": "OK",
            "available": 150,
            "purchased": 1000
        ]
        let enriched = enrichError(response)
        XCTAssertNil(enriched["action"])
    }

    func testDoesNotEnrichResponseWithoutCode() {
        let response: [String: Any] = [
            "result": "ERROR",
            "description": "Something went wrong"
        ]
        let enriched = enrichError(response)
        XCTAssertNil(enriched["action"])
    }

    func testPreservesOriginalFields() {
        let response: [String: Any] = [
            "result": "ERROR",
            "code": "ERR010",
            "description": "Zero balance",
            "extra": "field"
        ]
        let enriched = enrichError(response)
        XCTAssertEqual(enriched["extra"] as? String, "field")
        XCTAssertEqual(enriched["code"] as? String, "ERR010")
    }

    // MARK: - apiErrors constant

    func testApiErrorsHas29Entries() {
        // 33 error codes: ERR001-ERR013 (13), ERR019-ERR033 (15), ERR_INVALID_INPUT (1) = 29
        XCTAssertEqual(apiErrors.count, 29)
    }

    func testERR003MentionsCredentials() {
        XCTAssertTrue(apiErrors["ERR003"]!.contains("KWTSMS_USERNAME"))
    }

    func testERR013MentionsWait() {
        XCTAssertTrue(apiErrors["ERR013"]!.lowercased().contains("wait"))
    }

    func testERR024MentionsIP() {
        XCTAssertTrue(apiErrors["ERR024"]!.lowercased().contains("ip"))
    }

    func testERR028Mentions15Seconds() {
        XCTAssertTrue(apiErrors["ERR028"]!.contains("15"))
    }

    // MARK: - KwtSMSError

    func testApiErrorDescription() {
        let error = KwtSMSError.apiError(code: "ERR003", description: "Auth failed", action: "Check credentials")
        XCTAssertTrue(error.localizedDescription.contains("ERR003"))
        XCTAssertTrue(error.localizedDescription.contains("Auth failed"))
    }

    func testNetworkErrorDescription() {
        let error = KwtSMSError.networkError("Connection refused")
        XCTAssertTrue(error.localizedDescription.contains("Connection refused"))
    }

    func testInvalidResponseDescription() {
        let error = KwtSMSError.invalidResponse("Not JSON")
        XCTAssertTrue(error.localizedDescription.contains("Not JSON"))
    }

    func testEmptyMessageDescription() {
        let error = KwtSMSError.emptyMessage
        XCTAssertTrue(error.localizedDescription.contains("empty"))
    }

    func testAllNumbersInvalidDescription() {
        let error = KwtSMSError.allNumbersInvalid
        XCTAssertTrue(error.localizedDescription.contains("validation"))
    }
}
