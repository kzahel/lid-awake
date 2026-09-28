# End-to-end testing

## Helper setup and state

On a disposable Tart Mac VM with passwordless `sudo` configured, the privileged
helper's power-setting logic can be checked without changing Login Items consent. Stage this repository
inside the guest's read-only share and run
`sudo -n bash scripts/test-helper-in-vm.sh` from that staged copy. The script
requires a `VirtualMac` model and root, verifies on/off, marker recovery
after a process restart, the 90-second no-heartbeat watchdog, unplugged and
open-lid-only modes, and retry after a
successful `pmset` exit with failed state read-back. It restores
normal sleep from an exit trap. This
exercises the helper logic directly; the signed app's XPC connection and
one-time macOS approval still require the UI test below.

Use a signed, notarized app copied to `/Applications`. On first launch, choose **Set Up Helper…**. Approve the background daemon in System Settings. Confirm that later on/off toggles do not request a sudo password. After each closed-lid-capable toggle, compare the menu with:

```sh
/usr/sbin/ioreg -r -c IOPMrootDomain -d 1 -l | /usr/bin/sed -n 's/.*"SleepDisabled" = //p'
```

With Lid Awake off, expect `No`. With **Even when closed** active, expect `Yes`. With **Lid open only** active, expect `No` and confirm an idle-sleep assertion with `pmset -g assertions`. Quit the app while on; expect normal sleep to return. Repeat with a forced app termination and wait up to 90 seconds for the watchdog. Test a helper restart in an isolated Mac testbed and verify that the recovery marker restores normal sleep.

Check timed, Until I turn it off, and Until unplugged choices. Confirm Until unplugged is unavailable on battery and ends without rearming after a power-source change. Test the 15%, 20%, 30%, and Off battery policies with injected readings in the helper harness; do not drain a physical Mac solely to test thresholds. Confirm serious heat still stops a session when the battery cutoff is Off. In the menu, verify the last stop reason, countdown, battery and repair icon cues, and a stop notification. Review the Safety, General, and Support Settings tabs in English and German; only session controls, Settings, and Quit should remain in the menu.

In the Keep Awake confirmation, select **Don't show this again** and confirm. End the session, then start another and verify the confirmation is skipped while the safety checks still apply. In **Settings… → Safety**, uncheck **Don't show start confirmation** and verify the prompt returns. Check that selecting the suppression box and then cancelling does not save the preference.

Open **Settings… → Support → Report a Problem…** with the helper both available and unavailable. Confirm the summary and bounded Lid Awake events are reviewable and editable, **Copy Report** works, and opening GitHub leaves submission to the user. **Send Feedback…** should have no diagnostics. Test **Uninstall…** from off, active, and recovery states: it must verify normal sleep before unregistering the helper, remove login registration, and explain the final move to Trash. Check both choices for retaining or clearing preferences and diagnostic state. Under **General**, verify automatic update and launch-at-login toggles persist. Confirm **Quit Lid Awake** in the main menu restores normal sleep during an active session.

With the signed helper approved, leave Lid Awake off and wait 40 seconds after closing its menu. `launchctl print system/com.kzahel.lidawake.helper` should show no running PID. Opening the menu should start the helper; it should exit again after the menu closes and another 40 idle seconds. During a session it should remain running, including with the menu closed. Force-kill the helper during a session in an isolated testbed and verify launchd restarts it and the startup marker recovery restores `SleepDisabled = No`.

Run `scripts/test-xpc-denial-in-vm.sh` against the installed signed helper. It compiles an unsigned client, attempts a fixed XPC operation, and requires both a client connection failure and the helper's explicit code-signing rejection log. A generic XPC failure alone does not prove that the signing boundary worked.

## Menu bar contrast

Use both a light wallpaper and a solid black wallpaper, with macOS in dark appearance. Check that the laptop badge is visible while Lid Awake is off and while it is on. The off badge should be neutral with a white laptop; the active badge should be orange with a black laptop. Confirm that the menu still opens from each state.

## Physical lid test

Do this on a ventilated surface. Start a foreground heartbeat in Terminal:

```sh
while :; do date -u '+%Y-%m-%dT%H:%M:%SZ'; sleep 5; done | tee ~/Desktop/lid-awake-heartbeat.log
```

Enable Lid Awake, close the lid for 90 seconds, reopen it, and stop the heartbeat with Ctrl-C. The timestamps should continue at roughly five-second intervals during the closed period. Confirm that your remote agent session stayed reachable and record whether the screen locked while closed. Then turn Lid Awake off, confirm `SleepDisabled = No`, and repeat the lid close; the timestamp stream should pause while the Mac sleeps. Check the log against the actual close/reopen times rather than inferring them from the timestamp stream alone.

## Update test

In a claimed macOS VM, also test the manual check without installing anything:

- With the latest release and normal sleep, open **Settings… → General → Check for Updates…**. Expect Sparkle's **You're up to date!** dialog, then the same result beneath the button after dismissal. Check again to confirm it remains usable.
- With an older build, expect the available version both in Sparkle's window and beneath the button. Check again while that window is open; it should focus the offer without leaving Settings at **Checking for updates…**. Dismiss the offer without installing.
- With sleep disabled, expect a disabled button and a visible instruction to restore normal sleep. Restore sleep and confirm the button becomes enabled again. Also check helper repair and unreadable power-state explanations when exercising those failure paths.
- Launch an isolated Debug app with `--args -SUFeedURL https://raw.githubusercontent.com/kzahel/lid-awake/main/missing-test-appcast.xml -SUEnableAutomaticChecks NO` for a missing-feed check. Expect an error dialog, then a persistent error beneath the button after dismissal. Relaunch without the overrides and verify a successful check. Do not change the published appcast for this test.
- Confirm automatic checks initialize without opening Settings: with automatic checks enabled and the Debug app's last-check date cleared, launch it and verify a new `SULastCheckTime` preference before opening any windows. Restore test preferences afterward. This does not replace observing a full daily interval.
- Inspect the General tab in English and German with both a result and the blocked-check explanation visible.

Install a signed older version in `/Applications`, publish a newer signed version and appcast, use **Settings… → General → Check for Updates…**, and install it. Confirm the new version, Gatekeeper acceptance, helper status, and a fresh on/off toggle. If the menu says **Helper needs repair**, choose **Repair Helper…** while normal sleep is on, then confirm the registered helper build matches the app. Try while an awake session is active; the app should refuse installation until the session is off. Never substitute two clean installs for this old-to-new test.
