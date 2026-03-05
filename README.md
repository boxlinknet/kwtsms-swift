# kwtsms-swift

Official Swift client library for the [kwtSMS](https://www.kwtsms.com/integrations.html) SMS gateway API.

Zero dependencies. Async/await. Thread-safe. Works on iOS, macOS, tvOS, watchOS, and Linux (server-side Swift).

## Install

### Swift Package Manager (Xcode)

1. Open your project in Xcode.
2. File > Add Package Dependencies.
3. Enter: `https://github.com/boxlinknet/kwtsms-swift.git`
4. Select version `0.1.0` or later.

### Swift Package Manager (Package.swift)

```swift
dependencies: [
    .package(url: "https://github.com/boxlinknet/kwtsms-swift.git", from: "0.1.0")
]
```

Add to your target:

```swift
.target(name: "YourApp", dependencies: [
    .product(name: "KwtSMS", package: "kwtsms-swift")
])
```

## Quick Start

```swift
import KwtSMS

// Create client with explicit credentials
let sms = KwtSMS(username: "swift_username", password: "swift_password")

// Or load from environment variables / .env file
let sms = KwtSMS.fromEnv()

// Send an SMS
let result = await sms.send(mobile: "96598765432", message: "Hello from Swift!")
if result.result == "OK" {
    print("Sent! Message ID: \(result.msgId ?? "")")
    print("Balance: \(result.balanceAfter ?? 0)")
}
```

## API Methods

All methods are `async` and thread-safe (the client is a Swift `actor`).

### verify()

Test your credentials and get the current balance. Never throws.

```swift
let result = await sms.verify()
if result.ok {
    print("Balance: \(result.balance!)")
} else {
    print("Error: \(result.error!)")
}
```

### balance()

Get the current SMS credit balance. Returns the cached value if the API call fails.

```swift
let balance = await sms.balance()
print("Credits: \(balance ?? 0)")
```

### send()

Send an SMS to one or more phone numbers.

```swift
// Single number
let result = await sms.send(mobile: "96598765432", message: "Your OTP is: 123456")

// Multiple numbers (comma-separated)
let result = await sms.send(mobile: "96598765432,96512345678", message: "Hello!")

// Array of numbers
let result = await sms.send(mobiles: ["96598765432", "96512345678"], message: "Hello!")

// Custom sender ID
let result = await sms.send(mobile: "96598765432", message: "Hello!", sender: "MY-APP")

// Check result
if result.result == "OK" {
    print("Message ID: \(result.msgId!)")       // Save this for status/DLR
    print("Balance: \(result.balanceAfter!)")    // No need to call balance() again
} else {
    print("Error: \(result.code ?? "") \(result.description ?? "")")
    print("Action: \(result.action ?? "")")      // Developer-friendly guidance
}
```

**Bulk send (>200 numbers)** is handled automatically. Numbers are split into batches of 200 with a 0.5-second delay between batches:

```swift
let result = await sms.sendBulk(mobiles: largeNumberArray, message: "Campaign message")
print("Batches: \(result.batches), Sent: \(result.numbers)")
```

### validate()

Validate phone numbers before sending.

```swift
let result = await sms.validate(phones: ["+96598765432", "user@email.com", "123"])
print("Valid: \(result.ok)")      // API-validated OK numbers
print("Errors: \(result.er)")     // Format errors
print("No route: \(result.nr)")   // Country not activated
print("Rejected: \(result.rejected)")  // Failed local validation (email, too short, etc.)
```

### senderIds()

List available sender IDs on your account.

```swift
let result = await sms.senderIds()
if result.result == "OK" {
    print("Sender IDs: \(result.senderIds)")
}
```

### coverage()

List active country prefixes for SMS delivery.

```swift
let result = await sms.coverage()
if result.result == "OK" {
    print("Active prefixes: \(result.prefixes)")
}
```

### status()

Check the status of a sent message.

```swift
let result = await sms.status(msgId: "f4c841adee210f31307633ceaebff2ec")
if result.result == "OK" {
    print("Status: \(result.status ?? "")")
    print("Description: \(result.statusDescription ?? "")")
}
```

### deliveryReport()

Get delivery reports for international numbers (Kuwait numbers do not have DLR).

```swift
let result = await sms.deliveryReport(msgId: "f4c841adee210f31307633ceaebff2ec")
if result.result == "OK" {
    for entry in result.report {
        print("\(entry.number): \(entry.status)")
    }
}
```

## Utility Functions

These are exported publicly for use outside the client:

```swift
import KwtSMS

// Normalize a phone number (strip +, 00, spaces, dashes, convert Arabic digits)
let normalized = normalizePhone("+965 9876-5432")  // "96598765432"

// Validate a phone number
let (valid, error, normalized) = validatePhoneInput("user@email.com")
// (false, "'user@email.com' is an email address, not a phone number", "")

// Clean a message (strip emojis, HTML, control chars, convert Arabic digits)
let cleaned = cleanMessage("Hello \u{1F600} <b>World</b>")  // "Hello  World"
```

## Error Handling

Every error response includes a developer-friendly `action` field:

```swift
let result = await sms.send(mobile: "96598765432", message: "Hello")
if result.result == "ERROR" {
    print(result.code!)        // "ERR003"
    print(result.description!) // "Authentication error..."
    print(result.action!)      // "Wrong API username or password. Check KWTSMS_USERNAME..."
}
```

All 33 kwtSMS error codes are mapped. Access the full table via `apiErrors`:

```swift
for (code, action) in apiErrors {
    print("\(code): \(action)")
}
```

## Input Validation

The `send()` method automatically:
1. Normalizes all phone numbers (strips `+`, `00`, spaces, dashes, converts Arabic digits).
2. Validates each number locally (rejects emails, too-short, too-long, no-digits).
3. Deduplicates normalized numbers (e.g., `+96598765432` and `0096598765432` count as one).
4. Cleans the message text (strips emojis, HTML tags, hidden control characters).
5. Reports invalid numbers in the `invalid` field without crashing the call.

```swift
let result = await sms.send(
    mobiles: ["96598765432", "user@email.com", "123"],
    message: "Hello!"
)
// result.invalid = [
//   InvalidEntry(input: "user@email.com", error: "...is an email address..."),
//   InvalidEntry(input: "123", error: "...is too short (3 digits, minimum is 7)")
// ]
// The valid number "96598765432" is still sent to the API.
```

## Credential Management

**Never hardcode credentials.** Use one of these approaches:

### Environment variables (server-side, recommended)

```bash
export KWTSMS_USERNAME=swift_username
export KWTSMS_PASSWORD=swift_password
export KWTSMS_SENDER_ID=YOUR-SENDER    # optional, defaults to KWT-SMS
export KWTSMS_TEST_MODE=0              # optional, set 1 for test mode
export KWTSMS_LOG_FILE=kwtsms.log      # optional, empty string disables logging
```

```swift
let sms = KwtSMS.fromEnv()
```

### .env file (server-side)

Create a `.env` file (add to `.gitignore`):

```ini
KWTSMS_USERNAME=swift_username
KWTSMS_PASSWORD=swift_password
KWTSMS_SENDER_ID=YOUR-SENDER
KWTSMS_TEST_MODE=0
```

```swift
let sms = KwtSMS.fromEnv(envFile: ".env")
```

### Constructor injection (any platform)

```swift
let sms = KwtSMS(
    username: config.smsUsername,
    password: config.smsPassword,
    senderId: "MY-APP",
    testMode: false
)
```

### iOS apps: backend proxy (strongly recommended)

The compiled binary can be reverse-engineered. Never store API credentials in the app.

```swift
// Your backend holds kwtSMS credentials and exposes a /send-otp endpoint
let url = URL(string: "https://your-backend.com/api/send-otp")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.httpBody = try JSONEncoder().encode(["phone": phoneNumber])
let (data, _) = try await URLSession.shared.data(for: request)
```

### iOS apps: Keychain (if direct API access is needed)

```swift
import Security

// Store credentials in Keychain (not UserDefaults, not Info.plist)
func saveToKeychain(key: String, value: String) {
    let data = value.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data
    ]
    SecItemDelete(query as CFDictionary)
    SecItemAdd(query as CFDictionary, nil)
}
```

## Test Mode

Set `testMode: true` to queue messages without delivering them. No credits consumed.

```swift
let sms = KwtSMS(username: "swift_username", password: "swift_password", testMode: true)
let result = await sms.send(mobile: "96598765432", message: "Test")
// Message appears in kwtsms.com Queue but is not delivered.
// Delete from Queue to recover any held credits.
```

## Best Practices

### Always save msg-id and balance-after

```swift
let result = await sms.send(mobile: "96598765432", message: "OTP: 123456")
if result.result == "OK" {
    db.saveMsgId(result.msgId!)              // Needed for status() and deliveryReport()
    db.saveBalance(result.balanceAfter!)     // No need to call balance() separately
}
```

### Sender ID

- `KWT-SMS` is for testing only. Register a private sender ID before going live.
- Sender ID is case sensitive: `Kuwait` is not the same as `KUWAIT`.
- For OTP/authentication, use a Transactional sender ID (bypasses DND filters).
- Promotional sender IDs are silently blocked for DND subscribers, credits still deducted.

### Timestamps

API `unix-timestamp` values are in GMT+3 (Asia/Kuwait server time), not UTC. Convert when storing.

### Security Checklist

Before going live:

- [ ] Bot protection enabled (Device Attestation for iOS, CAPTCHA for web)
- [ ] Rate limit per phone number (max 3-5/hour)
- [ ] Rate limit per IP address (max 10-20/hour)
- [ ] Rate limit per user/session if authenticated
- [ ] Monitoring/alerting on abuse patterns
- [ ] Admin notification on low balance
- [ ] Test mode OFF (`testMode: false`)
- [ ] Private Sender ID registered (not KWT-SMS)
- [ ] Transactional Sender ID for OTP (not promotional)

## Publishing

Swift packages are published via git tags on GitHub.

1. Push code to `github.com/boxlinknet/kwtsms-swift`.
2. Validate the package:
   ```bash
   swift package describe
   ```
3. Tag a release:
   ```bash
   git tag 0.1.0
   git push origin 0.1.0
   ```
4. Users add in Xcode: File > Add Package Dependencies > enter `https://github.com/boxlinknet/kwtsms-swift.git`.

The package is also auto-indexed on [Swift Package Index](https://swiftpackageindex.com) after tagging.

## Requirements

- Swift 5.7+
- iOS 15+ / macOS 12+ / tvOS 15+ / watchOS 8+
- Linux (server-side Swift with Foundation)
- Zero external dependencies

## License

MIT. See [LICENSE](LICENSE).
