# Architecture and safety

## Components

1. Native AppKit menu bar application (`LSUIElement`, macOS 13+). It renders session and power state, reads `SleepDisabled` from I/O Registry, tracks helper approval, sends heartbeats, holds a process activity while active to avoid App Nap delaying heartbeats, shows safety settings and reviewable diagnostics, and hosts Sparkle.
2. Bundled root LaunchDaemon registered by `SMAppService.daemon(plistName:)`. Its Mach service launches it on demand; the `SuccessfulExit=false` policy also runs it once when the job loads and restarts it after an unsuccessful exit. It exits after 30 seconds idle. The daemon owns all writes to `/usr/bin/pmset -a disablesleep` and validates each XPC client's code-signing requirement before accepting a connection.
3. A shared Objective-C-compatible XPC protocol with a narrow command surface: start with a validated mode, duration, lid scope, and battery cutoff; disable; heartbeat; status; versioned health; session details; and diagnostic-state removal. No arbitrary command execution or path arguments.
4. Sparkle 2 update feed with per-app EdDSA key. A GitHub Actions macOS runner builds, signs, notarizes, staples, and publishes a DMG, update ZIP, and appcast after a version tag.

## State transitions

`Off -> Setup -> Ready -> On -> Off`. Setup approval can remain pending; the UI polls `SMAppService.status`. The app checks helper health on launch, when the menu opens, when approval completes, when sleep first appears disabled, and during an active session. Before `On`, the helper checks the observed `SleepDisabled` state, power source, and thermal state. Closed-lid-capable sessions create an ownership marker and run `pmset`; lid-open-only sessions use a process idle-sleep activity without changing the global flag. A successful closed-lid `Off` requires observed `SleepDisabled=No` before clearing the marker. Failed or unreadable restoration remains in recovery and retries every five seconds. A watchdog restores on deadline (if timed), unplug (in Until unplugged), lost heartbeat, the selected battery cutoff, serious or critical thermal state, or a power-source reading unavailable for 30 seconds. On daemon startup, any marker is treated as an interrupted session and immediately restored. External `SleepDisabled=Yes` without an ownership marker is shown as externally managed and cannot be enabled by this app. A helper health check detects an older registered helper and offers re-registration while normal sleep is observed.

## Build and verification

`project.yml` describes the XcodeGen project; the generated Xcode project is checked in. Debug and Release use separate bundle IDs and daemon labels. GitHub Actions builds and tests pushes, then signs, notarizes, staples, and publishes tagged releases as described in [release operations](RELEASE.md).

The [test plan](TESTING.md) and [validation record](VALIDATION.md) separate verified behavior from remaining checks. Signed installation, helper approval, on/off, quit and forced-exit recovery, Sparkle replacement, helper repair, and unsigned XPC client rejection have been exercised in a Tart VM. A physical MacBook stayed reachable during a closed-lid session with an earlier prerelease. The VM cannot emulate a physical lid switch; a differently signed client has not been tested.

## Threat model

The XPC Mach service is reachable by local processes. The helper sets a code signing requirement for the exact app identifier and signing team before `resume()`. It rejects unsupported modes, durations, and battery cutoffs, serializes state changes, uses fixed absolute tool paths, and avoids shell execution. Private keys stay outside the app and repository, and update installation is blocked during an active session. A user or another root tool can still change the global power setting independently; the UI displays observed state and avoids taking ownership of it.
