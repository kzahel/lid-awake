# Changelog

Notable changes to Lid Awake are listed by release version.

## [0.0.6]

- Start the privileged helper when needed and let it exit after 30 idle seconds. It stays running during an awake session and restarts after a crash to restore normal sleep.
- Check the registered helper version before starting a session, so an older helper cannot silently handle a new app's request.
- Improve the installer disk image with a clearer drag-to-Applications layout.

## [0.0.5]

- Verify that normal sleep has returned before clearing the recovery marker, and retry restoration when macOS does not confirm it.
- Stop sessions for low battery, serious heat, an unknown power source, a missed heartbeat, or an expired time limit.
- Detect an older registered helper after an update and offer an in-app repair action.
