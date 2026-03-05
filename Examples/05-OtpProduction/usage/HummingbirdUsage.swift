/**
 * OTP endpoints — Hummingbird (lightweight Swift server framework)
 *
 * Add to your Package.swift dependencies:
 *   .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
 *   .package(url: "https://github.com/boxlinknet/kwtsms-swift.git", from: "0.1.0")
 *
 * Routes:
 *   POST /auth/send-otp    body: { "phone": "...", "captchaToken": "..." }
 *   POST /auth/verify-otp  body: { "phone": "...", "code": "..." }
 *
 * Hummingbird is a newer, lighter alternative to Vapor.
 * Great for microservices and API-only backends.
 */

import Hummingbird
import KwtSMS

// MARK: - Request types

struct SendOtpRequest: Decodable {
    let phone: String
    let captchaToken: String?
}

struct VerifyOtpRequest: Decodable {
    let phone: String
    let code: String
}

// MARK: - Response types (Codable for JSON encoding)

struct SuccessResponse: ResponseCodable {
    let success: Bool
}

// MARK: - Setup

/// Add OTP routes to a Hummingbird router.
///
/// Example:
///   let router = Router()
///   addOtpRoutes(to: router)
///   let app = Application(router: router)
///   try await app.runService()
func addOtpRoutes(to router: Router<some RequestContext>) {
    let sms = KwtSMS.fromEnv()
    let store = MemoryOtpStore()

    // Optional: CAPTCHA
    // let captcha = TurnstileVerifier(secret: Environment.get("TURNSTILE_SECRET")!)

    let otp = OtpService(
        sms: sms,
        store: store,
        appName: "MyApp"
        // captcha: captcha
    )

    let auth = router.group("auth")

    // POST /auth/send-otp
    auth.post("send-otp") { request, context -> Response in
        let body = try await request.decode(as: SendOtpRequest.self, context: context)

        // Extract client IP from X-Forwarded-For or connection
        let ip = request.headers[.xForwardedFor].first
            ?? context.remoteAddress?.ipAddress
            ?? "127.0.0.1"

        let result = await otp.sendOtp(phone: body.phone, captchaToken: body.captchaToken, ip: ip)

        let status: HTTPResponse.Status = result.success ? .ok : (result.retryAfter != nil ? .tooManyRequests : .badRequest)
        return try Response(status: status, body: .init(data: JSONEncoder().encode(result)))
    }

    // POST /auth/verify-otp
    auth.post("verify-otp") { request, context -> Response in
        let body = try await request.decode(as: VerifyOtpRequest.self, context: context)

        let ip = request.headers[.xForwardedFor].first
            ?? context.remoteAddress?.ipAddress
            ?? "127.0.0.1"

        let result = await otp.verifyOtp(phone: body.phone, code: body.code, ip: ip)

        if result.success {
            // User is verified. Create session / issue JWT here.
            return try Response(status: .ok, body: .init(data: JSONEncoder().encode(SuccessResponse(success: true))))
        }

        let status: HTTPResponse.Status = result.retryAfter != nil ? .tooManyRequests : .badRequest
        return try Response(status: status, body: .init(data: JSONEncoder().encode(result)))
    }
}
