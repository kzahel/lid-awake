# Lid Awake

A small macOS menu bar app for keeping a MacBook running with its lid closed during a bounded session. It uses a signed, bundled privileged helper to change `pmset -a disablesleep`, so routine toggles do not require a sudo password.

**Status:** implementation in progress. The original command-line script remains at [`lid-awake`](lid-awake).

See [the product and UX plan](docs/PRODUCT.md), [the architecture and safety plan](docs/IMPLEMENTATION.md), and [release operations](docs/RELEASE.md). The [competitive analysis](COMPETITIVE-ANALYSIS.md) covers Lidless and Awayke.

MIT licensed.
