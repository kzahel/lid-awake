# End-to-end testing

## Helper setup and state

On a disposable Tart Mac VM with passwordless `sudo` configured, the privileged
helper's power-setting logic can be checked without changing Login Items consent. Stage this repository
inside the guest's read-only share and run
`sudo -n bash scripts/test-helper-in-vm.sh` from that staged copy. The script
requires a `VirtualMac` model and root, verifies on/off, marker recovery
after a process restart, the 90-second no-heartbeat watchdog, and retry after a
successful `pmset` exit with failed state read-back. It restores
normal sleep from an exit trap. This
exercises the helper logic directly; the signed app's XPC connection and
one-time macOS approval still require the UI test below.

Use a signed, notarized app copied to `/Applications`. On first launch, choose **Keep Awake**, then **Set Up Helper** in the prompt. Approve the background daemon in System Settings. Confirm that later on/off toggles do not request a sudo password. After each toggle, compare the menu with:

```sh
/usr/sbin/ioreg -r -c IOPMrootDomain -d 1 -l | /usr/bin/sed -n 's/.*"SleepDisabled" = //p'
```

With Lid Awake off, expect `No`. With it on, expect `Yes`. Quit the app while on; expect normal sleep to return. Repeat with a forced app termination and wait up to 90 seconds for the watchdog. Test a helper restart in an isolated Mac testbed and verify that the recovery marker restores normal sleep.

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

Install a signed older version in `/Applications`, publish a newer signed version and appcast, use **Check for Updates…**, and install it. Confirm the new version, Gatekeeper acceptance, helper status, and a fresh on/off toggle. If the menu says **Helper needs repair**, choose **Repair Helper…** while normal sleep is on, then confirm the registered helper build matches the app. Try while an awake session is active; the app should refuse installation until the session is off. Never substitute two clean installs for this old-to-new test.
