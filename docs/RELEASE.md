# Release operations

## Signing credentials

The release job uses a Developer ID Application certificate, an App Store Connect API key for notarization, and a Lid Awake-specific Sparkle EdDSA key. Keep private material outside this repository and provide it through GitHub Actions repository secrets. The required secret names are in [the release workflow](../.github/workflows/build.yml). Never print credential values in logs.

## Pipeline

- Push and PR: build and test without publishing.
- Before a stable release, validate the signed app on a stock macOS test environment, including Gatekeeper and helper approval, and complete the remaining [physical lid checks](VALIDATION.md). `v0.0.x` tags are prerelease test artifacts for exercising CI, installation, and Sparkle while acceptance work continues.
- `v*` tag: require all signing and notarization secrets; build with hardened runtime, run tests, verify signatures, notarize, staple, create DMG and Sparkle update ZIP, sign the update archive, stage a draft GitHub Release, then publish it and the appcast after those checks pass.

The release job installs `dmgbuild==1.6.7` in a Python virtual environment. Its layout is in [`scripts/dmg-settings.py`](../scripts/dmg-settings.py), with the editable background in [`Resources/dmg-background.svg`](../Resources/dmg-background.svg) and its rendered PNG beside it. If the background changes, regenerate the PNG with `sips -s format png Resources/dmg-background.svg --out Resources/dmg-background.png` before packaging.

The appcast is served at a stable HTTPS URL from the default branch through `raw.githubusercontent.com`. CI publishes it only after the GitHub Release is public; archives remain GitHub Release assets. The updater public key is embedded in the app. A published version must never be replaced in place.

Tags use `vMAJOR.MINOR.PATCH`; CI maps them to monotonic Sparkle build numbers (`major * 1,000,000 + minor * 1,000 + patch`).

## Verify a downloaded release

Mount the DMG and copy `Lid Awake.app` to `/Applications`, then check its signature, Gatekeeper assessment, and stapled ticket:

```sh
codesign --verify --deep --strict --verbose=2 '/Applications/Lid Awake.app'
spctl -a -vvv -t exec '/Applications/Lid Awake.app'
xcrun stapler validate '/Applications/Lid Awake.app'
```

Sparkle replacement from 0.0.4 to 0.0.5 was tested in the VM with a previously approved helper. The new app detected that the registered helper was stale, **Repair Helper…** registered the new helper, and the helper toggled the sleep setting afterward without a new password prompt in that VM. Scheduled daily update discovery has not been observed through a full interval. CI success alone does not establish the behavior of an installed update.
