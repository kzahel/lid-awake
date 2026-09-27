# Lid Awake

A small macOS menu bar app for keeping a MacBook running with its lid closed during a bounded session. It uses a signed, bundled privileged helper to change `pmset -a disablesleep`, so routine toggles do not require a sudo password.

**Status:** prerelease. GitHub Actions signs and notarizes [v0.0.4](https://github.com/kzahel/lid-awake/releases/tag/v0.0.4). VM tests passed installation, Sparkle updates, one-time helper approval, on/off toggling without repeated password prompts, quit restoration, and forced-exit watchdog restoration. Version 0.0.4 fixes the icon disappearing against a black menu bar; both icon states and on/off toggling were verified on a physical Mac. That Mac also remained reachable through a remote agent session with its lid closed using version 0.0.3. The original command-line script remains at [`lid-awake`](lid-awake).

To try the test build, download the `v0.0.4` DMG from the release, drag **Lid Awake.app** to **Applications**, and open it. Choose **Set Up Helper…** from its menu bar icon and approve Lid Awake under **System Settings → General → Login Items & Extensions**. Existing users can choose **Check for Updates…** when an awake session is off.

See [the product and UX plan](docs/PRODUCT.md), [the architecture and safety plan](docs/IMPLEMENTATION.md), [release operations](docs/RELEASE.md), [end-to-end testing](docs/TESTING.md), and [current validation](docs/VALIDATION.md). The [competitive analysis](COMPETITIVE-ANALYSIS.md) covers Lidless and Awayke.

MIT licensed.
