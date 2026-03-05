# Production OTP Flow with kwtSMS

A complete, production-ready SMS OTP implementation for Swift / iOS.
Built for mobile apps: device attestation instead of CAPTCHA, rate limiting, code hashing, framework wiring.

---

## How It Works

```
User enters phone number
        |
        v
1. Validate phone number locally       <- no SMS credit wasted on bad numbers
        |
        v
2. Validate auth token (if 2FA)        <- only authenticated users can request OTP
        |
        v
3. Verify device attestation           <- blocks bots/scripts (App Attest)
        |
        v
4. Check rate limits                   <- per-IP (10/hr) + per-phone (3/hr)
        |
        v
5. Check resend cooldown               <- 4-minute minimum between sends
        |
        v
6. Generate 6-digit code (cryptographic random)
        |
        v
7. Hash code with SHA-256 + salt       <- DB leak won't expose codes
        |
        v
8. Save to database                    <- with 5-minute expiry
        |
        v
9. Send SMS via kwtSMS                 <- only after ALL checks pass

-- User receives SMS, enters code --

10. Validate phone + code input        <- sanitize, strip non-digits
        |
        v
11. Rate limit verify attempts         <- max 5/hr (brute-force guard)
        |
        v
12. Check: used? expired? >3 attempts?
        |
        v
13. SHA-256 compare (constant-time)    <- wrong: increment attempts
        |                                 correct: mark used, return success
        v
14. User is verified                   <- issue JWT / create session
```

---

## Quick Start (5 minutes)

### 1. Add to Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/boxlinknet/kwtsms-swift.git", from: "0.1.0")
]
```

### 2. Set environment variables

```bash
# .env
KWTSMS_USERNAME=swift_username
KWTSMS_PASSWORD=swift_password
KWTSMS_SENDER_ID=YOUR-APP
KWTSMS_LOG_FILE=          # leave empty -- OTP codes would be logged otherwise
```

### 3. Copy and initialize

```swift
import KwtSMS

let otp = OtpService(
    sms: KwtSMS.fromEnv(),
    store: MemoryOtpStore(),   // swap for your DB adapter in production
    appName: "MyApp"
)
```

### 4. Wire up your routes

```swift
// Send OTP
let sendResult = await otp.sendOtp(phone: body.phone, ip: clientIp)
// sendResult.success / sendResult.error / sendResult.resendIn / sendResult.retryAfter

// Verify OTP
let verifyResult = await otp.verifyOtp(phone: body.phone, code: body.code, ip: clientIp)
if verifyResult.success {
    // Issue JWT / create session
}
```

See `usage/` for copy-paste route files for Vapor and Hummingbird.

---

## Input Validation: The Full Picture

Phone numbers go through 5 layers of validation before any SMS is sent:

| Step | What happens | Why |
|------|-------------|-----|
| Length guard | Rejects > 30 characters | Prevents memory attacks |
| trim() | Strips surrounding whitespace | Copy-paste safety |
| normalizePhone() | Strips +/00 prefix, spaces, dashes, dots, brackets; converts Arabic-Indic digits | Consistent format |
| validatePhoneInput() | Rejects emails, text, < 7 or > 15 digits | Catches invalid numbers before SMS send |

OTP codes go through 3 layers:

| Step | What happens | Why |
|------|-------------|-----|
| trim() | Strips surrounding whitespace | Copy-paste safety |
| Strip non-digits | "1 2 3 4 5 6" -> "123456" | Handles autofill formatting |
| Length check | Must be exactly 6 digits | Prevents empty/partial codes |

---

## Database Setup

### Option A: In-memory (development / testing)

Zero setup. Data lost on restart. Not shared across instances.

```swift
let store = MemoryOtpStore()
```

### Option B: Custom adapter (production)

Implement `OtpStoreProtocol` for any database (SQLite, PostgreSQL, Redis, etc.):

```swift
public actor MyDatabaseStore: OtpStoreProtocol {
    public func get(phone: String) async -> OtpRecord? {
        // SELECT * FROM otp_records WHERE phone = ?
    }

    public func set(phone: String, record: OtpRecord) async {
        // INSERT OR REPLACE INTO otp_records ...
    }

    public func delete(phone: String) async {
        // DELETE FROM otp_records WHERE phone = ?
    }

    public func getRateLimit(key: String) async -> [Date] {
        // SELECT timestamps FROM otp_rate_limits WHERE key = ?
        // Decode JSON array of ISO timestamps
    }

    public func setRateLimit(key: String, timestamps: [Date]) async {
        // INSERT OR REPLACE INTO otp_rate_limits (key, timestamps, updated_at) ...
    }
}
```

### SQL Schema (reference)

```sql
CREATE TABLE otp_records (
    phone           TEXT PRIMARY KEY,
    code_hash       TEXT NOT NULL,
    salt            TEXT NOT NULL,
    expires_at      REAL NOT NULL,
    resend_allowed_at REAL NOT NULL,
    attempts        INTEGER NOT NULL DEFAULT 0,
    used            INTEGER NOT NULL DEFAULT 0,
    created_at      REAL NOT NULL,
    ip_address      TEXT
);

