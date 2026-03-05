/**
 * Production OTP Service for kwtSMS (Swift)
 *
 * Framework-agnostic. Plug in any database adapter and optional CAPTCHA verifier.
 *
 * Quick start:
 *   let service = OtpService(
 *       sms: KwtSMS.fromEnv(),
 *       store: MemoryOtpStore(),
 *       appName: "MyApp"
 *   )
 *
 *   let result = await service.sendOtp(phone: rawPhone, ip: clientIp)
 *   let result = await service.verifyOtp(phone: rawPhone, code: rawCode, ip: clientIp)
 *
 * With device attestation + auth token (production):
 *   let service = OtpService(
 *       sms: KwtSMS.fromEnv(),
 *       store: MemoryOtpStore(),
 *       appName: "MyApp",
 *       deviceAttest: AppAttestVerifier(teamId: "...", bundleId: "..."),
 *       auth: myJWTAuthenticator
 *   )
 *
 * Swap the database:
 *   let store = MemoryOtpStore()          // dev / single-process
 *   let store = YourCustomStore()          // implement OtpStoreProtocol
 */

import Foundation
import CryptoKit    // Apple platforms (iOS 15+, macOS 12+)
// For Linux: add swift-crypto to your Package.swift dependencies
// import Crypto
import KwtSMS

// MARK: - Constants (all overridable via OtpServiceConfig)

public let OTP_TTL_SECONDS: TimeInterval = 5 * 60                // 5 minutes
public let RESEND_COOLDOWN_SECONDS: TimeInterval = 4 * 60        // 4 minutes (kwtSMS standard)
public let MAX_ATTEMPTS = 3                                        // wrong guesses before code invalidated
public let RATE_WINDOW_SECONDS: TimeInterval = 60 * 60            // 1-hour sliding window
public let MAX_SENDS_PER_IP = 10                                   // per hour
public let MAX_SENDS_PER_PHONE = 3                                 // per hour
public let MAX_VERIFY_PER_PHONE = 5                                // per hour (brute-force guard)

// MARK: - OTP Record

/// Stored per OTP request. Code is always a SHA-256 hash with salt, never plain text.
public struct OtpRecord: Sendable {
    public let phone: String              // normalized (digits only, e.g. "96598765432")
    public let codeHash: String           // SHA-256(salt + code), hex encoded
    public let salt: String               // random salt for this code
    public let expiresAt: Date
    public let resendAllowedAt: Date      // 4-min cooldown between sends
    public var attempts: Int              // wrong guesses so far
    public var used: Bool
    public let createdAt: Date
    public let ipAddress: String?         // optional audit trail

    public init(
        phone: String, codeHash: String, salt: String,
        expiresAt: Date, resendAllowedAt: Date,
        attempts: Int = 0, used: Bool = false,
        createdAt: Date = Date(), ipAddress: String? = nil
    ) {
        self.phone = phone
        self.codeHash = codeHash
        self.salt = salt
        self.expiresAt = expiresAt
        self.resendAllowedAt = resendAllowedAt
        self.attempts = attempts
        self.used = used
        self.createdAt = createdAt
        self.ipAddress = ipAddress
    }
}

// MARK: - Store Protocol

/// Database adapter interface. Implement for any database (Redis, SQLite, PostgreSQL, etc.)
public protocol OtpStoreProtocol: Sendable {
    func get(phone: String) async -> OtpRecord?
    func set(phone: String, record: OtpRecord) async
    func delete(phone: String) async
    /// Optional: DB-backed rate limiting. If not implemented, falls back to in-memory only.
    func getRateLimit(key: String) async -> [Date]
    func setRateLimit(key: String, timestamps: [Date]) async
}

/// Default implementations for optional rate limit methods (in-memory fallback).
extension OtpStoreProtocol {
    public func getRateLimit(key: String) async -> [Date] { return [] }
    public func setRateLimit(key: String, timestamps: [Date]) async {}
}

