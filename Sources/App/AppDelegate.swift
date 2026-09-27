import AppKit
import ServiceManagement
import Sparkle

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
    private var activity: NSObjectProtocol?
    private var helperNeedsRepair = false
    private var helperProblem: String?
    private var recoveryIssue: String?
    private var repairing = false

    private var expectedHelperBuild: Int {
        Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setStatusIcon()
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
        if active || observed != false || repairing {
            throw NSError(domain: "LidAwake.Update", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Restore normal sleep before installing an update."])
        }
    }

    func menuWillOpen(_ menu: NSMenu) { renderMenu() }

    private func tick() {
        if active { helper.heartbeat() }
        refresh()
    }

    private func refresh() {
        observed = PowerState.observedSleepDisabled()
        if helper.status == .enabled {
            helper.getHealth { [weak self] health, error in
                guard let self else { return }
                if let health {
                    self.active = health.active
                    self.remaining = health.remaining
                    self.recoveryIssue = health.recoveryIssue
                    self.helperNeedsRepair = health.build != self.expectedHelperBuild
                    self.helperProblem = self.helperNeedsRepair
                        ? "The registered helper is build \(health.build); this app is build \(self.expectedHelperBuild)."
                        : nil
                } else {
                    self.helperNeedsRepair = true
                    self.helperProblem = error ?? "The helper is not responding."
                    if self.observed == false { self.active = false; self.recoveryIssue = nil }
                }
                self.updateIcon()
                self.renderMenu()
                if self.setupPending && !self.helperNeedsRepair {
                    self.setupPending = false
                    self.showInfo("Helper Ready", "The helper is approved. Choose Keep Awake when you are ready.")
                }
            }
        } else {
            active = false
            helperNeedsRepair = false
            helperProblem = nil
            recoveryIssue = nil
            updateIcon()
            renderMenu()
        }
    }

    private func updateIcon() {
        if active && activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.idleSystemSleepDisabled, .suddenTerminationDisabled],
                reason: "Lid Awake session heartbeat")
        } else if !active, let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        setStatusIcon()
        item.button?.contentTintColor = nil
    }

    private func setStatusIcon() {
        let enabled = observed == true
        let icon = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { _ in
            let badge = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 18, height: 18), xRadius: 4, yRadius: 4)
            (enabled
                ? NSColor(calibratedRed: 0.88, green: 0.36, blue: 0.05, alpha: 1)
                : NSColor(calibratedWhite: 0.42, alpha: 1)).setFill()
            badge.fill()

            (enabled ? NSColor.black : NSColor.white).setStroke()
            let screen = NSBezierPath(roundedRect: NSRect(x: 4.5, y: 7, width: 11, height: 8), xRadius: 1, yRadius: 1)
            screen.lineWidth = 1.5
            screen.stroke()
            let base = NSBezierPath()
            base.move(to: NSPoint(x: 3.8, y: 5.5))
            base.line(to: NSPoint(x: 16.2, y: 5.5))
            base.lineWidth = 1.6
            base.lineCapStyle = .round
            base.stroke()
            return true
        }
        icon.isTemplate = false
        icon.accessibilityDescription = enabled ? (active ? "Lid Awake on" : "Sleep disabled") : "Lid Awake off"
        item.button?.image = icon
    }

    private func renderMenu() {
        menu.removeAllItems()
        let headline: String
        if repairing { headline = "Repairing helper…" }
        else if recoveryIssue != nil { headline = "Restoring sleep · retrying" }
        else if helperNeedsRepair && observed == false { headline = "Helper needs repair" }
        else if observed == true && helperNeedsRepair { headline = "Sleep disabled · helper unavailable" }
        else if active && observed == false { headline = "Sleep changed outside Lid Awake" }
        else if active { headline = "On · \(max(0, remaining / 60)) min remaining" }
        else if observed == true && helper.status != .enabled { headline = "Sleep disabled · helper unavailable" }
        else if observed == true { headline = "Sleep disabled by another tool" }
        else if observed == false { headline = "Off · normal sleep" }
        else { headline = "Sleep state unavailable" }
        let stateItem = NSMenuItem(title: headline, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: active ? "Restore Normal Sleep" : "Keep Awake", action: #selector(toggleAwake), keyEquivalent: "")
        toggle.target = self
        toggle.isEnabled = !busy && !repairing && (active || (observed == false && !helperNeedsRepair))
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
        if helperNeedsRepair && helper.status == .enabled {
            let repair = NSMenuItem(title: "Repair Helper…", action: #selector(repairHelper), keyEquivalent: "")
            repair.target = self
            repair.isEnabled = !repairing && !busy && !active && observed == false
            menu.addItem(repair)
        }
        if observed == true && (!active || recoveryIssue != nil || helperNeedsRepair) {
            let recovery = NSMenuItem(title: "Sleep Recovery Instructions…", action: #selector(showRecovery), keyEquivalent: "")
            recovery.target = self
            menu.addItem(recovery)
        }
        menu.addItem(.separator())

        let update = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        update.isEnabled = !active && observed == false && !repairing && updater.updater.canCheckForUpdates
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
        guard !helperNeedsRepair else { showError(helperProblem ?? "Repair the helper before starting a session."); return }
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
        guard !active && observed == false && !repairing else { return }
        updater.updater.checkForUpdates()
    }

    @objc private func showRecovery() {
        let problem = recoveryIssue ?? helperProblem ?? "Lid Awake cannot control the current sleep setting."
        showInfo("Restore Normal Sleep", "\(problem)\n\nIf no other tool should own this setting, run in Terminal:\n\nsudo /usr/bin/pmset -a disablesleep 0")
    }

    @objc private func repairHelper() {
        guard !repairing && !active && observed == false else { return }
        repairing = true
        renderMenu()
        helper.repair { [weak self] error in
            guard let self else { return }
            self.repairing = false
            if let error { self.showError("Helper repair failed: \(error)") }
            else if self.helper.status == .requiresApproval {
                self.setupPending = true
                self.helper.openApprovalSettings()
                self.showInfo("Approve the Helper", "macOS needs approval for the updated helper in System Settings > General > Login Items & Extensions.")
            }
            self.refresh()
        }
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
