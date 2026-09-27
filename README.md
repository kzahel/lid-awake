# Lid Awake

A small macOS menu bar app for keeping a MacBook running with its lid closed during a bounded session. It uses a signed, bundled privileged helper to change `pmset -a disablesleep`, so routine toggles do not require a sudo password.

**Status:** pre-release. The signed app and update archive have passed local notarization; helper approval and physical lid behavior still need end-to-end testing. The original command-line script remains at [`lid-awake`](lid-awake).

See [the product and UX plan](docs/PRODUCT.md), [the architecture and safety plan](docs/IMPLEMENTATION.md), [release operations](docs/RELEASE.md), and [current validation](docs/VALIDATION.md). The [competitive analysis](COMPETITIVE-ANALYSIS.md) covers Lidless and Awayke.

MIT licensed.
