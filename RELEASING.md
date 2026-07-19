# Releasing Clippy

Releases are automated by `.github/workflows/release.yml`: push a tag → build, sign, notarize, staple, publish, and generate a signed appcast entry.

## One-time setup

### 1. Apple Developer ID (required for notarized releases)
- Enroll in the Apple Developer Program ($99/yr).
- Create a **Developer ID Application** certificate in Xcode or developer.apple.com, export as `.p12`.
- Create an app-specific password for notarization at appleid.apple.com.

### 2. Sparkle update keys (required for auto-updates)
Generate a fresh EdDSA key pair (never reuse Maccy's):

```sh
brew install --cask sparkle   # or download the Sparkle release tarball
./bin/generate_keys           # prints the public key, stores private in Keychain
./bin/generate_keys -x private-key-file   # export for CI
```

Put the printed **public** key into `Maccy/Info.plist` as `SUPublicEDKey` (currently absent — updates are inert until this is set).

### 3. GitHub repository secrets
| Secret | Value |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | `base64 -i cert.p12` |
| `P12_PASSWORD` | password for the .p12 |
| `TEAM_ID` | your 10-char Apple team id |
| `APPLE_ID` | Apple ID email used for notarization |
| `APP_PASSWORD` | app-specific password |
| `SPARKLE_ED_PRIVATE_KEY` | contents of the exported private key file |

## Cutting a release

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Maccy.xcodeproj/project.pbxproj`.
2. `git tag 0.1.0 && git push --tags`
3. When the workflow finishes, copy the generated `<item>` from the workflow log's appcast output into `appcast.xml` on master and push — Sparkle clients read `https://raw.githubusercontent.com/maka-tanmay/Clippy/master/appcast.xml`.

## Homebrew

After the first release, create a tap (`maka-tanmay/homebrew-tap`) with a cask pointing at the release zip, then `brew install maka-tanmay/tap/clippy`.
