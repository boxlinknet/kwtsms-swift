import Foundation

// MARK: - Response types

/// Result from the `verify()` method.
public struct VerifyResult: Sendable {
    public let ok: Bool
    public let balance: Double?
    public let error: String?
}

/// Result from a single-batch `send()` call (up to 200 numbers).
public struct SendResult: Sendable {
    public let result: String
    public let msgId: String?
    public let numbers: Int?
    public let pointsCharged: Int?
    public let balanceAfter: Double?
    public let unixTimestamp: Int?
    public let code: String?
    public let description: String?
    public let action: String?
    public let invalid: [InvalidEntry]
}

/// Result from a bulk `send()` call (>200 numbers, auto-batched).
public struct BulkSendResult: Sendable {
    public let result: String  // "OK", "PARTIAL", or "ERROR"
    public let bulk: Bool
    public let batches: Int
    public let numbers: Int
    public let pointsCharged: Int
    public let balanceAfter: Double?
    public let msgIds: [String]
    public let errors: [BatchError]
    public let invalid: [InvalidEntry]
    public let code: String?
    public let description: String?
}

/// Error from a single batch within a bulk send.
public struct BatchError: Sendable {
    public let batch: Int
    public let code: String
    public let description: String
}

/// Result from the `validate()` method.
public struct ValidateResult: @unchecked Sendable {
    public let ok: [String]
    public let er: [String]
    public let nr: [String]
    public let rejected: [InvalidEntry]
    public let error: String?
    public let raw: [String: Any]?
}

/// Result from the `senderIds()` method.
public struct SenderIdResult: Sendable {
    public let result: String
    public let senderIds: [String]
    public let code: String?
    public let description: String?
    public let action: String?
}

/// Result from the `coverage()` method.
public struct CoverageResult: Sendable {
    public let result: String
    public let prefixes: [String]
    public let code: String?
    public let description: String?
    public let action: String?
}

/// Result from the `status()` method.
public struct StatusResult: Sendable {
    public let result: String
    public let status: String?
    public let statusDescription: String?
    public let code: String?
    public let description: String?
    public let action: String?
}

/// A single delivery report entry.
public struct DeliveryReportEntry: Sendable {
    public let number: String
    public let status: String
}

/// Result from the `deliveryReport()` method.
public struct DeliveryReportResult: Sendable {
    public let result: String
    public let report: [DeliveryReportEntry]
    public let code: String?
    public let description: String?
    public let action: String?
}

// MARK: - KwtSMS Client

