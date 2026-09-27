# Product behavior and UX

## Purpose

Keep local agents and other processes running while a MacBook is carried with its lid closed. The app is macOS-only and lives in the menu bar. It must make the active state conspicuous and bound how long the machine can stay awake.

## MVP behavior

- The menu bar shows a gray badge with a white laptop when normal sleep is enabled, and an orange badge with a black laptop when sleep is disabled. Setup and errors are explained in the menu or an alert.
- The menu shows the observed macOS `SleepDisabled` state, session time remaining, and **Keep Awake** / **Restore Normal Sleep**.
- The user chooses a duration before enabling: 30 minutes, 1 hour, 2 hours (default), or 4 hours. The privileged helper enforces the deadline independently of the UI.
- A normal quit restores sleep immediately. If the app crashes or stops heartbeating, the helper restores normal sleep after about 90 seconds. If the helper restarts while it owns an active override, it restores normal sleep immediately.
- Turning off always restores normal sleep for an override owned by Lid Awake. If another program already disabled sleep, Lid Awake reports that state and refuses to take ownership.
- If sleep is disabled while the helper is unavailable, the menu remains orange and offers a manual `sudo pmset -a disablesleep 0` recovery instruction.
- First use presents a clear explanation, then **Set Up Helper…**. The app registers its bundled daemon with `SMAppService`; if macOS requires approval, it opens System Settings and watches for the approved state. No sudo password is collected by the app.
- On battery, the helper restores normal sleep at 15% charge. It also restores at serious or critical thermal state, or after 30 seconds without a readable power source. An unknown power source or serious heat prevents a new session. The UI explains the battery cutoff before starting.
- After an update, the menu checks the registered helper build and offers **Repair Helper…** when it is old or unreachable. Repair runs only when normal sleep is observed; macOS may require approval again.
- The menu has **Check for Updates…**. Sparkle checks daily by default and announces available updates. Installation is offered only when Lid Awake is off. Silent installation is disabled for MVP.
- Optional **Launch at Login** menu item uses `SMAppService.mainApp`.

## First-run flow

1. Open the signed, notarized app from `/Applications`.
2. Choose **Set Up Helper…** from the menu (or choose **Keep Awake** to reach the same setup prompt).
3. Confirm the setup explanation. If macOS requires approval, the app opens the Login Items section of System Settings and shows where to approve Lid Awake.
4. After approval, choose a duration and **Keep Awake**. Confirm the ventilation warning.
5. The menu shows the remaining time and the badge turns orange. The user can turn it off immediately.

## Safety and recovery

Closed-lid operation in a bag can cause heat buildup and rapid battery drain. The app shows a ventilation warning before each session. Bounded duration, low-battery cutoff, thermal cutoff, and sustained unknown-power cutoff are enforced by the root helper; the app cannot extend them merely by sending heartbeats. A helper-owned state marker is written before enabling sleep suppression, and remains until normal sleep is observed, so a helper restart or failed restoration can be recovered. The helper accepts XPC requests only from the signed app with the exact bundle identifier and Apple team ID.

## Distribution

A Developer ID signed and Apple notarized DMG contains `Lid Awake.app` and an Applications shortcut. The user drags the app into Applications once. Sparkle updates the app from a signed update archive and appcast published with GitHub Releases. No package installer is needed for the bundled daemon.

## Acceptance and remaining checks

The [validation record](VALIDATION.md) distinguishes completed checks from tests that still need a physical Mac or a stock test environment. In particular, the closed-lid remote session and app-driven restoration were observed separately; the timestamped heartbeat and normal-sleep lid-close control below remain to be run together.

- First-run helper approval succeeds and subsequent toggles need no password.
- On/off state is confirmed using I/O Registry `SleepDisabled`, including after app or helper failure.
- Auto-off, heartbeat expiry, and battery cutoff restore normal sleep.
- An already-disabled sleep state owned by another tool is never silently claimed.
- A signed older app updates to a signed newer app, with the helper usable afterward.
- Gatekeeper accepts a stapled release downloaded from GitHub.
- A real MacBook lid-close test confirms a timestamped background process continues while closed, then normal lid sleep resumes after turning off.
