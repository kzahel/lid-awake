# Roadmap

Lid Awake 0.0.5 is a signed prerelease. Its aim is a predictable, bounded closed-lid session: background work continues, the user can see whether sleep is disabled, and normal sleep reliably returns. The [comparison](../COMPETITIVE-ANALYSIS.md) explains the tradeoffs with Lidless and Awayke; the [validation record](VALIDATION.md) distinguishes observed behavior from remaining tests.

## Completed in 0.0.5

1. **Verified restoration and recovery.** The helper keeps its marker until I/O Registry reports `SleepDisabled = No`. Failed or unreadable restoration remains visible and retries every five seconds. The root VM harness covers a successful `pmset` exit with failed state read-back, followed by recovery. The menu distinguishes an owned session, recovery, an external override, and a helper fault.
2. **Root helper boundary.** The installed helper accepts the signed app and rejects an unsigned XPC client. The VM helper log explicitly reports a forbidden message due to its code-signing requirement. The protocol still accepts only fixed operations and allowed durations. A differently signed client remains untested.
3. **Helper update repair.** The app checks the registered helper's build and offers **Repair Helper…** while normal sleep is observed. A real 0.0.4-to-0.0.5 Sparkle update in the VM left a version-3 helper registered; the menu detected it, and repair registered the version-5 helper without another password prompt in that VM.
4. **Heat and power limits.** The helper separates AC, battery percentage, and unavailable readings. It refuses a new session when power is unknown or thermal state is serious or critical; an active session restores at 15% battery, serious or critical heat, or after 30 seconds of unknown power. Injected-reading unit tests cover the thresholds without heating or draining a Mac.

## Before a stable release

1. **Physical acceptance on the release candidate.** Run the timestamped heartbeat test with the lid closed, then the normal-sleep control after turning Lid Awake off. Check screen lock and remote agent continuity during both. Confirm Gatekeeper, helper repair or approval, quit recovery, and update behavior on a stock SIP-enabled Mac. The earlier 0.0.3 closed-lid session and 0.0.4 icon/on-off test do not cover this full sequence together.
2. **More failure evidence.** Simulate an external `SleepDisabled` change during a session, unreadable I/O Registry, and a helper launch failure after update. Confirm that the UI guides recovery and never reports off while the marker is unresolved. Exercise the thermal and unknown-power cutoffs in the root integration harness as well as the policy tests.
3. **Update interval.** Verify automatic daily update discovery over a full interval. Manual **Check for Updates…** and an actual signed old-to-new install have already passed.

## Then improve convenience

- Decide the screen-lock policy from physical tests. If needed, offer an explicit lock action when starting a session while keeping remote agent use workable.
- Consider an “until lid reopens” option only with a hard maximum duration. Keep indefinite sessions outside the default transit flow. Add charging-only mode or configurable thresholds if real use shows a need.
- Improve plain-language recovery instructions if the physical test reveals confusing macOS approval or helper failure states.

## Size and scope

Keep the native AppKit app and Sparkle updater. The installed 0.0.5 app uses about 3.4 MiB in the Tart VM, small enough for this job. Track bundle size, memory, and idle CPU use across releases; optimize a meaningful regression rather than trading away recovery or updates for a smaller download.