/// kwtSMS API client for sending SMS messages from Swift.
///
/// Thread-safe: uses `actor` isolation for internal mutable state.
/// All API methods are `async` and use Swift concurrency.
///
/// Usage:
/// ```swift
/// let sms = KwtSMS(username: "swift_username", password: "swift_password")
/// let result = try await sms.send(mobile: "96598765432", message: "Hello!")
/// ```
public actor KwtSMS {
    private let username: String
    private let password: String
    private let senderId: String
    private let testMode: Bool
    private let logFile: String

    private var _cachedBalance: Double?
    private var _cachedPurchased: Double?

    /// The last known balance from a `verify()` or successful `send()` call.
    public var cachedBalance: Double? { _cachedBalance }

    /// The total purchased credits from the last `verify()` call.
    public var cachedPurchased: Double? { _cachedPurchased }

    /// Create a new kwtSMS client with explicit credentials.
    ///
    /// - Parameters:
    ///   - username: Your kwtSMS API username.
    ///   - password: Your kwtSMS API password.
    ///   - senderId: Sender ID to use. Defaults to "KWT-SMS" (testing only).
    ///   - testMode: If true, messages are queued but not delivered and no credits consumed.
    ///   - logFile: Path to JSONL log file. Empty string disables logging.
    public init(
        username: String,
        password: String,
        senderId: String = "KWT-SMS",
        testMode: Bool = false,
        logFile: String = "kwtsms.log"
    ) {
        self.username = username
        self.password = password
        self.senderId = senderId
        self.testMode = testMode
        self.logFile = logFile
    }

    /// Create a kwtSMS client from environment variables and/or a `.env` file.
    ///
    /// Reads `KWTSMS_USERNAME`, `KWTSMS_PASSWORD`, `KWTSMS_SENDER_ID`,
    /// `KWTSMS_TEST_MODE`, `KWTSMS_LOG_FILE` from the process environment first,
    /// then falls back to values in the `.env` file.
    ///
    /// - Parameter envFile: Path to `.env` file. Defaults to ".env".
    /// - Returns: A configured KwtSMS instance.
    public static func fromEnv(envFile: String = ".env") -> KwtSMS {
        let fileVars = loadEnvFile(envFile)

        func resolve(_ key: String, fallback: String = "") -> String {
            if let envVal = ProcessInfo.processInfo.environment[key], !envVal.isEmpty {
                return envVal
            }
            return fileVars[key] ?? fallback
        }

        let username = resolve("KWTSMS_USERNAME")
        let password = resolve("KWTSMS_PASSWORD")
        let senderId = resolve("KWTSMS_SENDER_ID", fallback: "KWT-SMS")
        let testModeStr = resolve("KWTSMS_TEST_MODE", fallback: "0")
        let logFile = resolve("KWTSMS_LOG_FILE", fallback: "kwtsms.log")
        let testMode = testModeStr == "1" || testModeStr.lowercased() == "true"

        return KwtSMS(
            username: username,
            password: password,
            senderId: senderId,
            testMode: testMode,
            logFile: logFile
        )
    }

    // MARK: - Credentials payload

    private var authPayload: [String: Any] {
        ["username": username, "password": password]
    }

    // MARK: - verify()

    /// Test credentials and get the current balance. Never throws.
    ///
    /// - Returns: A `VerifyResult` with ok, balance, and error fields.
    public func verify() async -> VerifyResult {
        do {
            let response = try await apiRequest(
                endpoint: "balance",
                payload: authPayload,
                logFile: logFile
            )

            let result = response["result"] as? String ?? ""
            if result == "OK" {
                let available = asDouble(response["available"])
                let purchased = asDouble(response["purchased"])
                _cachedBalance = available
                _cachedPurchased = purchased
                return VerifyResult(ok: true, balance: available, error: nil)
            } else {
                let enriched = enrichError(response)
                let desc = enriched["description"] as? String ?? "Unknown error"
                let action = enriched["action"] as? String
                let errorMsg = action != nil ? "\(desc) \(action!)" : desc
                return VerifyResult(ok: false, balance: nil, error: errorMsg)
            }
        } catch {
            return VerifyResult(ok: false, balance: nil, error: error.localizedDescription)
        }
    }

    // MARK: - balance()

    /// Get the current SMS credit balance.
    ///
    /// Returns the live balance on success, or the cached value if the API call fails.
    /// Returns nil if no cached value exists and the API call fails.
    ///
    /// - Returns: The available balance, or nil.
    public func balance() async -> Double? {
        let result = await verify()
        if result.ok {
            return result.balance
        }
        return _cachedBalance
    }

    // MARK: - send()

    /// Send an SMS to one or more phone numbers.
    ///
    /// Validates and normalizes all phone numbers locally before calling the API.
    /// Automatically cleans the message text (strips emojis, HTML, control chars).
    /// For >200 numbers, auto-batches with 0.5s delay between batches.
    ///
    /// - Parameters:
    ///   - mobile: A single phone number or comma-separated list.
    ///   - message: The SMS message text.
    ///   - sender: Optional sender ID override. Uses the client's default if nil.
    /// - Returns: A `SendResult` for single-batch, or throws for errors.
    public func send(mobile: String, message: String, sender: String? = nil) async -> SendResult {
        let phones = mobile.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return await sendToPhones(phones, message: message, sender: sender)
    }

    /// Send an SMS to an array of phone numbers.
    ///
    /// - Parameters:
    ///   - mobiles: Array of phone number strings.
    ///   - message: The SMS message text.
    ///   - sender: Optional sender ID override.
    /// - Returns: A `SendResult` for single-batch or indicates bulk was needed.
    public func send(mobiles: [String], message: String, sender: String? = nil) async -> SendResult {
        return await sendToPhones(mobiles, message: message, sender: sender)
    }

    /// Send an SMS to an array of phone numbers, returning a BulkSendResult when >200.
    ///
    /// - Parameters:
    ///   - mobiles: Array of phone number strings.
    ///   - message: The SMS message text.
    ///   - sender: Optional sender ID override.
    /// - Returns: A `BulkSendResult` with per-batch tracking.
    public func sendBulk(mobiles: [String], message: String, sender: String? = nil) async -> BulkSendResult {
        return await sendBulkInternal(mobiles, message: message, sender: sender)
    }

    // MARK: - validate()

    /// Validate phone numbers with the kwtSMS API.
    ///
    /// Runs local validation first, then sends valid numbers to the API.
    ///
    /// - Parameter phones: Array of phone number strings to validate.
    /// - Returns: A `ValidateResult` with ok, er, nr, rejected, and raw fields.
    public func validate(phones: [String]) async -> ValidateResult {
        var validNumbers: [String] = []
        var rejected: [InvalidEntry] = []

        for phone in phones {
            let (valid, error, normalized) = validatePhoneInput(phone)
            if valid {
                validNumbers.append(normalized)
            } else {
                rejected.append(InvalidEntry(input: phone, error: error ?? "Invalid"))
            }
        }

        validNumbers = deduplicatePhones(validNumbers)

        if validNumbers.isEmpty {
            return ValidateResult(ok: [], er: [], nr: [], rejected: rejected, error: "All numbers failed local validation", raw: nil)
        }

        do {
            var payload = authPayload
            payload["mobile"] = validNumbers.joined(separator: ",")

            let response = try await apiRequest(endpoint: "validate", payload: payload, logFile: logFile)
            let result = response["result"] as? String ?? ""

            if result == "OK", let mobile = response["mobile"] as? [String: Any] {
                let ok = (mobile["OK"] as? [String]) ?? []
                let er = (mobile["ER"] as? [String]) ?? []
                let nr = (mobile["NR"] as? [String]) ?? []
                return ValidateResult(ok: ok, er: er, nr: nr, rejected: rejected, error: nil, raw: response)
            } else {
                let enriched = enrichError(response)
                let desc = enriched["description"] as? String ?? "Unknown error"
                return ValidateResult(ok: [], er: [], nr: [], rejected: rejected, error: desc, raw: response)
            }
        } catch {
            return ValidateResult(ok: [], er: [], nr: [], rejected: rejected, error: error.localizedDescription, raw: nil)
        }
    }

    // MARK: - senderIds()

    /// List available sender IDs on the account.
    ///
    /// - Returns: A `SenderIdResult` with the list of sender IDs or an error.
    public func senderIds() async -> SenderIdResult {
        do {
            let response = try await apiRequest(endpoint: "senderid", payload: authPayload, logFile: logFile)
            let result = response["result"] as? String ?? ""

            if result == "OK" {
                let ids = (response["senderid"] as? [String]) ?? []
                return SenderIdResult(result: "OK", senderIds: ids, code: nil, description: nil, action: nil)
            } else {
                let enriched = enrichError(response)
                return SenderIdResult(
                    result: "ERROR",
                    senderIds: [],
                    code: enriched["code"] as? String,
                    description: enriched["description"] as? String,
                    action: enriched["action"] as? String
                )
            }
        } catch {
            return SenderIdResult(result: "ERROR", senderIds: [], code: nil, description: error.localizedDescription, action: nil)
        }
    }

    // MARK: - coverage()

    /// List active country prefixes for SMS delivery.
    ///
    /// - Returns: A `CoverageResult` with active prefixes or an error.
    public func coverage() async -> CoverageResult {
        do {
            let response = try await apiRequest(endpoint: "coverage", payload: authPayload, logFile: logFile)
            let result = response["result"] as? String ?? ""

            if result == "OK" {
                let prefixes = (response["prefixes"] as? [String]) ?? []
                return CoverageResult(result: "OK", prefixes: prefixes, code: nil, description: nil, action: nil)
            } else {
                let enriched = enrichError(response)
                return CoverageResult(
                    result: "ERROR",
                    prefixes: [],
                    code: enriched["code"] as? String,
                    description: enriched["description"] as? String,
                    action: enriched["action"] as? String
                )
            }
        } catch {
            return CoverageResult(result: "ERROR", prefixes: [], code: nil, description: error.localizedDescription, action: nil)
        }
    }

    // MARK: - status()

    /// Check the status of a sent message by its message ID.
    ///
    /// - Parameter msgId: The message ID returned from a successful `send()`.
    /// - Returns: A `StatusResult` with the message status.
    public func status(msgId: String) async -> StatusResult {
        do {
            var payload = authPayload
            payload["msgid"] = msgId

            let response = try await apiRequest(endpoint: "status", payload: payload, logFile: logFile)
            let result = response["result"] as? String ?? ""

            if result == "OK" {
                return StatusResult(
                    result: "OK",
                    status: response["status"] as? String,
                    statusDescription: response["description"] as? String,
                    code: nil,
                    description: nil,
                    action: nil
                )
            } else {
                let enriched = enrichError(response)
                return StatusResult(
                    result: "ERROR",
                    status: nil,
                    statusDescription: nil,
                    code: enriched["code"] as? String,
                    description: enriched["description"] as? String,
                    action: enriched["action"] as? String
                )
            }
        } catch {
            return StatusResult(result: "ERROR", status: nil, statusDescription: nil, code: nil, description: error.localizedDescription, action: nil)
        }
    }

    // MARK: - deliveryReport()

    /// Get delivery reports for a sent message (international numbers only).
    ///
    /// Kuwait numbers do not have delivery reports. Wait at least 5 minutes
    /// after sending before checking DLR for international numbers.
    ///
    /// - Parameter msgId: The message ID returned from a successful `send()`.
    /// - Returns: A `DeliveryReportResult` with per-number delivery status.
    public func deliveryReport(msgId: String) async -> DeliveryReportResult {
        do {
            var payload = authPayload
            payload["msgid"] = msgId

            let response = try await apiRequest(endpoint: "dlr", payload: payload, logFile: logFile)
            let result = response["result"] as? String ?? ""

            if result == "OK" {
                var entries: [DeliveryReportEntry] = []
                if let report = response["report"] as? [[String: Any]] {
                    for item in report {
                        let number = item["Number"] as? String ?? ""
                        let status = item["Status"] as? String ?? ""
                        entries.append(DeliveryReportEntry(number: number, status: status))
                    }
                }
                return DeliveryReportResult(result: "OK", report: entries, code: nil, description: nil, action: nil)
            } else {
                let enriched = enrichError(response)
                return DeliveryReportResult(
                    result: "ERROR",
                    report: [],
                    code: enriched["code"] as? String,
                    description: enriched["description"] as? String,
                    action: enriched["action"] as? String
                )
            }
        } catch {
            return DeliveryReportResult(result: "ERROR", report: [], code: nil, description: error.localizedDescription, action: nil)
        }
    }

    // MARK: - Private send helpers

    private func sendToPhones(_ phones: [String], message: String, sender: String?) async -> SendResult {
        // Clean message
        let cleaned = cleanMessage(message)
        if cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return SendResult(
                result: "ERROR", msgId: nil, numbers: nil, pointsCharged: nil,
                balanceAfter: nil, unixTimestamp: nil, code: "ERR009",
                description: "Message is empty after cleaning.",
                action: apiErrors["ERR009"], invalid: []
            )
        }

        // Validate all numbers
        var validNumbers: [String] = []
        var invalid: [InvalidEntry] = []

        for phone in phones {
            let (valid, error, normalized) = validatePhoneInput(phone)
            if valid {
                validNumbers.append(normalized)
            } else {
                invalid.append(InvalidEntry(input: phone, error: error ?? "Invalid"))
            }
        }

        // Deduplicate
        validNumbers = deduplicatePhones(validNumbers)

        if validNumbers.isEmpty {
            return SendResult(
                result: "ERROR", msgId: nil, numbers: nil, pointsCharged: nil,
                balanceAfter: nil, unixTimestamp: nil, code: "ERR_INVALID_INPUT",
                description: "All phone numbers are invalid.",
                action: apiErrors["ERR_INVALID_INPUT"], invalid: invalid
            )
        }

        // If >200 numbers, delegate to bulk send and return a summary as SendResult
        if validNumbers.count > 200 {
            let bulk = await sendBulkInternal(phones, message: message, sender: sender)
            return SendResult(
                result: bulk.result, msgId: bulk.msgIds.first, numbers: bulk.numbers,
                pointsCharged: bulk.pointsCharged, balanceAfter: bulk.balanceAfter,
                unixTimestamp: nil, code: bulk.code, description: bulk.description,
                action: nil, invalid: bulk.invalid
            )
        }

        // Single batch send
        return await sendSingleBatch(validNumbers, message: cleaned, sender: sender, invalid: invalid)
    }

    private func sendSingleBatch(
        _ numbers: [String],
        message: String,
        sender: String?,
        invalid: [InvalidEntry],
        retryCount: Int = 0
    ) async -> SendResult {
        var payload = authPayload
        payload["sender"] = sender ?? senderId
        payload["mobile"] = numbers.joined(separator: ",")
        payload["message"] = message
        payload["test"] = testMode ? "1" : "0"

        do {
            let response = try await apiRequest(endpoint: "send", payload: payload, logFile: logFile)
            let result = response["result"] as? String ?? ""

            if result == "OK" {
                let balanceAfter = asDouble(response["balance-after"])
                if let bal = balanceAfter {
                    _cachedBalance = bal
                }
                return SendResult(
                    result: "OK",
                    msgId: response["msg-id"] as? String,
                    numbers: asInt(response["numbers"]),
                    pointsCharged: asInt(response["points-charged"]),
                    balanceAfter: balanceAfter,
                    unixTimestamp: asInt(response["unix-timestamp"]),
                    code: nil, description: nil, action: nil,
                    invalid: invalid
                )
            } else {
                let enriched = enrichError(response)
                let code = enriched["code"] as? String ?? ""

                // ERR013 (queue full): retry up to 3 times with backoff
                if code == "ERR013" && retryCount < 3 {
                    let delays: [UInt64] = [30_000_000_000, 60_000_000_000, 120_000_000_000]
                    try? await Task.sleep(nanoseconds: delays[retryCount])
                    return await sendSingleBatch(numbers, message: message, sender: sender, invalid: invalid, retryCount: retryCount + 1)
                }

                return SendResult(
                    result: "ERROR", msgId: nil, numbers: nil, pointsCharged: nil,
                    balanceAfter: nil, unixTimestamp: nil,
                    code: code,
                    description: enriched["description"] as? String,
                    action: enriched["action"] as? String,
                    invalid: invalid
                )
            }
        } catch {
            return SendResult(
                result: "ERROR", msgId: nil, numbers: nil, pointsCharged: nil,
                balanceAfter: nil, unixTimestamp: nil, code: nil,
                description: error.localizedDescription, action: nil,
                invalid: invalid
            )
        }
    }

    private func sendBulkInternal(_ phones: [String], message: String, sender: String?) async -> BulkSendResult {
        // Clean message
        let cleaned = cleanMessage(message)
        if cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return BulkSendResult(
                result: "ERROR", bulk: true, batches: 0, numbers: 0,
                pointsCharged: 0, balanceAfter: nil, msgIds: [], errors: [],
                invalid: [], code: "ERR009", description: "Message is empty after cleaning."
            )
        }

        // Validate all numbers
        var validNumbers: [String] = []
        var invalid: [InvalidEntry] = []

        for phone in phones {
            let (valid, error, normalized) = validatePhoneInput(phone)
            if valid {
                validNumbers.append(normalized)
            } else {
                invalid.append(InvalidEntry(input: phone, error: error ?? "Invalid"))
            }
        }

        validNumbers = deduplicatePhones(validNumbers)

        if validNumbers.isEmpty {
            return BulkSendResult(
                result: "ERROR", bulk: true, batches: 0, numbers: 0,
                pointsCharged: 0, balanceAfter: nil, msgIds: [], errors: [],
                invalid: invalid, code: "ERR_INVALID_INPUT",
                description: "All phone numbers are invalid."
            )
        }

        // Split into batches of 200
        let batchSize = 200
        var batches: [[String]] = []
        var start = 0
        while start < validNumbers.count {
            let end = min(start + batchSize, validNumbers.count)
            batches.append(Array(validNumbers[start..<end]))
            start = end
        }

        var allMsgIds: [String] = []
        var allErrors: [BatchError] = []
        var totalNumbers = 0
        var totalPoints = 0
        var lastBalance: Double?

        for (index, batch) in batches.enumerated() {
            if index > 0 {
                // 0.5s delay between batches (max 2 req/s)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }

            let result = await sendSingleBatch(batch, message: cleaned, sender: sender, invalid: [])

            if result.result == "OK" {
                if let msgId = result.msgId { allMsgIds.append(msgId) }
                totalNumbers += result.numbers ?? 0
                totalPoints += result.pointsCharged ?? 0
                lastBalance = result.balanceAfter ?? lastBalance
            } else {
                allErrors.append(BatchError(
                    batch: index + 1,
                    code: result.code ?? "UNKNOWN",
                    description: result.description ?? "Unknown error"
                ))
            }
        }

        let overallResult: String
        if allErrors.isEmpty {
            overallResult = "OK"
        } else if allMsgIds.isEmpty {
            overallResult = "ERROR"
        } else {
            overallResult = "PARTIAL"
        }

        return BulkSendResult(
            result: overallResult,
            bulk: true,
            batches: batches.count,
            numbers: totalNumbers,
            pointsCharged: totalPoints,
            balanceAfter: lastBalance,
            msgIds: allMsgIds,
            errors: allErrors,
            invalid: invalid,
            code: allErrors.first?.code,
            description: allErrors.first?.description
        )
    }
}

// MARK: - Helpers

private func asDouble(_ value: Any?) -> Double? {
    if let d = value as? Double { return d }
    if let i = value as? Int { return Double(i) }
    if let s = value as? String { return Double(s) }
    return nil
}

private func asInt(_ value: Any?) -> Int? {
    if let i = value as? Int { return i }
    if let d = value as? Double { return Int(d) }
    if let s = value as? String { return Int(s) }
    return nil
}
