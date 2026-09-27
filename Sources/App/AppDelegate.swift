import AppKit
import ServiceManagement
import Sparkle

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, SPUUpdaterDelegate {
    private let helper = HelperClient()
    private lazy var updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var timer: Timer?
    private var active = false
    private var remaining = 0
    private var observed: Bool?
    private var chosenMinutes = 120
    private var busy = false
    private var setupPending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item.button?.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: "Lid Awake off")
        item.menu = menu
        menu.delegate = self
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.tick() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard active else { return .terminateNow }
        helper.disable { ok, error in
            if !ok { self.showError(error ?? "Could not restore normal sleep.") }
            sender.reply(toApplicationShouldTerminate: ok)
        }
        return .terminateLater
    }

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem,
                 updateCheck: SPUUpdateCheck) throws {
        if active {
            throw NSError(domain: "LidAwake.Update", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Turn off Lid Awake before installing an update."])
        }
    }

    func menuWillOpen(_ menu: NSMenu) { renderMenu() }

    private func tick() {
        helper.heartbeat()
        refresh()
    }

    private func refresh() {
        observed = PowerState.observedSleepDisabled()
        if helper.status == .enabled {
            helper.getStatus { [weak self] isActive, seconds in
                guard let self else { return }
                if let isActive { self.active = isActive; self.remaining = seconds }
                self.updateIcon()
                self.renderMenu()
            }
        } else {
            active = false
            updateIcon()
            renderMenu()
        }
        if setupPending && helper.status == .enabled {
            setupPending = false
            showInfo("Helper Ready", "The helper is approved. Choose Keep Awake when you are ready.")
        }
    }

    private func updateIcon() {
        item.button?.image = NSImage(systemSymbolName: "laptopcomputer", accessibilityDescription: active ? "Lid Awake on" : "Lid Awake off")
        item.button?.contentTintColor = active ? .systemOrange : nil
    }

    private func renderMenu() {
        menu.removeAllItems()
        let headline: String
        if active { headline = "On · \(max(0, remaining / 60)) min remaining" }
        else if observed == true { headline = "Sleep disabled by another tool" }
        else if observed == false { headline = "Off · normal sleep" }
        else { headline = "Sleep state unavailable" }
        let stateItem = NSMenuItem(title: headline, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: active ? "Restore Normal Sleep" : "Keep Awake", action: #selector(toggleAwake), keyEquivalent: "")
        toggle.target = self
        toggle.isEnabled = !busy && (active || observed == false)
        menu.addItem(toggle)

        let durationMenu = NSMenu()
        for minutes in [30, 60, 120, 240] {
            let title = minutes < 60 ? "30 minutes" : "\(minutes / 60) hour\(minutes == 60 ? "" : "s")"
            let choice = NSMenuItem(title: title, action: #selector(selectDuration(_:)), keyEquivalent: "")
            choice.target = self
            choice.tag = minutes
            choice.state = chosenMinutes == minutes ? .on : .off
            choice.isEnabled = !active
            durationMenu.addItem(choice)
        }
        let duration = NSMenuItem(title: "Duration", action: nil, keyEquivalent: "")
        duration.submenu = durationMenu
        menu.addItem(duration)

        if helper.status != .enabled {
            let setup = NSMenuItem(title: helper.status == .requiresApproval ? "Approve Helper…" : "Set Up Helper…", action: #selector(setupHelper), keyEquivalent: "")
            setup.target = self
            menu.addItem(setup)
        }
        menu.addItem(.separator())

        let update = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        update.isEnabled = !active && updater.updater.canCheckForUpdates
        menu.addItem(update)
        let checks = NSMenuItem(title: "Automatically Check for Updates", action: #selector(toggleAutomaticChecks), keyEquivalent: "")
        checks.target = self
        checks.state = updater.updater.automaticallyChecksForUpdates ? .on : .off
        menu.addItem(checks)
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Lid Awake", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func selectDuration(_ sender: NSMenuItem) { chosenMinutes = sender.tag; renderMenu() }

    @objc private func toggleAwake() {
        if active {
            busy = true
            helper.disable { [weak self] ok, error in
                guard let self else { return }
                self.busy = false
                if ok { self.active = false }
                if !ok { self.showError(error ?? "Could not restore sleep.") }
                self.refresh()
            }
            return
        }
        guard helper.status == .enabled else { setupHelper(); return }
        let alert = NSAlert()
        alert.messageText = "Keep running with the lid closed?"
        alert.informativeText = "Lid Awake will restore normal sleep after \(chosenMinutes) minutes, if this app stops responding, or when battery reaches 15%. Keep the Mac ventilated while it runs."
        alert.addButton(withTitle: "Keep Awake")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        busy = true
        helper.enable(minutes: chosenMinutes) { [weak self] ok, error in
            guard let self else { return }
            self.busy = false
            if ok { self.active = true; self.remaining = self.chosenMinutes * 60 }
            if !ok { self.showError(error ?? "Could not enable Lid Awake.") }
            self.refresh()
        }
    }

    @objc private func setupHelper() {
        if helper.status == .requiresApproval {
            setupPending = true
            helper.openApprovalSettings()
            showInfo("Approve the Helper", "In System Settings > General > Login Items & Extensions, allow Lid Awake to run in the background. An administrator may need to authenticate.")
            return
        }
        let alert = NSAlert()
        alert.messageText = "Set up the Lid Awake helper?"
        alert.informativeText = "The signed helper changes the system sleep setting so future toggles do not require a sudo password. macOS will ask you to approve it once."
        alert.addButton(withTitle: "Set Up Helper")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try helper.register()
            setupPending = true
            if helper.status == .requiresApproval { helper.openApprovalSettings() }
            refresh()
        } catch {
            if helper.status == .requiresApproval {
                setupPending = true
                helper.openApprovalSettings()
            } else { showError(error.localizedDescription) }
        }
    }

    @objc private func checkForUpdates() {
        guard !active else { return }
        updater.updater.checkForUpdates()
    }

    @objc private func toggleAutomaticChecks() {
        updater.updater.automaticallyChecksForUpdates.toggle()
        renderMenu()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { showError(error.localizedDescription) }
        renderMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showError(_ message: String) { showInfo("Lid Awake Error", message) }
    private func showInfo(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