// MARK: - Device Attestation Protocol

/// Device attestation verifier (Apple App Attest / DeviceCheck).
/// Proves requests come from a genuine app installation on a real device, not a script or bot.
///
/// Flow:
///   1. iOS app generates an attestation key via DCAppAttestService
///   2. On each request, app generates an assertion (signs the request data)
///   3. Server verifies the assertion against the stored public key
///
/// See attestation/AppAttestVerifier.swift for the Apple App Attest implementation.
public protocol DeviceAttestVerifier: Sendable {
    /// Verify a device assertion.
    /// - Parameters:
    ///   - assertion: The assertion data from DCAppAttestService.generateAssertion()
    ///   - keyId: The App Attest key identifier for this device
    ///   - clientData: The client data hash that was signed (typically a hash of the request body)
    /// - Returns: true if the assertion is valid (genuine device + genuine app)
    func verify(assertion: Data, keyId: String, clientData: Data) async -> Bool
}

// MARK: - Token Authentication Protocol

/// Authentication token verifier (JWT / session token).
/// Requires users to be authenticated before requesting OTP.
/// Useful for 2FA flows where the user is already partially logged in.
///
/// Example: verify a JWT before allowing OTP send:
///   struct JWTAuthenticator: TokenAuthenticator {
///       func validate(token: String) async -> Bool {
///           // Decode and verify JWT signature, expiry, issuer
///           return jwt.verify(token)
///       }
///   }
public protocol TokenAuthenticator: Sendable {
    /// Validate an authentication token.
    /// - Parameter token: The auth token (from Authorization header, cookie, etc.)
    /// - Returns: true if the token is valid and the user is authorized
    func validate(token: String) async -> Bool
}

// MARK: - Result Types

public struct SendOtpResult: Sendable {
    public let success: Bool
    public let error: String?
    /// Seconds until resend is allowed (when resend cooldown active).
    public let resendIn: Int?
    /// Seconds until rate limit window resets.
    public let retryAfter: Int?

    public init(success: Bool, error: String? = nil, resendIn: Int? = nil, retryAfter: Int? = nil) {
        self.success = success
        self.error = error
        self.resendIn = resendIn
        self.retryAfter = retryAfter
    }
}

public struct VerifyOtpResult: Sendable {
    public let success: Bool
    public let error: String?
    /// Remaining wrong guesses before code is invalidated (forces resend).
    public let attemptsLeft: Int?
    /// Seconds until rate limit window resets.
    public let retryAfter: Int?

    public init(success: Bool, error: String? = nil, attemptsLeft: Int? = nil, retryAfter: Int? = nil) {
        self.success = success
        self.error = error
        self.attemptsLeft = attemptsLeft
        self.retryAfter = retryAfter
    }
}

// MARK: - Input Sanitization

/// Sanitize and validate a phone number input.
/// Returns (normalizedPhone, error). Error is nil on success.
public func sanitizePhone(_ raw: String) -> (phone: String, error: String?) {
    if raw.count > 30 { return ("", "Phone number is too long") }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return ("", "Phone number is required") }
    let (valid, error, normalized) = validatePhoneInput(trimmed)
    if !valid { return ("", error ?? "Invalid phone number") }
    return (normalized, nil)
}

/// Sanitize an OTP code input.
/// Strips non-digits, checks for exactly 6 digits.
/// Returns (cleanedCode, error). Error is nil on success.
public func sanitizeCode(_ raw: String) -> (code: String, error: String?) {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let digits = trimmed.unicodeScalars.filter { $0.value >= 0x30 && $0.value <= 0x39 }.map { Character($0) }
    let code = String(digits)
    if code.isEmpty { return ("", "Code is required") }
    if code.count != 6 { return ("", "Code must be exactly 6 digits (got \(code.count))") }
    return (code, nil)
}

// MARK: - Hashing