CREATE TABLE otp_rate_limits (
    key         TEXT PRIMARY KEY,
    timestamps  TEXT NOT NULL,    -- JSON array of ISO date strings
    updated_at  REAL NOT NULL
);
```

---

## Device Attestation (Apple App Attest)

For iOS apps, device attestation replaces CAPTCHA. It proves each request comes from a genuine installation of YOUR app on a real Apple device.

### What it blocks

- Bots and scripts calling your API directly
- Modified/jailbroken app builds
- Replay attacks (each assertion is unique + counter-based)

### How it works

```
iOS App (client)                          Your Server (backend)
-------------------                       ---------------------
1. Generate key pair
   (DCAppAttestService.generateKey)

2. Attest key with Apple         ------->  3. Verify attestation with Apple
   (generateAttestation)                      Store public key for this device

4. On each request, sign data    ------->  5. Verify assertion signature
   (generateAssertion)                        against stored public key
```

### Client-side (iOS app)

```swift
import DeviceCheck
import CryptoKit

let service = DCAppAttestService.shared

// One-time: generate and attest a key
let keyId = try await service.generateKey()
let clientDataHash = Data(SHA256.hash(data: requestBodyData))
let attestation = try await service.attestKey(keyId, clientDataHash: clientDataHash)
// Send attestation + keyId to POST /auth/attest

// Each OTP request: generate an assertion
let assertion = try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
// Include assertion + keyId in POST /auth/send-otp body
```

### Server-side

```bash
APP_ATTEST_TEAM_ID=YOUR_TEAM_ID
APP_ATTEST_BUNDLE_ID=com.yourcompany.yourapp
```

```swift
let deviceAttest = AppAttestVerifier(
    teamId: ProcessInfo.processInfo.environment["APP_ATTEST_TEAM_ID"]!,
    bundleId: ProcessInfo.processInfo.environment["APP_ATTEST_BUNDLE_ID"]!
)

let otp = OtpService(
    sms: sms,
    store: store,
    appName: "MyApp",
    deviceAttest: deviceAttest
)
```

### Simulator fallback

`DCAppAttestService.shared.isSupported` returns `false` on the Simulator. During development, skip device attestation by not passing the `deviceAttest` parameter.

---

## Auth Token Validation (JWT / Session)

For 2FA flows where the user is already partially authenticated (e.g., they entered their password and now need SMS verification), require a valid auth token before allowing OTP operations.

### Setup

```swift
struct MyJWTAuthenticator: TokenAuthenticator {
    func validate(token: String) async -> Bool {
        // Decode and verify JWT signature, expiry, issuer
        // Return true if valid
    }
}

let otp = OtpService(
    sms: sms,
    store: store,
    appName: "MyApp",
    auth: MyJWTAuthenticator()
)
```

### Usage

```swift
// Client sends auth token in request
let result = await otp.sendOtp(phone: body.phone, authToken: body.authToken, ip: clientIp)

