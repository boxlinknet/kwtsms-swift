# Contributing to kwtsms-swift

## Development Setup

1. Install Swift 5.7+ (or use Xcode 14+):
   - macOS: install Xcode from the App Store
   - Linux: follow https://swift.org/install

2. Clone the repo:
   ```bash
   git clone https://github.com/boxlinknet/kwtsms-swift.git
   cd kwtsms-swift
   ```

3. Build:
   ```bash
   swift build
   ```

4. Run unit tests:
   ```bash
   swift test --filter "PhoneTests|MessageTests|ApiErrorTests"
   ```

5. Run integration tests (requires API credentials):
   ```bash
   SWIFT_USERNAME=your_user SWIFT_PASSWORD=your_pass swift test --filter IntegrationTests
   ```

## Branch Naming

- `feat/description` for new features
- `fix/description` for bug fixes
- `docs/description` for documentation changes

## Pull Request Checklist

- [ ] All unit tests pass (`swift test`)
- [ ] New features include tests
- [ ] No compiler warnings
- [ ] CHANGELOG.md updated
- [ ] README.md updated if public API changed

## Code Style

- Follow Swift API Design Guidelines: https://swift.org/documentation/api-design-guidelines/
- Use `actor` for thread-safe types with mutable state
- All public API methods should be `async`
- Never force-unwrap in library code (use `guard` or `if let`)
- Keep zero external dependencies
