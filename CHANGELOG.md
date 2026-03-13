# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-03-13

### Added

- Country-specific phone validation with `phoneRules` table (80+ countries): validates local number length and mobile prefix.
- `findCountryCode()` for longest-match country code detection (3-digit, 2-digit, 1-digit).
- `validatePhoneFormat()` for country-specific length and prefix checks.
- Domestic trunk prefix stripping in `normalizePhone()` (e.g. `9660559...` becomes `966559...`).
- GitGuardian secrets scanning workflow.
- Dependabot auto-merge workflow (patch/minor updates only).
- Stale issues/PRs workflow (30-day stale, 7-day close).
- Production OTP example (`Examples/05-OtpProduction/`): complete send/verify flow with rate limiting, code hashing (SHA-256 + salt), constant-time comparison, resend cooldown, attempt tracking.
- `OtpStoreProtocol` database adapter interface with `MemoryOtpStore` reference implementation.
- `DeviceAttestVerifier` protocol and `AppAttestVerifier` for Apple App Attest (iOS bot prevention).
- `TokenAuthenticator` protocol for JWT/session-based auth (2FA flows).
- Vapor and Hummingbird framework usage examples.
- CodeQL security analysis workflow (macOS, weekly + on push/PR).
- Dependabot configuration for Swift packages and GitHub Actions.

### Changed

- Dropped Swift 5.9 from test matrix (lacks async URLSession on Linux).
- Cross-platform URLSession async wrapper for Linux compatibility.
- CodeQL runs on macOS (Swift extractor requires macOS).
- `ValidateResult` uses `@unchecked Sendable` for Swift 5.10/6.0 compatibility.

## [0.1.0] - 2026-03-05

### Added

- Initial release of the kwtSMS Swift client library.
- `KwtSMS` actor with full API coverage: `send()`, `balance()`, `verify()`, `validate()`, `senderIds()`, `coverage()`, `status()`, `deliveryReport()`.
- Auto-batching for >200 numbers with 0.5s delay between batches.
- ERR013 (queue full) automatic retry with exponential backoff (30s, 60s, 120s).
- Phone number utilities: `normalizePhone()`, `validatePhoneInput()`, `deduplicatePhones()`.
- Message cleaning: `cleanMessage()` strips emojis, HTML, control chars, converts Arabic digits.
- All 33 kwtSMS error codes mapped to developer-friendly action messages via `apiErrors` and `enrichError()`.
- `.env` file loading via `fromEnv()` factory method (macOS/Linux/server).
- JSONL logging with password masking.
- Thread-safe via Swift `actor` isolation.
- Comprehensive test suite: 115+ unit tests, integration test suite with test mode.
- Zero external dependencies: uses only Foundation and URLSession.
- Supports iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, Linux (server-side Swift).
