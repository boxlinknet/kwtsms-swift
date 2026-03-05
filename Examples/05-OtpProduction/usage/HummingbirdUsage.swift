/**
 * OTP endpoints — Hummingbird (lightweight Swift server framework)
 *
 * Add to your Package.swift dependencies:
 *   .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
 *   .package(url: "https://github.com/boxlinknet/kwtsms-swift.git", from: "0.1.0")
 *
 * Routes:
 *   POST /auth/send-otp     body: { "phone": "...", "assertion": "<base64>", "keyId": "..." }
 *   POST /auth/verify-otp   body: { "phone": "...", "code": "..." }
 *
 * Hummingbird is a newer, lighter alternative to Vapor.
 * Great for microservices and API-only backends.
 */

import Hummingbird
import KwtSMS

// MARK: - Request types

struct SendOtpRequest: Decodable {
    let phone: String
    let assertion: String?   // base64-encoded App Attest assertion
    let keyId: String?
    let authToken: String?
}

struct VerifyOtpRequest: Decodable {
    let phone: String
    let code: String
    let authToken: String?
}

// MARK: - Response types

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

    // Optional: Device attestation (recommended for iOS apps)
    // let deviceAttest = AppAttestVerifier(
    //     teamId: Environment.get("APP_ATTEST_TEAM_ID")!,
    //     bundleId: Environment.get("APP_ATTEST_BUNDLE_ID")!
    // )

    // Optional: Auth token validation (for 2FA flows)
    // let auth = MyJWTAuthenticator()

    let otp = OtpService(
        sms: sms,
        store: store,
        appName: "MyApp"
        // deviceAttest: deviceAttest,
        // auth: auth
    )

    let auth = router.group("auth")

    // POST /auth/send-otp
    auth.post("send-otp") { request, context -> Response in
        let body = try await request.decode(as: SendOtpRequest.self, context: context)

        let ip = request.headers[.xForwardedFor].first
            ?? context.remoteAddress?.ipAddress
            ?? "127.0.0.1"

        let assertion = body.assertion.flatMap { Data(base64Encoded: $0) }
        let clientData = body.phone.data(using: .utf8)

        let result = await otp.sendOtp(
            phone: body.phone,
            authToken: body.authToken,
            assertion: assertion,
            keyId: body.keyId,
            clientData: clientData,
            ip: ip
        )

        let status: HTTPResponse.Status = result.success ? .ok : (result.retryAfter != nil ? .tooManyRequests : .badRequest)
        return try Response(status: status, body: .init(data: JSONEncoder().encode(result)))
    }

    // POST /auth/verify-otp
    auth.post("verify-otp") { request, context -> Response in
        let body = try await request.decode(as: VerifyOtpRequest.self, context: context)

        let ip = request.headers[.xForwardedFor].first
            ?? context.remoteAddress?.ipAddress
            ?? "127.0.0.1"

        let result = await otp.verifyOtp(
            phone: body.phone,
            code: body.code,
            authToken: body.authToken,
            ip: ip
        )

        if result.success {
            // User is verified. Create session / issue JWT here.
            return try Response(status: .ok, body: .init(data: JSONEncoder().encode(SuccessResponse(success: true))))
        }

        let status: HTTPResponse.Status = result.retryAfter != nil ? .tooManyRequests : .badRequest
        return try Response(status: status, body: .init(data: JSONEncoder().encode(result)))
    }
}
