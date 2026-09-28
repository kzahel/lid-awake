# Lid Awake user guide

[Back to README](../README.md)

## Install and set up

1. Download the newest prerelease DMG from [Releases](https://github.com/kzahel/lid-awake/releases), open it, and drag **Lid Awake.app** to **Applications**.
2. Open the app and click its laptop icon near the clock.
3. Choose **Set Up Helper…**. If macOS asks for approval, follow the prompt to **System Settings → General → Login Items** (called **Login Items & Extensions** on newer macOS versions).

You may need to enter an administrator password once. Later sessions do not ask for it again.

## Start and stop a session

1. Under **Keep Mac awake**, choose **Lid open only** to prevent idle sleep, or **Even when closed** to keep working after the lid closes.
2. Under **Stop when**, choose **Until I turn it off**, **Until unplugged** (available while charging), or **After a time limit** (15 minutes to 4 hours).
3. Choose **Start Keeping Awake** and confirm the ventilation warning.

The session starts immediately; it does not wait for a lid event. Choose **Restore Normal Sleep** to end it.

Keep the Mac on a hard, ventilated surface while the lid is closed. Avoid putting it in an enclosed bag while it is running.

The menu shows the power source, active condition, last stop reason, and Quit. Its icon adds a battery cue while active on battery and an attention cue for helper repair or recovery.

## Settings

Open **Settings…** from the menu bar menu.

| Tab | Options |
| --- | --- |
| Safety | Battery cutoff and start confirmation |
| General | Update checks and launch at login |
| Support | Problem reporting, feedback, and uninstall |

The battery cutoff can be Off, 15%, 20%, or 30% and applies to sessions that can run on battery. The helper always stops for serious or critical thermal state and for sustained unreadable power.

To skip the start confirmation, select **Don't show this again** when starting a session. To restore it, uncheck **Don't show start confirmation** in **Settings… → Safety**.

## Updates and helper repair

Lid Awake checks for updates daily by default and lets you choose when to install them. To check manually, choose **Settings… → General → Check for Updates…** when no session is active.

The text below the button shows the check result or explains why checking is unavailable. If it asks you to restore normal sleep, end the awake session first. A failed check shows an error rather than reporting that the app is up to date; you can try again afterward.

After an update, the menu may show **Helper needs repair**. Choose **Repair Helper…** while normal sleep is on. macOS may ask you to approve the updated helper again.

## Background helper behavior

The approved helper starts when needed and exits after about 30 seconds without a session or request. It also starts briefly when its launchd job loads to recover an interrupted session. During an active session, it stays running to enforce time, battery, and heat limits.

The menu bar app stays open while its icon is visible. The **Lid Awake** switch in macOS Login Items & Extensions grants background permission; it may remain visible even while the helper process is stopped.

## Get help or uninstall

Under **Settings… → Support**, choose **Report a Problem…** to review and edit diagnostics before opening a GitHub issue, or **Send Feedback…** for feedback without diagnostics.

Choose **Uninstall…** to restore and verify normal sleep before removing the helper and login item. Follow the prompts to finish removing the app.

## Further reading

- [Product behavior and first-run flow](PRODUCT.md)
- [How it works and safety limits](IMPLEMENTATION.md)
- [Test results and remaining checks](VALIDATION.md) and [roadmap](ROADMAP.md)
- [Comparison with Lidless and Awayke](../COMPETITIVE-ANALYSIS.md), a research snapshot describing version 0.0.5
- [Original command-line script](../lid-awake)
