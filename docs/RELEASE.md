# Release operations

## Credentials

Reuse the existing Developer ID Application certificate and App Store Connect API key documented privately in `~/code/dotfiles/runbooks/desktop-code-signing.md`. The Sparkle EdDSA key is unique to Lid Awake. Keep all private keys outside this repository and upload them as GitHub Actions repository secrets. Never log credentials. The local Developer ID identity is available in the macOS login keychain for signing tests.

## Intended pipeline

- Push and PR: build and test without publishing.
- Before the first tag, validate the signed app on a clean macOS test VM, including Gatekeeper and helper approval. Test an older-to-newer update when a second release candidate exists.
- `v*` tag: require all signing and notarization secrets; build with hardened runtime, run tests, verify signatures, notarize, staple, create DMG and Sparkle update ZIP, sign the update archive, stage a draft GitHub Release, then publish it and the appcast after those checks pass.

The appcast is served at a stable HTTPS URL from the default branch through `raw.githubusercontent.com`. CI publishes it only after the GitHub Release is public; archives remain GitHub Release assets. The updater public key is embedded in the app. A published version must never be replaced in place.

Tags use `vMAJOR.MINOR.PATCH`; CI maps them to monotonic Sparkle build numbers (`major * 1,000,000 + minor * 1,000 + patch`).

## Local verification commands

```sh
xcodegen generate
xcodebuild -project LidAwake.xcodeproj -scheme LidAwake -configuration Release archive -archivePath build/LidAwake.xcarchive
xcodebuild -exportArchive -archivePath build/LidAwake.xcarchive -exportPath build/export -exportOptionsPlist ExportOptions.plist
codesign --verify --deep --strict --verbose=2 path/to/Lid\ Awake.app
spctl -a -vvv -t exec path/to/Lid\ Awake.app
xcrun stapler validate path/to/Lid\ Awake.app
```

An older signed build must update to a newer signed build before claiming that auto-update works. CI success alone does not establish that the helper survives an update.
