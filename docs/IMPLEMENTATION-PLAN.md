# Reliability release plan

Target: the next signed `v0.0.x` prerelease. This plan implements the [roadmap](ROADMAP.md) work that can be developed and tested without a physical lid switch. The user will run the final closed-lid test on a MacBook after the prerelease is published.

## Behavior to ship

1. **Verified restoration.** Keep the root-owned session marker until I/O Registry reports `SleepDisabled = No`. A failed or unreadable restoration stays in a recovery state and is retried by the helper every five seconds. The app reports that state and does not claim success from `pmset`'s exit code alone. A new session cannot start while a marker remains.
2. **Power and thermal policy.** Parse AC power, battery percentage, and unknown power separately. Refuse to start when battery is at or below 15% or the power source cannot be determined. During a session, restore at 15%, at serious/critical thermal state, or after sustained unknown power readings. A single transient read failure does not end the session. The helper enforces these rules independently of the menu app.
3. **Helper health and update recovery.** Add a versioned health reply while preserving the current XPC operations for compatibility. If the registered helper is unreachable or outdated, offer repair only while normal sleep is observed. Re-register the bundled daemon using `SMAppService`, and guide the user if macOS requires approval again. Update installation remains blocked during a session.
4. **Clear observed state.** The menu distinguishes an owned session, recovery in progress, an external sleep override, a helper needing repair, and normal sleep. It must not show a normal/off state while the helper still owns an unresolved marker.

## Verification

- Unit tests cover power parsing, the 15% boundary, transient and sustained unknown readings, thermal cutoff, session deadline, and heartbeat expiry. Tests use injected readings; they do not drain or heat a Mac.
- In a claimed machine-control Tart VM, the root helper integration harness verifies on/off, marker recovery, timeout, failed restoration retry, and observed read-back. The harness restores normal sleep and removes only its own test marker on exit.
- In the VM, an unsigned or differently signed XPC client must fail to call the installed helper, while the signed app still succeeds. Record the exact observed result; the source-level signing check alone is insufficient evidence.
- Install an older signed release, update through Sparkle to the new signed release, verify helper health and repair if required, then toggle on/off without a routine password prompt. Verify Gatekeeper, code signatures, notarization, and the update archive signature.
- Publish the prerelease from GitHub Actions only after the local and VM checks pass. Record the release and remaining physical test in [validation](VALIDATION.md). The user then performs the physical lid-close, normal-sleep control, and screen-lock check in [the test plan](TESTING.md).

## Constraints

- All destructive `pmset` tests run inside the claimed disposable VM. The host Mac's power settings remain untouched during development.
- Keep the privileged protocol limited to fixed operations; do not add arbitrary paths, commands, or shell invocation.
- Keep the native AppKit app and Sparkle. Bundle size is a regression metric, not a release target.
- If helper repair would occur while `SleepDisabled` is on or its state is unknown, stop and show recovery instructions instead of unregistering the daemon.
