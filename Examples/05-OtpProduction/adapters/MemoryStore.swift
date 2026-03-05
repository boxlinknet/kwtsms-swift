/**
 * In-memory OTP store adapter.
 *
 * Zero dependencies. Perfect for:
 *   - Development and testing
 *   - Single-process servers (no multi-instance coordination needed)
 *   - Serverless functions (each invocation is isolated anyway)
 *
 * Limitations:
 *   - Data lost on server restart
 *   - Not shared across multiple server instances
 *   → Use a persistent database adapter (SQLite, PostgreSQL, Redis) for
 *     production multi-instance deployments
 *
 * Usage:
 *   let store = MemoryOtpStore()
 *   let service = OtpService(sms: sms, store: store, appName: "MyApp")
 */

import Foundation

/// Thread-safe in-memory implementation of OtpStoreProtocol.
public actor MemoryOtpStore: OtpStoreProtocol {
    private var records: [String: OtpRecord] = [:]
    private var rateLimits: [String: [Date]] = [:]

    public init() {}

    public func get(phone: String) async -> OtpRecord? {
        return records[phone]
    }

    public func set(phone: String, record: OtpRecord) async {
        records[phone] = record
    }

    public func delete(phone: String) async {
        records.removeValue(forKey: phone)
    }

    public func getRateLimit(key: String) async -> [Date] {
        return rateLimits[key] ?? []
    }

    public func setRateLimit(key: String, timestamps: [Date]) async {
        rateLimits[key] = timestamps
    }
}
