# Closed-lid menu bar apps: Lidless and Awayke

Research snapshot: 2026-09-27. Goal: a small macOS menu bar control that lets local agent sessions continue with the lid closed, without a password on every toggle. This is a source review and release inspection, not a live closed-lid test or a penetration test.

## Revisions inspected

| Project | Local clone | Source revision | Release inspected | License |
| --- | --- | --- | --- | --- |
| [Lidless](https://github.com/nghialuong/Lidless) | `~/github/Lidless` | [`1c432ed`](https://github.com/nghialuong/Lidless/tree/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb) (2026-08-06) | [`v0.1.3`](https://github.com/nghialuong/Lidless/releases/tag/v0.1.3); source changes since tag affect only the appcast | MIT |
| [Awayke](https://github.com/daemonphantom/Awayke) | `~/github/Awayke` | [`b502251`](https://github.com/daemonphantom/Awayke/tree/b50225198abb1c6e21c4d8da513bbd08fafa6a91) (2026-08-24) | [`v2.4.0`](https://github.com/daemonphantom/Awayke/releases/tag/v2.4.0); source changes since tag affect only the README | MIT |

Both use an `SMAppService` root LaunchDaemon to run `/usr/bin/pmset -a disablesleep 1/0` after one-time macOS approval. Both have an `osascript` administrator prompt fallback when the helper is unavailable. A normal IOKit idle-sleep assertion alone does not solve lid-close sleep. Apple's [Service Management documentation](https://developer.apple.com/documentation/servicemanagement/smappservice) describes this app/helper arrangement.

## Size and scope

Measurements below are from the downloaded release assets, with the disk image mounted read-only and the ZIP extracted. Installed sizes are `du` disk usage, so filesystem allocation and compression make them different from download sizes. Executable sizes are individual file lengths, not memory use.

| Measure | Lidless | Awayke |
| --- | ---: | ---: |
| Release download | 3,626,413 B DMG (3.63 MB) | 1,887,535 B ZIP (1.89 MB) |
| Installed `.app` | 5,756 KiB (5.62 MiB) | 2,376 KiB (2.32 MiB) |
| Main executable | 708,944 B | 489,072 B |
| Root helper executable | 256,016 B | 167,904 B |
| Swift source, raw lines | 3,150 app/helper/shared | 1,259 app/helper |
| Swift test source, raw lines | 1,394 | 108 |
| Third-party runtime dependency | Sparkle auto-updater, 2,832 KiB of installed framework | None found in the app bundle |

Lidless's installed app is about 2.4 times Awayke's size. Sparkle alone accounts for about half of Lidless's installed bytes. Lidless also has onboarding and settings windows, an auto-enable policy, state reconciliation, a signed appcast, and update UI. Awayke keeps the interface mostly in one 573-line `AppDelegate.swift`, with one-click on/off and right-click session choices. Raw line counts indicate maintenance surface, not correctness.

Both release apps passed `codesign --verify --strict` and `xcrun stapler validate` locally. Both carry Developer ID signatures and a stapled notarization ticket. This checks artifact integrity and distribution hygiene; it does not establish that the app is secure or works on this Mac.

## Code and behavior

| Area | Lidless | Awayke |
| --- | --- | --- |
| Root helper interface | Fixed boolean toggle plus state, heartbeat, and version calls; fixed `/usr/bin/pmset` path and arguments. [Helper](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/Sources/Helper/HelperService.swift) | Fixed boolean toggle; fixed `/usr/bin/pmset` path and arguments. [Helper](https://github.com/daemonphantom/Awayke/blob/b50225198abb1c6e21c4d8da513bbd08fafa6a91/AwaykeHelper/main.swift) |
| XPC client authorization | Calls `setCodeSigningRequirement` on every new connection, pinning the app bundle ID and developer Team ID. [Helper](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/Sources/Helper/HelperService.swift#L7-L37), [requirement](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/Sources/Shared/HelperProtocol.swift#L23-L52) | `shouldAcceptNewConnection` unconditionally resumes and accepts each connection. Its embedded `SMAuthorizedClients` entry is described in comments as protecting XPC, but that key is documented for clients allowed to *add and remove* a helper through `SMJobBless`. [Helper](https://github.com/daemonphantom/Awayke/blob/b50225198abb1c6e21c4d8da513bbd08fafa6a91/AwaykeHelper/main.swift#L24-L33), [plist](https://github.com/daemonphantom/Awayke/blob/b50225198abb1c6e21c4d8da513bbd08fafa6a91/AwaykeHelper/Info.plist), [Apple documentation](https://developer.apple.com/documentation/servicemanagement/smjobbless%28_%3A_%3A_%3A_%3A%29) |
| Recovery from app crash | Root helper clears the flag after a 90-second missed heartbeat, checked every 30 seconds. [Watchdog](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/Sources/Helper/HelperService.swift#L42-L92) | Clears the flag on normal quit and on the *next launch* after a crash, if the helper is approved. No independent watchdog. [App lifecycle](https://github.com/daemonphantom/Awayke/blob/b50225198abb1c6e21c4d8da513bbd08fafa6a91/Awayke/AppDelegate.swift#L65-L126) |
| State truth | Reads `pmset -g` and distinguishes unknown reads, verifies writes, and notices external changes. [Parser](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/Sources/Shared/PowerParsers.swift), [reconciler](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/Sources/Shared/StateReconciler.swift) | UI state is its in-memory `intent` following a successful `pmset` call; it does not read the actual flag in normal operation. [App state](https://github.com/daemonphantom/Awayke/blob/b50225198abb1c6e21c4d8da513bbd08fafa6a91/Awayke/AppDelegate.swift#L24-L60) |
| Safety policy | Default 20% battery cutoff and high-thermal pause; optional charging-only mode and duration. Checks every 30 seconds. [Defaults](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/Sources/Shared/SafetySettings.swift#L1-L28), [poll](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/Sources/Lidless/AppState.swift#L120-L142) | Optional 10/20/30% cutoff, default off because an unset `UserDefaults.integer` returns 0; event-driven battery updates and timed/until-reopen sessions. No thermal guard found. [Defaults](https://github.com/daemonphantom/Awayke/blob/b50225198abb1c6e21c4d8da513bbd08fafa6a91/Awayke/AppDelegate.swift#L52-L58), [battery](https://github.com/daemonphantom/Awayke/blob/b50225198abb1c6e21c4d8da513bbd08fafa6a91/Awayke/BatteryMonitor.swift) |
| Display/lock behavior | No explicit lid-close lock found in the reviewed app/helper paths. | Acquires a display-sleep assertion whose source says it also prevents screen saver and auto-lock while active. That deserves testing for a transit use case. [DisplayWakeKeeper](https://github.com/daemonphantom/Awayke/blob/b50225198abb1c6e21c4d8da513bbd08fafa6a91/Awayke/DisplayWakeKeeper.swift) |

### Security assessment

**Awayke's XPC boundary is the main concern.** Apple's [code-signing guidance](https://developer.apple.com/documentation/Technotes/tn3127-inside-code-signing-requirements) recommends `setCodeSigningRequirement` to restrict XPC clients. Awayke does not call it, and the cited Apple `SMJobBless` description limits `SMAuthorizedClients` to helper management. The implication from the source is that another local process able to reach its Mach service could ask the root helper to turn `SleepDisabled` on or off. The exposed operation is tightly limited to that boolean; this is **not** an arbitrary-command root interface. I did not attempt a live connection, so the reachability claim remains an inference from code and platform documentation. I would not adopt its helper unchanged.

Lidless's explicit client check is substantially better. Its watchdog is useful but narrower than its [onboarding claim](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/Sources/Lidless/OnboardingView.swift#L60-L69) that the Mac can never get stuck awake: `keepAwake` and the heartbeat timestamp live only in helper memory. If the helper itself exits while the persistent `pmset` flag is on, a relaunched helper starts with `keepAwake = false`, so this watchdog cannot know it owns an earlier hold. This is a code-level failure-mode inference, not a reproduced crash. Normal app exit also leaves the flag on until the watchdog fires, potentially about 90–120 seconds later.

Both change a **global** sleep setting. Neither has an exclusive owner token in `pmset`, so concurrent tools can interfere. Awayke's unconditional off write at startup can clear another tool's hold; Lidless detects external changes but can still auto-manage the same global flag. Any app we build needs an explicit ownership/reconciliation policy.

### Local compatibility finding

On this Mac (macOS 26.6.2), a read-only `pmset -g` did **not** contain a `SleepDisabled` line while the flag was off. A read-only `ioreg -r -c IOPMrootDomain -d 1 -l` did report `"SleepDisabled" = No`, and our [script](lid-awake) correctly reported off. Lidless's [strict parser](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/Sources/Shared/PowerParsers.swift#L11-L29) returns unknown when the `pmset` line is absent. This means its off-state read-back and external-state reconciliation cannot be assumed to work here. We did not turn sleep prevention on to check whether `pmset -g` prints the line in that state. A fork should read `IOPMrootDomain` as our script does, then test both directions on the target Mac.

## Hygiene and maturity signals

| Signal, as of 2026-09-27 | Lidless | Awayke |
| --- | --- | --- |
| Repository history | 77 commits; 3 distinct commit authors; created June 2026 | 50 commits; 5 distinct commit authors; created May 2026 |
| Releases | Four tags through `v0.1.3`; signed/notarized DMG | Four `v*` tags through `v2.4.0`; signed/notarized ZIP |
| Automation | Checked-in macOS build/test [GitHub Actions workflow](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/.github/workflows/ci.yml). Its signed/notarized [release script](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/scripts/release.sh) is run manually on a Mac with the author's signing certificate and keys, then uploads the DMG to GitHub Releases. | Checked-in signed/notarized release workflow; no separate test workflow or test invocation in that release workflow. [Release](https://github.com/daemonphantom/Awayke/blob/b50225198abb1c6e21c4d8da513bbd08fafa6a91/.github/workflows/release.yml) |
| Test breadth | Eight XCTest source files covering parsers, safety and state transitions | One 108-line Swift test runner covering battery policy and lid-session tracking |
| Recent CI evidence | CI [succeeded on the inspected commit](https://github.com/nghialuong/Lidless/actions/runs/31087681451) on August 6. September 12–13 fork PR runs are `action_required` with zero jobs, which can indicate an approval gate; they do not establish a billing outage. The checked-in `CLAUDE.md` billing claim conflicts with the successful run history. | Release workflow exists; no automatic test gate found in it. |

Stars and version numbers are weak quality signals for projects only a few months old. The stronger signals here are signed releases, auditable build recipes, tests that cover failure-prone state transitions, and clear runtime authorization of the root helper.

GitHub says [standard hosted runners are free for public repositories](https://docs.github.com/en/actions/concepts/billing-and-usage), including the standard macOS runner used by Lidless CI. The `action_required` status on the recent fork PR runs is consistent with GitHub's [workflow approval policy for outside contributors](https://docs.github.com/en/enterprise-cloud@latest/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository). We cannot see the maintainer's billing settings; the observed successful run is enough to reject a blanket claim that public-repo CI cannot run because it costs money.

## Verification performed

- Cloned both repositories without local source edits; each working tree is clean after review.
- Downloaded the latest release asset of each, measured size, inspected bundle contents, and passed `codesign --verify --strict` plus `xcrun stapler validate` on both apps.
- `swiftc -parse` passed for both sets of Swift sources. Awayke's checked-in pure Swift test runner compiled and passed all 25 checks.
- Generated Lidless's Xcode project with `xcodegen`. `xcodebuild test -scheme Lidless-CI -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet` produced no test result after more than three minutes and was terminated. This is **not** a test pass or failure. The generated Xcode project is ignored, and the tracked plist changed by XcodeGen was restored.
- During this comparison, no competitor app was installed or run, no helper registered, no `pmset` write made, and no closed-lid test performed.

## Decision and resulting implementation

1. **Best security and recovery reference:** Lidless, for its signed client check, state reconciliation, recovery watchdog, and tests. Its `pmset -g` read path did not report the off state on this Mac.
2. **Best minimal UI reference:** Awayke. Its timed sessions fit short trips, but its root helper needs runtime XPC client authorization and independent recovery before reuse.
3. **Our choice:** We built a small native menu bar app. The current [architecture](docs/IMPLEMENTATION.md) uses I/O Registry for observed state, a signed-client privileged helper, bounded sessions, a battery cutoff, and a recovery marker. It does not include a lock-on-close option; that remains a possible future feature. The original [shell script](lid-awake) remains available.

Because the intended use includes **transit**, an awake closed Mac should not go into an enclosed bag. None of the software guards can guarantee safe cooling under a heavy local agent workload.
