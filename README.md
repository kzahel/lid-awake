# Lid Awake

Keep your MacBook awake from the menu bar, including when you close the lid. Run until you turn it off, until you unplug, or for a chosen time. Lid Awake restores normal sleep at the selected limit, on serious heat, or if the app stops responding.

**macOS 13 or later · [Download a test release](https://github.com/kzahel/lid-awake/releases)**

## Install

1. Download the newest prerelease DMG, open it, and drag **Lid Awake.app** to **Applications**.
2. Open the app and click its laptop icon near the clock.
3. Choose **Set Up Helper…**. If macOS asks for approval, follow the prompt to **System Settings → General → Login Items** (called **Login Items & Extensions** on newer macOS versions). You may need to enter an administrator password once. Later sessions do not ask for it again.

## Use

Choose **Keep Mac awake → Lid open only** for ordinary idle sleep prevention, or **Even when closed** to keep working after the lid closes. Choose **Stop when → Until I turn it off**, **Until unplugged** (available while charging), or **After a time limit**. Timed sessions can run for 15 minutes to 4 hours. Then choose **Start Keeping Awake** and confirm the ventilation warning. These choices start keeping the Mac awake immediately; they do not wait for a lid event. **Restore Normal Sleep** ends a session.

**Settings…** has Safety, General, and Support tabs. Safety offers a battery cutoff of Off, 15%, 20%, or 30%. It applies to sessions that can run on battery. The helper always stops for serious or critical thermal state and for sustained unreadable power. General contains update checks and launch at login. Support contains problem reporting, feedback, and uninstall. **Report a Problem…** lets you review and edit diagnostics before opening a GitHub issue; **Uninstall…** restores and verifies normal sleep before removing the helper and login item. The compact menu shows the power source, active condition, last stop reason, and Quit. Its icon adds a battery cue while active on battery and an attention cue for helper repair or recovery.

After an update, the menu may show **Helper needs repair**. Choose **Repair Helper…** while normal sleep is on. macOS may ask you to approve the updated helper again.

The approved helper starts when needed and exits after about 30 seconds without a session or request. It also starts briefly when its launchd job loads, so it can recover an interrupted session. During an active session it stays running to enforce the time, battery, and heat limits. The menu bar app itself stays open while its icon is visible. The **Lid Awake** switch in macOS Login Items & Extensions grants background permission; it may remain visible even while the helper process is stopped.

Keep the Mac on a hard, ventilated surface while the lid is closed. Avoid putting it in an enclosed bag while it is running.

## Updates

Lid Awake checks for updates daily by default and lets you choose when to install them. You can also choose **Settings… → General → Check for Updates…** when no session is active. The current release is a prerelease; [test results and remaining checks](docs/VALIDATION.md) are recorded separately.

## How it compares

[Compare Lid Awake with Lidless and Awayke](COMPETITIVE-ANALYSIS.md) for the research snapshot that motivated these controls. Its measured sizes and feature table describe version 0.0.5.

The [roadmap](docs/ROADMAP.md) tracks physical acceptance and remaining reliability checks.

See the [changelog](CHANGELOG.md) for release notes.

## More information

- [How it works and its safety limits](docs/IMPLEMENTATION.md)
- [Product behavior and first-run flow](docs/PRODUCT.md)
- [Testing](docs/TESTING.md) and [release process](docs/RELEASE.md)
- [Original command-line script](lid-awake)

[MIT licensed](LICENSE).
