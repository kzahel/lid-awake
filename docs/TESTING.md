# End-to-end testing

## Helper setup and state

Use a signed, notarized app copied to `/Applications`. On first launch, choose **Keep Awake**, then **Set Up Helper**. Approve the background daemon in System Settings. Confirm that later on/off toggles do not request a sudo password. After each toggle, compare the menu with:

```sh
/usr/sbin/ioreg -r -c IOPMrootDomain -d 1 -l | /usr/bin/sed -n 's/.*"SleepDisabled" = //p'
```

With Lid Awake off, expect `No`. With it on, expect `Yes`. Quit the app while on; expect normal sleep to return. Repeat with a forced app termination and wait up to 90 seconds for the watchdog. Test a helper restart in an isolated Mac testbed and verify that the recovery marker restores normal sleep.

## Physical lid test

Do this on a ventilated surface. Start a foreground heartbeat in Terminal:

```sh
while :; do date -u '+%Y-%m-%dT%H:%M:%SZ'; sleep 5; done | tee ~/Desktop/lid-awake-heartbeat.log
```

Enable Lid Awake, close the lid for 90 seconds, reopen it, and stop the heartbeat with Ctrl-C. The timestamps should continue at roughly five-second intervals during the closed period. Then turn Lid Awake off, confirm `SleepDisabled = No`, and repeat the lid close; the timestamp stream should pause while the Mac sleeps. Check the log against the actual close/reopen times rather than inferring them from the timestamp stream alone.

## Update test

Install a signed older version in `/Applications`, publish a newer signed version and appcast, use **Check for Updates…**, and install it. Confirm the new version, Gatekeeper acceptance, helper status, and a fresh on/off toggle. Try while an awake session is active; the app should refuse installation until the session is off. Never substitute two clean installs for this old-to-new test.
