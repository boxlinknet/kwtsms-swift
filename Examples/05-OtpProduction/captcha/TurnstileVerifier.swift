/**
 * Cloudflare Turnstile CAPTCHA verifier.
 *
 * Privacy-friendly, free, unlimited verifications.
 * Works great alongside kwtSMS for Kuwait/GCC markets.
 *
 * Setup (5 minutes):
 *   1. Go to: https://dash.cloudflare.com → Zero Trust → Turnstile
 *   2. Click "Add site"
 *   3. Enter your site name and domain
 *   4. Copy the Site Key (for your frontend) and Secret Key (for this file)
 *   5. Set environment variable: TURNSTILE_SECRET=your_secret_key
 *
 * Frontend (add to your HTML):
 *   <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
 *   <div class="cf-turnstile" data-sitekey="YOUR_SITE_KEY"></div>
 *
 *   When the user submits your form, read the token:
 *   const token = document.querySelector('[name="cf-turnstile-response"]').value;
 *   // Send token to your backend in the request body as captchaToken
 *
 * Backend:
 *   let secret = ProcessInfo.processInfo.environment["TURNSTILE_SECRET"]!
 *   let captcha = TurnstileVerifier(secret: secret)
 *   let service = OtpService(sms: sms, store: store, appName: "MyApp", captcha: captcha)
 *
 * Environment variable:
 *   TURNSTILE_SECRET=your_secret_key_here
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Cloudflare Turnstile CAPTCHA verification.
public struct TurnstileVerifier: CaptchaVerifier, Sendable {
    private let secret: String

    public init(secret: String) {
        self.secret = secret
    }

    public func verify(token: String, ip: String?) async -> Bool {
        if token.isEmpty { return false }

        var body: [String: String] = [
            "secret": secret,
            "response": token
        ]
        if let ip = ip { body["remoteip"] = ip }

        guard let url = URL(string: "https://challenges.cloudflare.com/turnstile/v0/siteverify") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let success = json["success"] as? Bool {
                return success
            }
        } catch {
            // Network/parse failure → fail closed (reject)
        }
        return false
    }
}
