# Implementation plan

## Components

1. Native SwiftUI/AppKit menu bar application (`LSUIElement`, macOS 13+). It renders state, reads `SleepDisabled` from I/O Registry, tracks helper approval, sends heartbeats, and hosts Sparkle.
2. Bundled root LaunchDaemon registered by `SMAppService.daemon(plistName:)`. The daemon owns all writes to `/usr/bin/pmset -a disablesleep` and validates each XPC client's code-signing requirement before accepting a connection.
3. A shared Objective-C-compatible XPC protocol with a narrow command surface: enable for a bounded duration, disable, heartbeat, status. No arbitrary command execution or path arguments.
4. Sparkle 2 update feed with per-app EdDSA key. A GitHub Actions macOS runner builds, signs, notarizes, staples, and publishes a DMG, update ZIP, and appcast after a version tag.

## State transitions

`Off -> Setup -> Ready -> On -> Off`. Setup approval can remain pending; the UI polls `SMAppService.status`. Before `On`, the helper checks the observed `SleepDisabled` state, creates an ownership marker, then runs `pmset`. A successful `Off` runs `pmset` and clears the marker. A watchdog restores on deadline, lost heartbeat, or low battery. On daemon startup, any marker is treated as an interrupted session and immediately restored. External `SleepDisabled=Yes` without an ownership marker is shown as externally managed and cannot be enabled by this app.

## Build and test sequence

1. Generate an Xcode project with XcodeGen. Keep Debug and Release bundle IDs and daemon labels separate.
2. Compile app and daemon; run focused pure-logic tests for session expiration and state parsing.
3. Test read-only state, setup approval, XPC identity rejection, on/off, app quit, daemon restart, and timer in a claimed Tart test VM via `machine-control`.
4. Build and sign locally with the Developer ID keychain identity. Validate nested signatures and hardened runtime.
5. Run notarization and stapling on an actual archive. Validate with `spctl` and `stapler`.
6. Upload CI secrets without ever printing them or placing private material in the repository. Run a draft release, verify the signed artifacts, then publish the first release.
7. Test a real signed old-to-new Sparkle update and the physical lid-close behavior.

Tart and `machine-control` provide no virtual lid switch. The OS-specific clamshell event needs the final physical MacBook test; automated tests cover all other transitions.

## Threat model

The XPC Mach service is reachable by local processes. Restrict its clients to the exact app identifier and signing team, using the audit-token-backed code signing requirement before `resume()`. Treat daemon input as untrusted: reject durations outside the fixed range, serialize state changes, use fixed absolute tool paths, avoid shell execution, keep private keys out of the app and repository, and prevent update installation during an active session. A user or another root tool can still change the global power setting independently; the UI must display observed state and avoid taking ownership of it.
