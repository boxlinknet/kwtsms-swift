/**
 * OTP endpoints — Vapor (Swift server framework)
 *
 * Add to your Package.swift dependencies:
 *   .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
 *   .package(url: "https://github.com/boxlinknet/kwtsms-swift.git", from: "0.1.0")
 *
 * Routes:
 *   POST /auth/attest       body: { "keyId": "...", "attestation": "<base64>", "clientData": "<base64>" }
 *   POST /auth/send-otp     body: { "phone": "...", "assertion": "<base64>", "keyId": "..." }
 *   POST /auth/verify-otp   body: { "phone": "...", "code": "..." }
 *
 * IP extraction:
 *   Uses req.peerAddress or X-Forwarded-For header (for reverse proxy setups).
 *   Configure app.middleware.use(FileMiddleware(...)) and trust proxy as needed.
 */

import Vapor
import KwtSMS

// MARK: - Request types

struct AttestDeviceRequest: Content {
    let keyId: String
    let attestation: String  // base64-encoded
    let clientData: String   // base64-encoded
}

struct SendOtpRequest: Content {
    let phone: String
    let assertion: String?   // base64-encoded App Attest assertion
    let keyId: String?       // App Attest key ID
    let authToken: String?   // optional JWT for 2FA flows
}

struct VerifyOtpRequest: Content {
    let phone: String
    let code: String
    let authToken: String?
}

// MARK: - Setup

/// Call this from your configure.swift to register OTP routes.
///
/// Example:
///   func configure(_ app: Application) throws {
///       registerOtpRoutes(app)
///   }
func registerOtpRoutes(_ app: Application) {
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

    let auth = app.grouped("auth")

    // POST /auth/attest — one-time device registration
    // Call this after DCAppAttestService.attestKey() on the client
    // auth.post("attest") { req async throws -> Response in
    //     let body = try req.content.decode(AttestDeviceRequest.self)
    //     guard let attestation = Data(base64Encoded: body.attestation),
    //           let clientData = Data(base64Encoded: body.clientData) else {
    //         throw Abort(.badRequest, reason: "Invalid base64 encoding")
    //     }
    //     let ok = await deviceAttest.registerDevice(
    //         keyId: body.keyId,
    //         attestation: attestation,
    //         clientDataHash: clientData
    //     )
    //     guard ok else { throw Abort(.forbidden, reason: "Device attestation failed") }
    //     return Response(status: .ok)
    // }

    // POST /auth/send-otp
    auth.post("send-otp") { req async throws -> Response in
        let body = try req.content.decode(SendOtpRequest.self)

        let ip = req.headers.first(name: .xForwardedFor)
            ?? req.peerAddress?.description
            ?? "127.0.0.1"

        // Decode assertion if provided (base64 → Data)
        let assertion = body.assertion.flatMap { Data(base64Encoded: $0) }
        let clientData = body.phone.data(using: .utf8)  // hash of request body in production

        let result = await otp.sendOtp(
            phone: body.phone,
            authToken: body.authToken,
            assertion: assertion,
            keyId: body.keyId,
            clientData: clientData,
            ip: ip
        )

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

        let result = await otp.verifyOtp(
            phone: body.phone,
            code: body.code,
            authToken: body.authToken,
            ip: ip
        )

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

// MARK: - Example JWT Authenticator

// Uncomment and implement with your JWT library (e.g., vapor/jwt):
//
// struct MyJWTAuthenticator: TokenAuthenticator {
//     func validate(token: String) async -> Bool {
//         do {
//             let payload = try app.jwt.signers.verify(token, as: UserPayload.self)
//             return payload.expiration.value > Date()
//         } catch {
//             return false
//         }
//     }
// }
