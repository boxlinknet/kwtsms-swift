import Foundation
import KwtSMS

// OTP configuration
let appName = "MyApp"
let otpLength = 6
let otpExpiryMinutes = 5

// Generate a random OTP code
func generateOTP() -> String {
    let digits = (0..<otpLength).map { _ in String(Int.random(in: 0...9)) }
    return digits.joined()
}

// Send OTP to a phone number
func sendOTP(phone: String, sms: KwtSMS) async {
    // 1. Validate the phone number first
    let (valid, error, normalized) = validatePhoneInput(phone)
    guard valid else {
        print("Invalid phone: \(error!)")
        return
    }

    // 2. Generate a fresh code (always new on each request)
    let code = generateOTP()

    // 3. Include app name in message (telecom compliance)
    let message = "Your OTP for \(appName) is: \(code). Valid for \(otpExpiryMinutes) minutes."

    // 4. Send to one number per request (never batch OTP sends)
    let result = await sms.send(mobile: normalized, message: message)

    if result.result == "OK" {
        print("OTP sent to \(normalized)")
        print("Message ID: \(result.msgId ?? "") (save this)")
        // Store: code, normalized phone, expiry time, msg-id
    } else {
        print("Failed: \(result.description ?? "")")
        print("Action: \(result.action ?? "")")
    }
}

// Usage
let sms = KwtSMS(
    username: "your_user",
    password: "your_pass",
    senderId: "MY-APP-TXN",  // Use a Transactional sender ID for OTP
    testMode: true
)

await sendOTP(phone: "+96598765432", sms: sms)
