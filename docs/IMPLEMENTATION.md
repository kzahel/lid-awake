# Architecture and safety

## Components

1. Native AppKit menu bar application (`LSUIElement`, macOS 13+). It renders state, reads `SleepDisabled` from I/O Registry, tracks helper approval, sends heartbeats, holds a process activity while active to avoid App Nap delaying heartbeats, and hosts Sparkle.
2. Bundled root LaunchDaemon registered by `SMAppService.daemon(plistName:)`. The daemon owns all writes to `/usr/bin/pmset -a disablesleep` and validates each XPC client's code-signing requirement before accepting a connection.
3. A shared Objective-C-compatible XPC protocol with a narrow command surface: enable for a bounded duration, disable, heartbeat, status. No arbitrary command execution or path arguments.
4. Sparkle 2 update feed with per-app EdDSA key. A GitHub Actions macOS runner builds, signs, notarizes, staples, and publishes a DMG, update ZIP, and appcast after a version tag.

## State transitions

`Off -> Setup -> Ready -> On -> Off`. Setup approval can remain pending; the UI polls `SMAppService.status`. Before `On`, the helper checks the observed `SleepDisabled` state, creates an ownership marker, then runs `pmset`. A successful `Off` runs `pmset` and clears the marker. A watchdog restores on deadline, lost heartbeat, or low battery. On daemon startup, any marker is treated as an interrupted session and immediately restored. External `SleepDisabled=Yes` without an ownership marker is shown as externally managed and cannot be enabled by this app.

## Build and verification

`project.yml` describes the XcodeGen project; the generated Xcode project is checked in. Debug and Release use separate bundle IDs and daemon labels. GitHub Actions builds and tests pushes, then signs, notarizes, staples, and publishes tagged releases as described in [release operations](RELEASE.md).

The [test plan](TESTING.md) and [validation record](VALIDATION.md) separate verified behavior from remaining checks. Signed installation, helper approval, on/off, quit and forced-exit recovery, and Sparkle replacement have been exercised in a Tart VM. A physical MacBook stayed reachable during a closed-lid session. The VM cannot emulate a lid switch, and XPC client rejection has not been tested with a deliberately mismatched signed client.

## Threat model

The XPC Mach service is reachable by local processes. The helper sets a code signing requirement for the exact app identifier and signing team before `resume()`. It rejects durations outside the fixed range, serializes state changes, uses fixed absolute tool paths, and avoids shell execution. Private keys stay outside the app and repository, and update installation is blocked during an active session. A user or another root tool can still change the global power setting independently; the UI displays observed state and avoids taking ownership of it.
