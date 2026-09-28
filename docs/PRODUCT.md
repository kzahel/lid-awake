# Product behavior and UX

## Purpose

Lid Awake is a macOS menu bar power control. It can prevent idle sleep while the lid is open or keep work running after the lid closes. Starting a session takes effect immediately. The app does not wait for a lid-close event or keep the display lit.

## Session flow

1. Choose **Keep Mac awake → Lid open only** or **Even when closed**.
2. Choose **Stop when → Until I turn it off**, **Until unplugged** (charging only), or **After a time limit**. Timed choices range from 15 minutes to 4 hours.
3. Choose **Start Keeping Awake** and confirm the safety explanation. **Restore Normal Sleep** ends and disarms the session.

Until unplugged ends as soon as battery power is observed. Reconnecting does not restart it. A time limit, battery cutoff, heat cutoff, sustained unknown power, missed heartbeat, normal quit, or helper restart also disarms the session. None of these stops the user's workload while the lid stays open; they restore the normal macOS sleep policy.

The menu shows the power source, active condition, countdown when timed, and the last stop reason. The badge is neutral when off, active while Lid Awake owns a session, marked **B** on battery, and marked **!** for repair or recovery. Accessibility descriptions convey the same state.

## Safety and recovery

**Settings…** offers a battery cutoff of Off, 15%, 20%, or 30%. It affects sessions that continue on battery. The privileged helper always stops for serious or critical macOS thermal state, 30 seconds without a readable power source, or a lost app heartbeat. It refuses to start when the power source or sleep state cannot be read or macOS reports serious heat. Keep a running Mac ventilated, especially with the lid closed.

Closed-lid sessions create a root-owned marker before changing the global `SleepDisabled` flag. The helper clears it only after observing normal sleep. On restart it restores any interrupted closed-lid session. Failed restoration remains visible and retries. An external sleep override is displayed separately; Lid Awake does not claim it. Lid-open-only sessions use a macOS idle-sleep activity and leave the global flag alone.

The helper accepts XPC requests from the signed app with the expected identifier and team. First use registers it with `SMAppService`; macOS may ask for background approval. **Repair Helper…** re-registers an older helper only while normal sleep is observed. Sparkle offers user-controlled updates while no session is active.

## Support and removal

**Report a Problem…** shows an editable diagnostic summary and recent Lid Awake unified-log events before opening a prefilled GitHub issue. The user can copy the report and nothing is submitted automatically. **Send Feedback…** opens an issue without diagnostics. **Uninstall…** ends any session, verifies normal sleep, unregisters the helper and login item, offers removal of preferences and diagnostic state, then guides the user to move the app to Trash.

English is the source language and German is available through the macOS app language setting.

## Acceptance

The [validation record](VALIDATION.md) distinguishes local tests, signed VM checks, and the physical lid test still required for this candidate. The VM cannot emulate a physical lid switch or replace stock SIP-enabled acceptance.
