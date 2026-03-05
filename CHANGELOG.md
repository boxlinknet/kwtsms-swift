# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- Comprehensive test suite: 89+ unit tests, integration test suite with test mode.
- Zero external dependencies: uses only Foundation and URLSession.
- Supports iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, Linux (server-side Swift).
