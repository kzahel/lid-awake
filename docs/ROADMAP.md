# Roadmap

## Delivered in 0.0.7

- **Session choices:** Until I turn it off, Until unplugged while charging, and 15-minute to 4-hour time limits. Each choice starts preventing sleep immediately. Unplugging ends and disarms an Until unplugged session; reconnecting does not restart it.
- **Lid coverage:** Lid open only uses an idle-sleep activity. Even when closed uses the privileged `SleepDisabled` setting and a recovery marker. Neither option keeps the display lit or waits to arm at lid close.
- **Safety:** A battery cutoff of Off, 15%, 20%, or 30% applies to sessions that can run on battery. Serious/critical macOS thermal state, 30 seconds of unreadable power, and a lost app heartbeat always stop a session. The helper verifies restoration before clearing the marker. macOS thermal state is a pressure signal, not a prediction that the Mac will cool down safely in a bag.
- **Status and diagnostics:** The menu shows power source, session condition, countdown, last stop reason, and helper repair or recovery state. The icon adds battery and attention cues. App and helper events use unified logging; a reviewable problem report includes recent Lid Awake events and can open a prefilled GitHub issue. General feedback opens an issue without diagnostics.
- **Removal and language:** Uninstall verifies normal sleep, unregisters the helper and login item, optionally removes preferences and diagnostic state, and guides moving the app to Trash. App controls and guidance have a German translation; English remains the source language.

The [interactive menu sketch](../work/power-menu-sketch.html) shows the policy model. The shipped UI uses native AppKit menus and a settings window.

## Before a stable release

1. Run the timestamped heartbeat and normal-sleep control with the lid closed on the 0.0.7 candidate. Observe screen lock and remote agent continuity. Check helper approval, repair, quit recovery, update behavior, and uninstall on a stock SIP-enabled Mac. Earlier physical and VM checks do not cover this sequence together.
2. Exercise external `SleepDisabled` changes, unreadable I/O Registry state, helper launch failure, and thermal/unknown-power cutoffs in the root harness and installed app. Confirm the menu never reports normal sleep while recovery is unresolved.
3. Observe automatic update discovery over a full daily interval. Manual update and an earlier signed old-to-new installation have passed.
4. Review German menu width, VoiceOver descriptions, keyboard navigation, and longer localized alerts on a physical Mac.

## Later options to investigate

- Prototype **only while the lid is closed** before adding it. A lid-close event may arrive too late to install a global override, while pre-installing that override would also affect open-lid behavior.
- Consider **Until lid reopens** with a maximum duration only after the lid-state transition has physical test evidence.
- Decide whether a screen-lock action is useful without interfering with remote work. Keep the display behavior separate from system sleep behavior.
- Assess whether an optional earlier thermal cutoff at macOS's **fair** state helps in practice. The serious/critical guard remains mandatory.
- Consider automatic enable on charging only as a separate, clearly labeled opt-in policy. Selecting Until unplugged does not auto-arm on reconnect.
- Track bundle size, idle CPU, and memory across releases, and optimize measured regressions.
