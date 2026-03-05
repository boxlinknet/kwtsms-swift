/**
 * hCaptcha CAPTCHA verifier.
 *
 * Privacy-focused alternative to reCAPTCHA. GDPR-safe.
 * Free tier: up to 1 million verifications/month.
 * Popular in MENA region and privacy-conscious applications.
 *
 * Setup (5 minutes):
 *   1. Go to: https://dashboard.hcaptcha.com/signup
 *   2. Create a new site
 *   3. Copy the Site Key (for your frontend) and Secret Key (for this file)
 *   4. Set environment variable: HCAPTCHA_SECRET=your_secret_key
 *
 * Frontend (add to your HTML):
 *   <script src="https://js.hcaptcha.com/1/api.js" async defer></script>
 *   <div class="h-captcha" data-sitekey="YOUR_SITE_KEY"></div>
 *
 *   When the user submits your form, read the token:
 *   const token = document.querySelector('[name="h-captcha-response"]').value;
 *   // Send token to your backend in the request body as captchaToken
 *
 * Backend:
 *   let secret = ProcessInfo.processInfo.environment["HCAPTCHA_SECRET"]!
 *   let captcha = HCaptchaVerifier(secret: secret)
 *   let service = OtpService(sms: sms, store: store, appName: "MyApp", captcha: captcha)
 *
 * Environment variable:
 *   HCAPTCHA_SECRET=your_secret_key_here
 */

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// hCaptcha CAPTCHA verification.
public struct HCaptchaVerifier: CaptchaVerifier, Sendable {
    private let secret: String

    public init(secret: String) {
        self.secret = secret
    }

    public func verify(token: String, ip: String?) async -> Bool {
        if token.isEmpty { return false }

        // hCaptcha uses application/x-www-form-urlencoded
        var params = "secret=\(urlEncode(secret))&response=\(urlEncode(token))"
        if let ip = ip { params += "&remoteip=\(urlEncode(ip))" }

        guard let url = URL(string: "https://hcaptcha.com/siteverify") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5
        request.httpBody = params.data(using: .utf8)

        do {
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

    /// Percent-encode a string for URL form data.
    private func urlEncode(_ string: String) -> String {
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}
