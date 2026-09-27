# Validation record

2026-09-27, macOS 26 / Xcode 26.6:

- Debug app and helper compile; all three session policy and I/O Registry parser XCTest tests pass locally.
- Signed Release archive exports as a universal `arm64` + `x86_64` app. The exported app and nested helper pass strict `codesign` verification and carry the expected Developer ID team identity.
- Apple notarization accepted the exported app and DMG. Both stapled tickets validate; Gatekeeper assesses the app as `Notarized Developer ID`.
- Sparkle generated an appcast and ZIP. An independent Ed25519 check verified the archive signature against the public key embedded in the app.
- The clean GitHub Actions build and test run [36305266986](https://github.com/kzahel/lid-awake/actions/runs/36305266986) passed.
- Exported only the Developer ID Application identity from the login Keychain into a new PKCS#12 archive. A fresh temporary Keychain imported that archive, reported one valid Developer ID identity, and signed and verified a test executable. The tested archive and its randomly generated password are stored as GitHub Actions repository secrets; the temporary archive and password were removed locally.
- The Mac Tart appliance powered up, but its guest administration and resident control agent were unreachable, so helper approval and on/off interaction could not be tested there. The appliance was suspended and the use claim released.

The current checks establish local packaging and signing, including import from the same PKCS#12 used by CI. The GitHub Actions release job has not run yet. Before publishing a first release, verify helper setup and restoration on a working Mac testbed or physical MacBook. A second signed version is needed to exercise the full Sparkle replacement/relaunch path. The physical lid-close test remains necessary because Tart does not expose a virtual clamshell switch.
