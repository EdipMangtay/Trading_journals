# Trusted macOS Distribution & Signing

HTTPS downloads and SHA-256 checksums protect transport and detect file changes. They do not replace an Apple Developer ID signature and notarization.

Open-source preview/community releases built without Apple Developer ID credentials are ad-hoc signed (`codesign --sign -`). On first launch, macOS Gatekeeper may require explicit approval via **System Settings → Privacy & Security → Open Anyway** (see [INSTALLATION.md](INSTALLATION.md)).

## Configuring Apple Developer ID & Notarization (Optional)

To produce warning-free notarized macOS releases automatically in GitHub Actions, configure these repository secrets:

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATES_P12` | Base64 PKCS#12 export containing `Developer ID Application` and `Developer ID Installer` identities with their private keys |
| `MACOS_CERTIFICATE_PASSWORD` | PKCS#12 export password |
| `MACOS_APP_IDENTITY` | Full `Developer ID Application: ...` identity |
| `MACOS_INSTALLER_IDENTITY` | Full `Developer ID Installer: ...` identity |
| `APPLE_ID` | Developer account Apple ID |
| `APPLE_TEAM_ID` | Developer team ID |
| `APPLE_APP_PASSWORD` | App-specific password for `notarytool` |

When these secrets are set on tag pushes (`v*`), `.github/workflows/build.yml` imports them into a temporary keychain, signs and notarizes the app, staples tickets, signs/notarizes the PKG and DMG, and deletes the temporary keychain afterward.

Never commit certificates, private keys, keychains, or personal journal stores to the repository.
