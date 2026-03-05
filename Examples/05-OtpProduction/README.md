# Production OTP Flow with kwtSMS

A complete, production-ready SMS OTP implementation for Swift.
Drop-in adapters for any database. Framework wiring for Vapor and Hummingbird.

---

## How It Works

```
User enters phone number
        |
        v
1. Validate phone number locally       <- no SMS credit wasted on bad numbers
        |
        v
2. Verify CAPTCHA (if configured)      <- blocks bots before any DB/SMS work
        |
        v
3. Check rate limits                   <- per-IP (10/hr) + per-phone (3/hr)
        |
        v
4. Check resend cooldown               <- 4-minute minimum between sends
        |
        v
5. Generate 6-digit code (cryptographic random)
        |
        v
6. Hash code with SHA-256 + salt       <- DB leak won't expose codes
        |
        v
7. Save to database                    <- with 5-minute expiry
        |
        v
8. Send SMS via kwtSMS                 <- only after ALL checks pass

-- User receives SMS, enters code --

9. Validate phone + code input         <- sanitize, strip non-digits
        |
        v
10. Rate limit verify attempts         <- max 5/hr (brute-force guard)
        |
        v
11. Check: used? expired? >3 attempts?
        |
        v
12. SHA-256 compare (constant-time)    <- wrong: increment attempts
        |                                correct: mark used, return success
        v
13. User is verified                   <- issue JWT / create session
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
let sendResult = await otp.sendOtp(phone: body.phone, captchaToken: body.token, ip: clientIp)
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

## CAPTCHA Setup

### Option A: No CAPTCHA (trusted clients / dev)

Omit the `captcha` parameter entirely.

```swift
let otp = OtpService(sms: sms, store: store, appName: "MyApp")
```

### Option B: Cloudflare Turnstile (recommended)

Free. Unlimited. Privacy-friendly. Works great in Kuwait/GCC.

**Get your keys (5 minutes):**
1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) -> Zero Trust -> Turnstile
2. Click "Add site" -> enter your domain
3. Copy **Site Key** (frontend) and **Secret Key** (backend)

**Add to your HTML:**
```html
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
<div class="cf-turnstile" data-sitekey="YOUR_SITE_KEY"></div>
```

**Read the token on form submit:**
```javascript
const token = document.querySelector('[name="cf-turnstile-response"]').value;
// Include in your fetch: { phone, captchaToken: token }
```

**Backend:**
```bash
TURNSTILE_SECRET=your_secret_key
```

```swift
let captcha = TurnstileVerifier(secret: ProcessInfo.processInfo.environment["TURNSTILE_SECRET"]!)
let otp = OtpService(sms: sms, store: store, appName: "MyApp", captcha: captcha)
```

### Option C: hCaptcha

Privacy-focused. GDPR-safe. Free tier: 1M verifications/month.

**Get your keys:**
1. Go to [dashboard.hcaptcha.com/signup](https://dashboard.hcaptcha.com/signup)
2. Create a new site
3. Copy **Site Key** and **Secret Key**

**Add to your HTML:**
```html
<script src="https://js.hcaptcha.com/1/api.js" async defer></script>
<div class="h-captcha" data-sitekey="YOUR_SITE_KEY"></div>
```

**Read the token:**
```javascript
const token = document.querySelector('[name="h-captcha-response"]').value;
```

**Backend:**
```bash
HCAPTCHA_SECRET=your_secret_key
```

```swift
let captcha = HCaptchaVerifier(secret: ProcessInfo.processInfo.environment["HCAPTCHA_SECRET"]!)
let otp = OtpService(sms: sms, store: store, appName: "MyApp", captcha: captcha)
```

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

# Optional -- CAPTCHA (pick one)
TURNSTILE_SECRET=your_cloudflare_turnstile_secret
HCAPTCHA_SECRET=your_hcaptcha_secret
```

---

## Security Checklist

Before going live, confirm:

- [ ] `KWTSMS_LOG_FILE=` (empty): OTP codes must NOT be logged
- [ ] CAPTCHA enabled in production (`TURNSTILE_SECRET` or `HCAPTCHA_SECRET` set)
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

### Comparing codes directly instead of using constant-time comparison

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
let result = await otp.sendOtp(phone: phone, captchaToken: token, ip: ip)
```
