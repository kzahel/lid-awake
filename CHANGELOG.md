# Changelog

Notable changes to Lid Awake are listed by release version.

## [0.0.9]

- Keep the menu focused on awake sessions and helper status. Move updates, launch at login, problem reports, feedback, uninstall, and quit into General and Support tabs in Settings.

## [0.0.8]

- Wrap the German heat-safety label inside the Settings window.

## [0.0.7]

- Add Until I turn it off, Until unplugged, and 15-minute through 4-hour sessions. Choose whether to keep the Mac awake only with the lid open or even when it closes.
- Add adjustable battery cutoff (Off, 15%, 20%, or 30%). Every session still stops for serious heat, unreadable power, or a lost app heartbeat. The helper records the last stop reason.
- Show charging and battery status, active battery and repair cues in the menu icon, session stop notifications, and a safety settings window.
- Add reviewable problem reports with recent Lid Awake events, a feedback link, and guided uninstall that verifies normal sleep before removing the helper.
- Add German localization for the app's controls, safety guidance, and recovery messages.

## [0.0.6]

- Start the privileged helper when needed and let it exit after 30 idle seconds. It stays running during an awake session and restarts after a crash to restore normal sleep.
- Check the registered helper version before starting a session, so an older helper cannot silently handle a new app's request.
- Improve the installer disk image with a clearer drag-to-Applications layout.

## [0.0.5]

- Verify that normal sleep has returned before clearing the recovery marker, and retry restoration when macOS does not confirm it.
- Stop sessions for low battery, serious heat, an unknown power source, a missed heartbeat, or an expired time limit.
- Detect an older registered helper after an update and offer an in-app repair action.
