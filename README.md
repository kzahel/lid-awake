# Lid Awake

Keep your MacBook running with the lid closed, from the menu bar. Choose a time limit, start a session, and turn it off when you are done. Lid Awake restores normal sleep when the time runs out, the app stops responding, the battery reaches 15%, or macOS reports serious heat.

**macOS 13 or later · [Download a test release](https://github.com/kzahel/lid-awake/releases)**

## Install

1. Download the newest prerelease DMG, open it, and drag **Lid Awake.app** to **Applications**.
2. Open the app and click its laptop icon near the clock.
3. Choose **Set Up Helper…**. If macOS asks for approval, follow the prompt to **System Settings → General → Login Items** (called **Login Items & Extensions** on newer macOS versions). You may need to enter an administrator password once. Later sessions do not ask for it again.

## Use

Choose **Duration** (30 minutes to 4 hours), then **Keep Awake**. The menu shows the time remaining. Its badge is gray when normal sleep is on and orange when sleep is disabled. Choose **Restore Normal Sleep** to end a session early.

After an update, the menu may show **Helper needs repair**. Choose **Repair Helper…** while normal sleep is on. macOS may ask you to approve the updated helper again.

The approved helper starts when needed and exits after about 30 seconds without a session or request. It also starts briefly when its launchd job loads, so it can recover an interrupted session. During an active session it stays running to enforce the time, battery, and heat limits. The menu bar app itself stays open while its icon is visible. The **Lid Awake** switch in macOS Login Items & Extensions grants background permission; it may remain visible even while the helper process is stopped.

Keep the Mac on a hard, ventilated surface while the lid is closed. Avoid putting it in an enclosed bag while it is running.

## Updates

Lid Awake checks for updates daily by default and lets you choose when to install them. You can also choose **Check for Updates…** in the menu when no session is active. The current release is a prerelease; [test results and remaining checks](docs/VALIDATION.md) are recorded separately.

## How it compares

[Compare Lid Awake with Lidless and Awayke](COMPETITIVE-ANALYSIS.md) for size, helper security, recovery, safety features, updates, and testing. Lid Awake favors short sessions with a fixed end time and a small menu; Lidless offers more controls, while Awayke has a quicker toggle and more session modes. The comparison also lists what Lid Awake has not tested yet.

The [roadmap](docs/ROADMAP.md) tracks physical acceptance and the remaining reliability checks before adding more session modes.

## More information

- [How it works and its safety limits](docs/IMPLEMENTATION.md)
- [Product behavior and first-run flow](docs/PRODUCT.md)
- [Testing](docs/TESTING.md) and [release process](docs/RELEASE.md)
- [Original command-line script](lid-awake)

[MIT licensed](LICENSE).
