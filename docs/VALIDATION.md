# Validation record

2026-09-27, macOS 26 / Xcode 26.6:

- Debug app and helper compile; the session policy and I/O Registry parser XCTest suite passes locally.
- Signed Release archive exports as a universal `arm64` + `x86_64` app. The exported app and nested helper pass strict `codesign` verification and carry the expected Developer ID team identity.
- Apple notarization accepted the exported app and DMG. Both stapled tickets validate; Gatekeeper assesses the app as `Notarized Developer ID`.
- Sparkle generated an appcast and ZIP. An independent Ed25519 check verified the archive signature against the public key embedded in the app.
- The clean GitHub Actions build and test run [36304356753](https://github.com/kzahel/lid-awake/actions/runs/36304356753) passed. The release job is still waiting for the Developer ID P12 export password repository secret.
- The Mac Tart appliance powered up, but its guest administration and resident control agent were unreachable, so helper approval and on/off interaction could not be tested there. The appliance was suspended and the use claim released.

The current checks establish packaging and signing, not closed-lid behavior. Before publishing a first release, verify helper setup and restoration on a working Mac testbed or physical MacBook. A second signed version is needed to exercise the full Sparkle replacement/relaunch path. The physical lid-close test remains necessary because Tart does not expose a virtual clamshell switch.