// If auth is configured and token is missing/invalid:
// result.success = false
// result.error = "Authentication token is required" or "Invalid or expired authentication token"
```

### When to use

| Scenario | Device Attest | Auth Token | Both |
|----------|:---:|:---:|:---:|
| Signup (new user, no account yet) | Yes | No | -- |
| Login (phone as primary auth) | Yes | No | -- |
| 2FA (password + SMS) | Yes | Yes | Yes |
| Account recovery | Yes | No | -- |

---

## Rate Limiting

### How it works

Two-tier sliding window. Both tiers must pass.

| Tier | Storage | Survives restart | Multi-instance |
|------|---------|-----------------|---------------|
| In-memory | Dictionary<String, [Date]> | No | No (per-process) |
| DB-backed | otp_rate_limits table | Yes | Yes (shared) |

**Limits:**

| What | Window | Max |
|------|--------|-----|
| Sends per IP | 1 hour | 10 |
| Sends per phone | 1 hour | 3 |
| Verify attempts per phone | 1 hour | 5 |
| Resend cooldown | -- | 4 minutes |

### Default: in-memory

Works out of the box. Resets on server restart. Fine for single-process apps.

### Production: DB-backed

Enabled automatically when your adapter implements `getRateLimit`/`setRateLimit`.
Custom database adapters that implement these methods get persistent rate limiting for free.

---

## Framework Wiring

| Framework | File | IP extraction |
|-----------|------|--------------|
| Vapor | `usage/VaporUsage.swift` | `X-Forwarded-For` header / `req.peerAddress` |
| Hummingbird | `usage/HummingbirdUsage.swift` | `X-Forwarded-For` header / `context.remoteAddress` |

---

## Environment Variables

```bash
# Required -- kwtSMS credentials
KWTSMS_USERNAME=swift_username
KWTSMS_PASSWORD=swift_password
KWTSMS_SENDER_ID=YOUR-APP

# IMPORTANT for OTP: disable logging (OTP codes appear in message bodies)
KWTSMS_LOG_FILE=

# Optional -- Device attestation
APP_ATTEST_TEAM_ID=YOUR_TEAM_ID
APP_ATTEST_BUNDLE_ID=com.yourcompany.yourapp
```

---

## Security Checklist

Before going live, confirm:

- [ ] `KWTSMS_LOG_FILE=` (empty): OTP codes must NOT be logged
- [ ] Device attestation enabled for production iOS builds
- [ ] Auth token validation enabled if this is a 2FA flow
- [ ] Reverse proxy trust configured correctly (Vapor/Hummingbird)
- [ ] `.env` file has proper permissions (not committed to git)
- [ ] Using a persistent database adapter (not memory) in production
- [ ] OTP codes are hashed: SHA-256 with per-code salt (handled by OtpService)
- [ ] `appName` set to your real app name (telecom compliance)
- [ ] `KWTSMS_TEST_MODE=0` in production (live mode)
- [ ] Running on HTTPS in production (tokens interceptable over HTTP)
- [ ] Transactional Sender ID registered (not KWT-SMS or promotional)

---

## Common Mistakes

### Logging OTP codes

```bash
# Wrong -- OTP codes will appear in kwtsms.log
KWTSMS_LOG_FILE=kwtsms.log

# Correct -- disable logging for OTP use cases
KWTSMS_LOG_FILE=
```

### Using raw phone as session/store key

```swift
// Wrong -- "+96598765432" and "96598765432" are treated as different users
store.set(phone: rawInput, record: record)

// Correct -- normalizePhone() is called internally, but use it in YOUR code too
import KwtSMS
let userId = normalizePhone(rawInput)
session.userId = userId
```

### Comparing codes directly

```swift
// Wrong -- timing attack possible + plain text stored
if stored.code == userInput { ... }

// Correct -- this library handles it internally via SHA-256 + constant-time compare
// Just call verifyOtp() -- never compare codes yourself
```

### Sending SMS before all checks pass

```swift
// Wrong -- sends SMS even if rate limited
let _ = await sms.send(mobile: phone, message: message)
let _ = await checkRateLimit(...)

// Correct -- all checks run first (this library handles it)
let result = await otp.sendOtp(phone: phone, ip: ip)
```

### Skipping device attestation in production

```swift
// Wrong -- any script can call your API
let otp = OtpService(sms: sms, store: store, appName: "MyApp")

// Correct -- prove requests come from your real app
let otp = OtpService(
    sms: sms,
    store: store,
    appName: "MyApp",
    deviceAttest: AppAttestVerifier(teamId: "...", bundleId: "...")
)
```
