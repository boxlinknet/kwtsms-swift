/**
 * OTP endpoints — Vapor (Swift server framework)
 *
 * Add to your Package.swift dependencies:
 *   .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
 *   .package(url: "https://github.com/boxlinknet/kwtsms-swift.git", from: "0.1.0")
 *
 * Routes:
 *   POST /auth/send-otp    body: { "phone": "...", "captchaToken": "..." }
 *   POST /auth/verify-otp  body: { "phone": "...", "code": "..." }
 *
 * IP extraction:
 *   Uses req.peerAddress or X-Forwarded-For header (for reverse proxy setups).
 *   Configure app.middleware.use(FileMiddleware(...)) and trust proxy as needed.
 */

import Vapor
import KwtSMS

// MARK: - Request/Response types

struct SendOtpRequest: Content {
    let phone: String
    let captchaToken: String?
}

struct VerifyOtpRequest: Content {
    let phone: String
    let code: String
}

// MARK: - Setup

/// Call this from your configure.swift to register OTP routes.
///
/// Example:
///   func configure(_ app: Application) throws {
///       registerOtpRoutes(app)
///   }
func registerOtpRoutes(_ app: Application) {
    // Initialize kwtSMS client from environment variables
    let sms = KwtSMS.fromEnv()

    // Choose your store adapter:
    let store = MemoryOtpStore()
    // let store = SQLiteOtpStore(path: "./otp.db")  // for production

    // Optional: CAPTCHA
    // let secret = Environment.get("TURNSTILE_SECRET")!
    // let captcha = TurnstileVerifier(secret: secret)

    let otp = OtpService(
        sms: sms,
        store: store,
        appName: "MyApp"
        // captcha: captcha
    )

    // MARK: - Routes

    let auth = app.grouped("auth")

    // POST /auth/send-otp
    auth.post("send-otp") { req async throws -> Response in
        let body = try req.content.decode(SendOtpRequest.self)

        // Extract client IP (X-Forwarded-For for reverse proxy, or peer address)
        let ip = req.headers.first(name: .xForwardedFor)
            ?? req.peerAddress?.description
            ?? "127.0.0.1"

        let result = await otp.sendOtp(phone: body.phone, captchaToken: body.captchaToken, ip: ip)

        let status: HTTPResponseStatus = result.success ? .ok : (result.retryAfter != nil ? .tooManyRequests : .badRequest)
        let response = Response(status: status)
        try response.content.encode(result)
        return response
    }

    // POST /auth/verify-otp
    auth.post("verify-otp") { req async throws -> Response in
        let body = try req.content.decode(VerifyOtpRequest.self)

        let ip = req.headers.first(name: .xForwardedFor)
            ?? req.peerAddress?.description
            ?? "127.0.0.1"

        let result = await otp.verifyOtp(phone: body.phone, code: body.code, ip: ip)

        if result.success {
            // User is verified. Create session / issue JWT here:
            // let token = try req.jwt.sign(UserPayload(phone: body.phone))
            let response = Response(status: .ok)
            try response.content.encode(["success": true])
            return response
        }

        let status: HTTPResponseStatus = result.retryAfter != nil ? .tooManyRequests : .badRequest
        let response = Response(status: status)
        try response.content.encode(result)
        return response
    }
}

// MARK: - Make result types Vapor-encodable

extension SendOtpResult: Content {}
extension VerifyOtpResult: Content {}
