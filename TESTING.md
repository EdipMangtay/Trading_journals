# Verification (macOS)

## Automated Tests

- Full native test suite (29 tests across `AnalyticsTests`, `LocalizationTests`, `PersistenceTests`, `WorkstationTests`):
  ```bash
  cd macos
  bash Scripts/test-local.sh
  ```
- Xcode scheme tests (also executed in GitHub Actions on `macos-15`):
  ```bash
  cd macos
  xcodebuild test -project LiquidityEdge.xcodeproj -scheme LiquidityEdge -destination 'platform=macOS' CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO
  ```
- Core SwiftPM package tests:
  ```bash
  cd macos
  swift test
  ```

## Universal Installer Verification

```bash
cd macos
bash Scripts/package-release.sh 6.0.0
```

The packaging workflow verifies:
- Both `arm64` (Apple Silicon) and `x86_64` (Intel) architectures via `lipo -archs`.
- Strict deep code signature verification via `codesign --verify --deep --strict`.
- Valid PKG structure (`pkgutil --expand-full`) and DMG integrity (`hdiutil verify`).
- Launch and fresh-store smoke testing (`Scripts/verify-installed.swift`) using an isolated temporary `JOURNAL_TEST_DATA_DIR`, confirming the app opens its main window cleanly and initializes a blank local store without touching user data.
- SHA-256 checksums written to `release/SHA256SUMS-macOS.txt`.
