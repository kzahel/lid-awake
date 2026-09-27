# Validation record

2026-09-27, macOS 26 / Xcode 26.6:

- Debug app and helper compile; all three session policy and I/O Registry parser XCTest tests pass locally.
- Signed Release archive exports as a universal `arm64` + `x86_64` app. The exported app and nested helper pass strict `codesign` verification and carry the expected Developer ID team identity.
- Apple notarization accepted the exported app and DMG. Both stapled tickets validate; Gatekeeper assesses the app as `Notarized Developer ID`.
- Sparkle generated an appcast and ZIP. An independent Ed25519 check verified the archive signature against the public key embedded in the app.
- The clean GitHub Actions build and test run [36305799671](https://github.com/kzahel/lid-awake/actions/runs/36305799671) passed.
- Exported only the Developer ID Application identity from the login Keychain into a new PKCS#12 archive. A fresh temporary Keychain imported that archive, reported one valid Developer ID identity, and signed and verified a test executable. The tested archive and its randomly generated password are stored as GitHub Actions repository secrets; the temporary archive and password were removed locally.
- The earlier Mac Tart diagnosis stopped too soon: the VM was suspended, and a direct platform command lacked the private target binding supplied by the common `machine-control` CLI. After resuming through the common CLI, guest administration and the resident worked. `maintenance repair --profile development` refreshed an older resident; `target doctor` then reported ready with an unlocked desktop, working Accessibility, capture, and input.
- Installed the notarized local DMG in the macOS 26.2 VM. Gatekeeper accepted it as `Notarized Developer ID`, and strict code-signature verification passed. VM interaction exposed a real app startup bug: the process ran without creating its menu bar item. An explicit nibless AppKit entry point fixed it; the signed replacement displays the menu, duration choices, helper setup, and update controls.
- Helper registration reached macOS's Login Items approval switch and administrator sheet. The testbed's one-shot guest credential channel delivered an attempt, but macOS authorization did not complete and the switch remained off. Stop credential retries until the saved guest password or the secure input route is diagnosed. No on/off or watchdog behavior has been verified yet.

The current checks establish local packaging and signing, including import from the same PKCS#12 used by CI. The GitHub Actions release job and the Sparkle old-to-new replacement test still need to run. Before calling the MVP ready, verify helper approval, on/off, forced-exit recovery, and restoration on a working Mac testbed or physical MacBook. The physical lid-close test remains necessary because Tart does not expose a virtual clamshell switch.
