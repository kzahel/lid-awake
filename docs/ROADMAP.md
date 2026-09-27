# Roadmap

Lid Awake 0.0.4 is a prerelease. The goal is a predictable, bounded closed-lid session: background work continues, screen-lock behavior is understood, and normal sleep reliably returns. Complete items 1–6 before the first stable release. The [comparison](../COMPETITIVE-ANALYSIS.md) explains the tradeoffs with Lidless and Awayke; the [validation record](VALIDATION.md) says which behaviors have actually been observed.

## Next: make the current path dependable

1. **Verify restoration before declaring a session off.** The helper currently treats a successful `pmset` exit as sufficient and removes its recovery marker without reading `SleepDisabled` again. Read the I/O Registry after disabling, retain the marker and retry if the state is still on or unknown, and surface a clear recovery error. Reconcile the menu if another tool changes the global setting during a session. Test failed writes, unreadable state, app termination, helper restart, and a competing power-setting change in an isolated VM.
2. **Test the root helper boundary.** The helper already calls `setCodeSigningRequirement`, which [Apple documents](https://developer.apple.com/documentation/foundation/nsxpcconnection/setcodesigningrequirement%28_%3A%29) as a way to enforce a peer's signature. Exercise it with the real installed helper: our signed app must work, while an unsigned or differently signed client must be rejected. Keep the helper protocol limited to fixed operations and allowed durations.
3. **Make helper updates repairable.** The 0.0.3-to-0.0.4 Sparkle update worked with prior approval, but the app has no explicit recovery if an updated helper is registered yet cannot launch. Add a helper version/health check and a guided re-registration path that runs only while sleep is normal. Test a signed old-to-new update that changes the helper, including a simulated failed launch and any macOS approval step.

## Before a stable release

4. **Enforce heat and power limits in the helper.** Add a thermal cutoff for serious or critical [macOS thermal states](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum). Separate “on AC,” “on battery at N%,” and “reading unavailable”: the current `nil` battery result conflates AC with a failed reading and skips the 15% cutoff. Choose a conservative policy for sustained unknown readings. Test the policy with injected readings and the helper harness; do not rely on draining or heating a physical Mac to reach a threshold.
5. **Finish physical acceptance on the release candidate.** Run the timestamped heartbeat test with the lid closed, then the normal-sleep control after turning Lid Awake off. Check screen-lock behavior and remote agent continuity during both. Confirm Gatekeeper, helper approval, quit recovery, and update behavior on a stock SIP-enabled Mac. The earlier 0.0.3 closed-lid session and 0.0.4 on/off test are valuable evidence, but they do not cover this full sequence together.
6. **Repeat the full update and failure path.** Install an older signed release, update through Sparkle, confirm the new helper works without a routine password prompt, and test a forced app exit and helper restart. Record results in [validation](VALIDATION.md). Exercise daily update discovery separately; manual “Check for Updates” has already been tested.

## Then improve convenience

- Make the menu explain helper approval, an externally changed sleep setting, restoration failures, and how to recover without guessing at the icon color.
- Decide the screen-lock policy from physical tests. If needed, offer an explicit lock action when starting a session while keeping remote agent use workable.
- Consider an “until lid reopens” option only with a hard maximum duration. Keep indefinite sessions outside the default transit flow. Add charging-only mode or configurable thresholds if real use shows a need.

## Size and scope

Keep the native AppKit app and Sparkle updater. At about 3.3 MiB installed for 0.0.4, the bundle is small enough for this job, and Sparkle supplies the tested update path. Track bundle size, memory, and idle CPU use across releases; optimize a meaningful regression rather than trading away recovery or updates for a smaller download.
