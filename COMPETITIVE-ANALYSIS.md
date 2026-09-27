# Closed-lid menu bar apps: Lid Awake, Lidless, and Awayke

Research snapshot: 2026-09-27. Goal: a small macOS menu bar control that lets local agent sessions continue with the lid closed, without a password on every toggle. The Lidless and Awayke findings are source and release inspections; neither competitor was installed or tested with a closed lid. Lid Awake has separate [VM and physical Mac validation](docs/VALIDATION.md). None of the three received a penetration test here.

## Revisions inspected

| Project | Local clone | Source revision | Release inspected | License |
| --- | --- | --- | --- | --- |
| [Lidless](https://github.com/nghialuong/Lidless) | `~/github/Lidless` | [`1c432ed`](https://github.com/nghialuong/Lidless/tree/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb) (2026-08-06) | [`v0.1.3`](https://github.com/nghialuong/Lidless/releases/tag/v0.1.3); source changes since tag affect only the appcast | MIT |
| [Awayke](https://github.com/daemonphantom/Awayke) | `~/github/Awayke` | [`b502251`](https://github.com/daemonphantom/Awayke/tree/b50225198abb1c6e21c4d8da513bbd08fafa6a91) (2026-08-24) | [`v2.4.0`](https://github.com/daemonphantom/Awayke/releases/tag/v2.4.0); source changes since tag affect only the README | MIT |
| [Lid Awake](https://github.com/kzahel/lid-awake) | this repository | [`bae0094`](https://github.com/kzahel/lid-awake/tree/bae009422d9ed0c80ff054a6edf7982f324968a2) (2026-09-27) | [`v0.0.4`](https://github.com/kzahel/lid-awake/releases/tag/v0.0.4) prerelease | MIT |

All three use an `SMAppService` root LaunchDaemon to run `/usr/bin/pmset -a disablesleep 1/0` after one-time macOS approval. Lidless and Awayke also have an `osascript` administrator prompt fallback when the helper is unavailable; Lid Awake requires its helper. A normal IOKit idle-sleep assertion alone does not solve lid-close sleep. Apple's [Service Management documentation](https://developer.apple.com/documentation/servicemanagement/smappservice) describes this app/helper arrangement.

## Size and scope

Lidless and Awayke measurements are from downloaded release assets, with the disk image mounted read-only and the ZIP extracted. Lid Awake measurements are from its published `v0.0.4` DMG and the installed `v0.0.4` app on this Mac. Installed sizes are `du` disk usage, so filesystem allocation and compression make them different from download sizes. Executable sizes are individual file lengths, not memory use. Packaging and supported CPU architectures also affect these numbers.

| Measure | Lid Awake | Lidless | Awayke |
| --- | ---: | ---: | ---: |
| Release download | 1,530,455 B DMG (1.53 MB) | 3,626,413 B DMG (3.63 MB) | 1,887,535 B ZIP (1.89 MB) |
| Installed `.app` | 3,408 KiB (3.33 MiB) | 5,756 KiB (5.62 MiB) | 2,376 KiB (2.32 MiB) |
| Main executable | 245,552 B | 708,944 B | 489,072 B |
| Root helper executable | 237,728 B | 256,016 B | 167,904 B |
| Swift source, raw lines | 575 app/helper/shared | 3,150 app/helper/shared | 1,259 app/helper |
| Swift test/harness source, raw lines | 94 | 1,394 | 108 |
| Third-party runtime dependency | Sparkle, 2,784 KiB of installed framework | Sparkle, 2,832 KiB of installed framework | None found in the app bundle |

Lid Awake sits between Awayke and Lidless in installed size. Sparkle accounts for about 82% of Lid Awake's installed disk usage, so the updater is most of its footprint. Lidless has onboarding and settings windows, an auto-enable policy, state reconciliation, and update UI. Awayke keeps the interface mostly in one 573-line `AppDelegate.swift`, with one-click on/off and right-click session choices. Lid Awake keeps its interface in a menu and requires a confirmation before each session. Raw line counts indicate maintenance surface, not correctness or completeness.

All three release apps passed `codesign --verify --strict` and `xcrun stapler validate` locally and carry Developer ID signatures and stapled notarization tickets. This checks artifact integrity and distribution hygiene; it does not establish that an app is secure or works with a closed lid.

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

All three change a **global** sleep setting. None has an exclusive owner token in `pmset`, so concurrent tools can interfere. Awayke's unconditional off write at startup can clear another tool's hold; Lidless detects external changes but can still auto-manage the same global flag. Lid Awake refuses to start when the flag is already on and uses a marker for its own session, but another root process can still race with it.

### Local compatibility finding

On this Mac (macOS 26.6.2), a read-only `pmset -g` did **not** contain a `SleepDisabled` line while the flag was off. A read-only `ioreg -r -c IOPMrootDomain -d 1 -l` did report `"SleepDisabled" = No`, and our [script](lid-awake) correctly reported off. Lidless's [strict parser](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/Sources/Shared/PowerParsers.swift#L11-L29) returns unknown when the `pmset` line is absent. This means its off-state read-back and external-state reconciliation cannot be assumed to work here. During the competitor review, we did not turn sleep prevention on to check whether `pmset -g` prints the line in that state. Lid Awake instead reads `IOPMrootDomain`; its on/off behavior was subsequently tested on this Mac.

## Where Lid Awake differs

| Area | Lid Awake | Lidless | Awayke |
| --- | --- | --- | --- |
| Starting a session | Explicit 30-minute to 4-hour limit and confirmation each time; no indefinite mode | More settings and automatic enable options | Fast one-click toggle; timed, until-reopen, or indefinite sessions |
| Root helper boundary | Fixed XPC commands and an exact app-ID/team signing requirement; rejection by a mismatched client has **not** been tested | Fixed commands and an exact app-ID/team signing requirement | Fixed boolean command, but no explicit runtime XPC client check found in the reviewed helper |
| Recovery | Normal quit requests immediate restoration; helper checks a 90-second missed heartbeat every five seconds and uses a persisted marker to restore on restart | Heartbeat watchdog, but its ownership state is in memory; normal quit can leave the flag on until watchdog recovery | Normal quit restores; after a crash, cleanup waits for the next launch with an approved helper |
| Observed state | Reads I/O Registry and refuses to start if sleep is already disabled by another tool; verifies an enable, but does not separately read back a successful disable | Reconciles state from `pmset -g`, whose off-state line was absent on this Mac | Mostly displays in-memory intent rather than reading the current flag |
| Battery and heat | Fixed 15% battery cutoff and session deadline in the helper; no thermal guard; an unreadable battery level skips the cutoff | Default 20% battery cutoff, thermal pause, and optional charging-only mode | Optional battery cutoff, off by default; no thermal guard found |
| Screen and lid policy | No explicit lock-on-close or lid-reopen auto-off | No explicit lock-on-close found in reviewed paths | Until-reopen mode; display-sleep assertion may also prevent auto-lock and needs physical testing |
| Updates | Sparkle signed feed; daily checks by default, user chooses installation; tagged releases built and notarized in GitHub Actions | Sparkle signed feed; signed release script is run manually | No bundled updater found; releases are downloaded manually |

Lid Awake's strongest fit is a short, deliberate transit session: it always has a deadline, does not claim another tool's existing sleep override, and has a tested helper recovery path. Its first-run approval and confirmation add clicks. It also offers fewer policies than Lidless and fewer session modes than Awayke. The `pmset` setting is global in all three; Lid Awake's marker tracks its own session but cannot prevent a separate root process from changing the flag at the same time.

The most important gaps in Lid Awake are its small unit-test suite, no thermal cutoff, no explicit screen-lock behavior, and no tested rejection of a wrongly signed XPC client. Its battery cutoff has a unit test but has not been observed at 15% on an installed app. A Sparkle update with an approved helper worked, but Lid Awake has no explicit helper re-registration/repair flow like [Lidless's](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/Sources/Lidless/HelperManager.swift); one successful update does not settle every future helper change. Scheduled daily update discovery also remains untested through a full interval.

## Hygiene and maturity signals

| Signal, as of 2026-09-27 | Lid Awake | Lidless | Awayke |
| --- | --- | --- | --- |
| Repository history | Created September 2026; one human author plus release automation | 77 commits; 3 distinct commit authors; created June 2026 | 50 commits; 5 distinct commit authors; created May 2026 |
| Releases | Four `v0.0.x` prereleases on one day; signed/notarized DMG and update ZIP | Four tags through `v0.1.3`; signed/notarized DMG | Four `v*` tags through `v2.4.0`; signed/notarized ZIP |
| Automation | [GitHub Actions](https://github.com/kzahel/lid-awake/blob/bae009422d9ed0c80ff054a6edf7982f324968a2/.github/workflows/build.yml) builds/tests pushes, then signs, notarizes, and publishes tagged releases and the appcast. | Checked-in macOS build/test [GitHub Actions workflow](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/.github/workflows/ci.yml). Its signed/notarized [release script](https://github.com/nghialuong/Lidless/blob/1c432ede45ea8c3e6dd4aa148a4d840d4e4e48cb/scripts/release.sh) is run manually on a Mac with the author's signing certificate and keys, then uploads the DMG to GitHub Releases. | Checked-in signed/notarized release workflow; no separate test workflow or test invocation in that release workflow. [Release](https://github.com/daemonphantom/Awayke/blob/b50225198abb1c6e21c4d8da513bbd08fafa6a91/.github/workflows/release.yml) |
| Test breadth | Three XCTest cases for policy/parser logic plus a VM helper integration harness; signed app/XPC/manual VM flows and a physical lid session also tested | Eight XCTest source files covering parsers, safety and state transitions; our attempted test run did not finish | One 108-line Swift test runner covering battery policy and lid-session tracking; passed 25 checks locally |
| Release evidence | Published `v0.0.4` passes signature, notarization and Gatekeeper checks; Sparkle replacement and helper toggling worked in VM; physical Mac stayed reachable closed with `v0.0.3` | Release signature and stapled ticket verified here; CI [succeeded on the inspected commit](https://github.com/nghialuong/Lidless/actions/runs/31087681451). September 12–13 fork PR runs were `action_required` with zero jobs, which does not establish a billing outage. | Release signature and stapled ticket verified here; no live install or closed-lid test in this review |

Stars and version numbers are weak quality signals for projects this new. Lid Awake is especially young: four prereleases in a day show release machinery working, not long-term reliability. The stronger signals here are signed releases, auditable build recipes, tests that cover failure-prone state transitions, and clear runtime authorization of the root helper. Our direct Lid Awake tests offer more evidence for this Mac; they cannot be used to conclude that the untested competitors fail on a real Mac.

GitHub says [standard hosted runners are free for public repositories](https://docs.github.com/en/actions/concepts/billing-and-usage), including the standard macOS runner used by Lidless CI. The `action_required` status on the recent fork PR runs is consistent with GitHub's [workflow approval policy for outside contributors](https://docs.github.com/en/enterprise-cloud@latest/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository). We cannot see the maintainer's billing settings; the observed successful run is enough to reject a blanket claim that public-repo CI cannot run because it costs money.

## Competitor verification performed

- Cloned both repositories without local source edits; each working tree is clean after review.
- Downloaded the latest release asset of each, measured size, inspected bundle contents, and passed `codesign --verify --strict` plus `xcrun stapler validate` on both apps.
- `swiftc -parse` passed for both sets of Swift sources. Awayke's checked-in pure Swift test runner compiled and passed all 25 checks.
- Generated Lidless's Xcode project with `xcodegen`. `xcodebuild test -scheme Lidless-CI -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO -quiet` produced no test result after more than three minutes and was terminated. This is **not** a test pass or failure. The generated Xcode project is ignored, and the tracked plist changed by XcodeGen was restored.
- During this comparison, no competitor app was installed or run, no helper registered, no `pmset` write made, and no closed-lid test performed.

## Which one fits?

- **Lidless** has the broadest safety settings, onboarding, and test suite. Its release signing is manual, its installed app is the largest here, and the inspected `pmset -g` parser could not see the off state on this Mac. It is the strongest option to study if configurability and established code coverage matter most.
- **Awayke** is the smallest installed app and offers the quickest toggle, indefinite sessions, and an until-reopen mode. Its missing runtime XPC client check and lack of independent crash recovery are material concerns for an unattended transit session. Those are source-review findings, not live exploits or failure tests.
- **Lid Awake** makes bounded sessions mandatory, reads the actual I/O Registry state, and has a helper watchdog plus restart marker. Its signed CI release and an older-to-newer update have been exercised, and an earlier prerelease sustained a physical closed-lid remote session. It is still a one-day-old prerelease with few unit tests and no thermal guard or explicit lock behavior. The current `v0.0.4` has not yet had the complete physical lid-close and normal-sleep control test in [the test plan](docs/TESTING.md).

We built Lid Awake for this narrow workflow rather than adopting either helper unchanged. Its [architecture](docs/IMPLEMENTATION.md) and [validation record](docs/VALIDATION.md) make the implementation and remaining checks reviewable. The original [shell script](lid-awake) remains available.

Because the intended use includes **transit**, an awake closed Mac should not go into an enclosed bag. None of the software guards can guarantee safe cooling under a heavy local agent workload.