/// Generate a random 16-byte salt as hex string.
func generateSalt() -> String {
    var bytes = [UInt8](repeating: 0, count: 16)
    for i in 0..<bytes.count {
        bytes[i] = UInt8.random(in: 0...255)
    }
    return bytes.map { String(format: "%02x", $0) }.joined()
}

/// Hash an OTP code with a salt using SHA-256. Constant-time comparison safe.
func hashCode(_ code: String, salt: String) -> String {
    let input = Data((salt + code).utf8)
    let digest = SHA256.hash(data: input)
    return digest.map { String(format: "%02x", $0) }.joined()
}

/// Constant-time comparison of two hex strings.
func constantTimeEqual(_ a: String, _ b: String) -> Bool {
    let aBytes = Array(a.utf8)
    let bBytes = Array(b.utf8)
    guard aBytes.count == bBytes.count else { return false }
    var result: UInt8 = 0
    for i in 0..<aBytes.count {
        result |= aBytes[i] ^ bBytes[i]
    }
    return result == 0
}

// MARK: - Code Generation

/// Generate a cryptographically secure 6-digit OTP code.
func generateOtpCode() -> String {
    let code = Int.random(in: 100_000...999_999)
    return String(code)
}

// MARK: - OTP Service

/// Production-ready OTP service with rate limiting, expiry, and attempt tracking.
///
/// Usage:
/// ```swift
/// let service = OtpService(
///     sms: KwtSMS.fromEnv(),
///     store: MemoryOtpStore(),
///     appName: "MyApp",
///     deviceAttest: appAttestVerifier,  // optional: Apple App Attest
///     auth: jwtAuthenticator            // optional: require auth token
/// )
///
/// // In your send-otp route:
/// let result = await service.sendOtp(phone: body.phone, ip: clientIp)
///
/// // In your verify-otp route:
/// let result = await service.verifyOtp(phone: body.phone, code: body.code, ip: clientIp)
/// if result.success { /* issue JWT / create session */ }
/// ```
public actor OtpService {
    private let sms: KwtSMS
    private let store: OtpStoreProtocol
    private let deviceAttest: DeviceAttestVerifier?
    private let auth: TokenAuthenticator?
    private let appName: String

    /// In-memory rate limit tier (always active, resets on restart).
    private var memRateLimits: [String: [Date]] = [:]

    public init(
        sms: KwtSMS,
        store: OtpStoreProtocol,
        appName: String,
        deviceAttest: DeviceAttestVerifier? = nil,
        auth: TokenAuthenticator? = nil
    ) {
        self.sms = sms
        self.store = store
        self.appName = appName
        self.deviceAttest = deviceAttest
        self.auth = auth
    }

    // MARK: - sendOtp

    /// Send an OTP to a phone number.
    ///
    /// Full flow:
    ///   1. Sanitize + validate phone (no SMS credit wasted on bad numbers)
    ///   2. Validate auth token (if TokenAuthenticator configured — for 2FA flows)
    ///   3. Verify device attestation (if DeviceAttestVerifier configured — blocks scripts/bots)
    ///   4. Rate limit by IP (10 sends/hour)
    ///   5. Rate limit by phone (3 sends/hour)
    ///   6. Enforce 4-minute resend cooldown
    ///   7. Generate 6-digit code + hash it with salt
    ///   8. Persist record to store
    ///   9. Send SMS via kwtSMS (only after all checks pass)
    public func sendOtp(
        phone rawPhone: String,
        authToken: String? = nil,
        assertion: Data? = nil,
        keyId: String? = nil,
        clientData: Data? = nil,
        ip: String? = nil
    ) async -> SendOtpResult {
        // 1. Sanitize + validate phone
        let (phone, phoneError) = sanitizePhone(rawPhone)
        if let err = phoneError { return SendOtpResult(success: false, error: err) }

        // 2. Auth token validation (for 2FA: user must be partially authenticated)
        if let auth = auth {
            guard let token = authToken, !token.isEmpty else {
                return SendOtpResult(success: false, error: "Authentication token is required")
            }
            let valid = await auth.validate(token: token)
            if !valid {
                return SendOtpResult(success: false, error: "Invalid or expired authentication token")
            }
        }

        // 3. Device attestation (proves request comes from genuine app on real device)
        if let deviceAttest = deviceAttest {
            guard let assertion = assertion, let keyId = keyId, let clientData = clientData else {
                return SendOtpResult(success: false, error: "Device attestation is required")
            }
            let valid = await deviceAttest.verify(assertion: assertion, keyId: keyId, clientData: clientData)
            if !valid {
                return SendOtpResult(success: false, error: "Device attestation failed. Please update the app.")
            }
        }

        // 4. Rate limit by IP
        if let ip = ip {
            let (limited, retryAfter) = await checkRateLimit(key: "ip:\(ip)", max: MAX_SENDS_PER_IP, window: RATE_WINDOW_SECONDS)
            if limited {
                return SendOtpResult(success: false, error: "Too many requests from this IP address", retryAfter: retryAfter)
            }
        }

        // 4. Rate limit by phone
        let (phoneLimited, phoneRetry) = await checkRateLimit(key: "phone:\(phone)", max: MAX_SENDS_PER_PHONE, window: RATE_WINDOW_SECONDS)
        if phoneLimited {
            return SendOtpResult(success: false, error: "Too many OTP requests for this number", retryAfter: phoneRetry)
        }

        // 5. Resend cooldown (4 minutes between sends)
        let now = Date()
        if let existing = await store.get(phone: phone), now < existing.resendAllowedAt {
            let resendIn = Int(existing.resendAllowedAt.timeIntervalSince(now).rounded(.up))
            return SendOtpResult(success: false, error: "Please wait before requesting a new code", resendIn: resendIn)
        }

        // 6. Generate + hash code
        let code = generateOtpCode()
        let salt = generateSalt()
        let hashed = hashCode(code, salt: salt)

        // 7. Persist (overwrites any previous code for this number)
        let record = OtpRecord(
            phone: phone,
            codeHash: hashed,
            salt: salt,
            expiresAt: now.addingTimeInterval(OTP_TTL_SECONDS),
            resendAllowedAt: now.addingTimeInterval(RESEND_COOLDOWN_SECONDS),
            attempts: 0,
            used: false,
            createdAt: now,
            ipAddress: ip
        )
        await store.set(phone: phone, record: record)

        // 8. Send SMS (only after ALL checks pass)
        let message = "Your \(appName) verification code is: \(code). Valid for 5 minutes. Do not share this code."
        let result = await sms.send(mobile: phone, message: message)

        if result.result != "OK" {
            // Roll back stored record if SMS fails.
            // Rate-limit counters are NOT rolled back (intentional: failed sends still count).
            await store.delete(phone: phone)
            return SendOtpResult(success: false, error: result.description ?? "Failed to send OTP. Please try again.")
        }

        return SendOtpResult(success: true)
    }

    // MARK: - verifyOtp

    /// Verify an OTP code submitted by the user.
    ///
    /// Full flow:
    ///   1. Sanitize + validate both inputs
    ///   2. Rate limit verify attempts by phone (5/hour, brute-force guard)
    ///   3. Look up stored record
    ///   4. Check: already used
    ///   5. Check: expired
    ///   6. Check: too many wrong attempts (>= 3, delete record, force resend)
    ///   7. Hash comparison (constant-time)
    ///   8. Wrong: increment attempts. Correct: mark used.
    public func verifyOtp(phone rawPhone: String, code rawCode: String, authToken: String? = nil, ip: String? = nil) async -> VerifyOtpResult {
        // 1. Sanitize inputs
        let (phone, phoneError) = sanitizePhone(rawPhone)
        if let err = phoneError { return VerifyOtpResult(success: false, error: err) }

        let (code, codeError) = sanitizeCode(rawCode)
        if let err = codeError { return VerifyOtpResult(success: false, error: err) }

        // 1b. Auth token validation (if configured)
        if let auth = auth {
            guard let token = authToken, !token.isEmpty else {
                return VerifyOtpResult(success: false, error: "Authentication token is required")
            }
            let valid = await auth.validate(token: token)
            if !valid {
                return VerifyOtpResult(success: false, error: "Invalid or expired authentication token")
            }
        }

        // 2. Rate limit verify attempts (brute-force guard)
        let (limited, retryAfter) = await checkRateLimit(key: "verify:\(phone)", max: MAX_VERIFY_PER_PHONE, window: RATE_WINDOW_SECONDS)
        if limited {
            return VerifyOtpResult(success: false, error: "Too many verification attempts. Please wait.", retryAfter: retryAfter)
        }

        // 3. Look up record
        guard let record = await store.get(phone: phone) else {
            return VerifyOtpResult(success: false, error: "No OTP requested for this number. Please request a new code.")
        }

        // 4. Already used
        if record.used {
            return VerifyOtpResult(success: false, error: "This code has already been used. Please request a new one.")
        }

        // 5. Expired
        if Date() > record.expiresAt {
            await store.delete(phone: phone)
            return VerifyOtpResult(success: false, error: "Code has expired. Please request a new one.")
        }

        // 6. Too many wrong attempts
        if record.attempts >= MAX_ATTEMPTS {
            await store.delete(phone: phone)
            return VerifyOtpResult(success: false, error: "Too many wrong attempts. Please request a new code.")
        }

        // 7. Compare (constant-time)
        let inputHash = hashCode(code, salt: record.salt)
        let correct = constantTimeEqual(inputHash, record.codeHash)

        if !correct {
            let newAttempts = record.attempts + 1
            let attemptsLeft = MAX_ATTEMPTS - newAttempts
            if attemptsLeft <= 0 {
                await store.delete(phone: phone)
                return VerifyOtpResult(success: false, error: "Too many wrong attempts. Please request a new code.")
            }
            var updated = record
            updated.attempts = newAttempts
            await store.set(phone: phone, record: updated)
            return VerifyOtpResult(success: false, error: "Incorrect code", attemptsLeft: attemptsLeft)
        }

        // 8. Correct: mark as used (one-time use)
        var used = record
        used.used = true
        await store.set(phone: phone, record: used)
        return VerifyOtpResult(success: true)
    }

    // MARK: - Rate Limiter

    /// Two-tier sliding window rate limiter.
    /// Tier 1: In-memory (always runs, zero latency, resets on restart).
    /// Tier 2: DB-backed via store (if adapter implements it).
    private func checkRateLimit(key: String, max: Int, window: TimeInterval) async -> (limited: Bool, retryAfter: Int) {
        let now = Date()
        let windowStart = now.addingTimeInterval(-window)

        // Tier 1: In-memory sliding window
        var memHits = (memRateLimits[key] ?? []).filter { $0 > windowStart }
        if memHits.count >= max {
            let oldest = memHits.min()!
            let retryAfter = Int((oldest.addingTimeInterval(window).timeIntervalSince(now)).rounded(.up))
            return (true, retryAfter)
        }
        memHits.append(now)
        memRateLimits[key] = memHits

        // Tier 2: DB-backed (optional, only if adapter implements it)
        var dbHits = (await store.getRateLimit(key: key)).filter { $0 > windowStart }
        if dbHits.count >= max {
            let oldest = dbHits.min()!
            let retryAfter = Int((oldest.addingTimeInterval(window).timeIntervalSince(now)).rounded(.up))
            return (true, retryAfter)
        }
        dbHits.append(now)
        await store.setRateLimit(key: key, timestamps: dbHits)

        return (false, 0)
    }
}
