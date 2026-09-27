# Product and UX plan

## Purpose

Keep local agents and other processes running while a MacBook is carried with its lid closed. The app is macOS-only and lives in the menu bar. It must make the active state conspicuous and bound how long the machine can stay awake.

## MVP behavior

- Menu bar icon indicates **Off**, **On**, **Setting up**, or **Error**.
- The menu shows the observed macOS `SleepDisabled` state, session time remaining, and **Keep Awake** / **Restore Normal Sleep**.
- The user chooses a duration before enabling: 30 minutes, 1 hour, 2 hours (default), or 4 hours. The privileged helper enforces the deadline independently of the UI.
- If the app quits, crashes, or stops heartbeating, the helper restores normal sleep within 90 seconds. If the helper restarts while it owns an active override, it restores normal sleep immediately.
- Turning off always restores normal sleep for an override owned by Lid Awake. If another program already disabled sleep, Lid Awake reports that state and refuses to take ownership.
- First use presents a clear explanation, then **Set Up Helper**. The app registers its bundled daemon with `SMAppService`; if macOS requires approval, it shows **Open System Settings** and watches for the approved state. No sudo password is collected by the app.
- On battery, the helper restores normal sleep at 15% charge. The UI explains the cutoff before starting.
- The menu has **Check for Updates…**. Sparkle checks daily by default and announces available updates. Installation is offered only when Lid Awake is off. Silent installation is disabled for MVP.
- Optional **Launch at Login** setting uses `SMAppService.mainApp`.

## First-run flow

1. Open the signed, notarized app from `/Applications`.
2. Choose a duration and click **Keep Awake**.
3. If the helper is not registered, show why the system-level helper is needed and a **Set Up Helper** button.
4. After registration, handle `.requiresApproval` by opening System Settings > General > Login Items & Extensions. Show current approval state; enable the control only after `.enabled`.
5. Once enabled, the menu icon and text change to **On** and show the deadline. The user can turn it off immediately.

## Safety and recovery

Closed-lid operation in a bag can cause heat buildup and rapid battery drain. Show a concise warning on first activation to keep the computer ventilated. Bounded duration and low-battery cutoff are enforced by the root helper; the app cannot extend them merely by sending heartbeats. A helper-owned state marker is written before enabling sleep suppression, so a helper restart can recover an interrupted session. The helper accepts XPC requests only from the signed app with the exact bundle identifier and Apple team ID.

## Distribution

A Developer ID signed and Apple notarized DMG contains `Lid Awake.app` and an Applications shortcut. The user drags the app into Applications once. Sparkle updates the app from a signed update archive and appcast published with GitHub Releases. No package installer is needed for the bundled daemon.

## Acceptance criteria

- First-run helper approval succeeds and subsequent toggles need no password.
- On/off state is confirmed using I/O Registry `SleepDisabled`, including after app or helper failure.
- Auto-off, heartbeat expiry, and battery cutoff restore normal sleep.
- An already-disabled sleep state owned by another tool is never silently claimed.
- A signed older app updates to a signed newer app, with the helper usable afterward.
- Gatekeeper accepts a stapled release downloaded from GitHub.
- A real MacBook lid-close test confirms a timestamped background process continues while closed, then normal lid sleep resumes after turning off.
