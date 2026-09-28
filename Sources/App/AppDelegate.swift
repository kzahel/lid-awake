import AppKit
import ServiceManagement
import Sparkle
import os
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, SPUUpdaterDelegate {
    private let helper = HelperClient()
    private lazy var updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let log = Logger(subsystem: "com.kzahel.lidawake", category: "app")
    private var timer: Timer?
    private var active = false
    private var remaining = 0
    private var observed: Bool?
    private var chosenMinutes = UserDefaults.standard.object(forKey: "durationMinutes") as? Int ?? 120
    private var chosenMode = SessionMode(rawValue: UserDefaults.standard.integer(forKey: "sessionMode")) ?? .timed
    private var allowClosedLid = UserDefaults.standard.object(forKey: "allowClosedLid") as? Bool ?? true
    private var batteryCutoff = UserDefaults.standard.object(forKey: "batteryCutoff") as? Int ?? 15
    private var sessionDetails: SessionDetails?
    private var powerSource: PowerSource = .unknown
    private var lastShownStopReason: StopReason?
    private var lastKnownActive = false
    private var settingsWindow: SettingsWindowController?
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
        refresh(checkHelper: true)
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.tick() }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard active else { return .terminateNow }
        helper.disable { ok, error in
            if !ok { self.showError(error ?? tr("Could not restore normal sleep.")) }
            sender.reply(toApplicationShouldTerminate: ok)
        }
        return .terminateLater
    }

    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem,
                 updateCheck: SPUUpdateCheck) throws {
        if active || observed != false || repairing {
            throw NSError(domain: "LidAwake.Update", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: tr("Restore normal sleep before installing an update.")])
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        renderMenu()
        refresh(checkHelper: true)
    }

    private func tick() {
        if active { helper.heartbeat() }
        refresh()
    }

    private func refresh(checkHelper: Bool = false) {
        let previousObserved = observed
        observed = PowerState.observedSleepDisabled()
        powerSource = PowerState.currentPowerSource()
        if helper.status == .enabled &&
            (active || setupPending || checkHelper || (observed == true && previousObserved != true)) {
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
                    if !self.helperNeedsRepair {
                        self.helper.getDetails { [weak self] details in
                            guard let self, let details else { return }
                            self.sessionDetails = details
                            self.active = details.active
                            self.remaining = details.remaining
                            self.recoveryIssue = details.recoveryIssue
                            self.maybeNotifyStop(details.lastStopReason)
                            self.updateIcon()
                            self.renderMenu()
                        }
                    }
                } else {
                    self.helperNeedsRepair = true
                    self.helperProblem = error ?? tr("The helper is not responding.")
                    if self.observed == false { self.active = false; self.recoveryIssue = nil }
                }
                self.updateIcon()
                self.renderMenu()
                if self.setupPending && !self.helperNeedsRepair {
                    self.setupPending = false
                    self.showInfo(tr("Helper Ready"), tr("The helper is approved. Choose Keep Awake when you are ready."))
                }
            }
        } else if helper.status != .enabled {
            active = false
            sessionDetails = nil
            helperNeedsRepair = false
            helperProblem = nil
            recoveryIssue = nil
            updateIcon()
            renderMenu()
        } else {
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
        let isActive = active
        let warning = recoveryIssue != nil || helperNeedsRepair || (enabled && !active)
        let battery = active && { if case .battery = powerSource { return true }; return false }()
        let icon = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { _ in
            let badge = NSBezierPath(roundedRect: NSRect(x: 1, y: 1, width: 18, height: 18), xRadius: 4, yRadius: 4)
            (warning
                ? NSColor.systemRed
                : enabled || isActive
                ? NSColor(calibratedRed: 0.88, green: 0.36, blue: 0.05, alpha: 1)
                : NSColor(calibratedWhite: 0.42, alpha: 1)).setFill()
            badge.fill()

            (enabled || isActive || warning ? NSColor.black : NSColor.white).setStroke()
            let screen = NSBezierPath(roundedRect: NSRect(x: 4.5, y: 7, width: 11, height: 8), xRadius: 1, yRadius: 1)
            screen.lineWidth = 1.5
            screen.stroke()
            let base = NSBezierPath()
            base.move(to: NSPoint(x: 3.8, y: 5.5))
            base.line(to: NSPoint(x: 16.2, y: 5.5))
            base.lineWidth = 1.6
            base.lineCapStyle = .round
            base.stroke()
            if warning || battery {
                let symbol = warning ? "!" : "B"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 8),
                    .foregroundColor: NSColor.black
                ]
                NSColor.white.setFill()
                NSBezierPath(ovalIn: NSRect(x: 11, y: 0, width: 9, height: 9)).fill()
                (symbol as NSString).draw(at: NSPoint(x: warning ? 14.1 : 12.8, y: 0.1), withAttributes: attrs)
            }
            return true
        }
        icon.isTemplate = false
        icon.accessibilityDescription = tr(warning ? "Lid Awake needs attention"
            : active ? (battery ? "Lid Awake on battery" : "Lid Awake on power")
            : enabled ? "Sleep disabled by another tool" : "Lid Awake off")
        item.button?.image = icon
    }

    private func renderMenu() {
        menu.removeAllItems()
        let headline: String
        if repairing { headline = tr("Repairing helper…") }
        else if recoveryIssue != nil { headline = tr("Restoring sleep · retrying") }
        else if helperNeedsRepair && observed == false { headline = tr("Helper needs repair") }
        else if observed == true && helperNeedsRepair { headline = tr("Sleep disabled · helper unavailable") }
        else if active && observed == false && sessionDetails?.configuration?.allowClosedLid == true {
            headline = tr("Sleep changed outside Lid Awake")
        }
        else if active {
            let configuration = sessionDetails?.configuration
            switch configuration?.mode {
            case .untilStopped: headline = tr("On · until turned off")
            case .untilUnplugged: headline = tr("On · until unplugged")
            default: headline = trf("On · %@ remaining", durationLabel(max(1, (remaining + 59) / 60)))
            }
        }
        else if observed == true && helper.status != .enabled { headline = tr("Sleep disabled · helper unavailable") }
        else if observed == true { headline = tr("Sleep disabled by another tool") }
        else if observed == false { headline = tr("Off · normal sleep") }
        else { headline = tr("Sleep state unavailable") }
        let stateItem = NSMenuItem(title: headline, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        let powerItem = NSMenuItem(title: powerSourceLabel(), action: nil, keyEquivalent: "")
        powerItem.isEnabled = false
        menu.addItem(powerItem)
        if !active, let reason = sessionDetails?.lastStopReason {
            let lastStop = NSMenuItem(title: trf("Last stop · %@", stopReasonText(reason)), action: nil, keyEquivalent: "")
            lastStop.isEnabled = false
            menu.addItem(lastStop)
        }
        menu.addItem(.separator())

        if active {
            let stop = NSMenuItem(title: tr("Restore Normal Sleep"), action: #selector(toggleAwake), keyEquivalent: "")
            stop.target = self
            stop.isEnabled = !busy
            menu.addItem(stop)
            if let configuration = sessionDetails?.configuration {
                let scope = tr(configuration.allowClosedLid ? "Even when the lid closes" : "Lid open only")
                let scopeItem = NSMenuItem(title: scope, action: nil, keyEquivalent: "")
                scopeItem.isEnabled = false
                menu.addItem(scopeItem)
            }
        } else {
            let scopeMenu = NSMenu()
            for (title, value) in [("Lid open only", false), ("Even when closed", true)] {
                let choice = NSMenuItem(title: tr(title), action: #selector(selectScope(_:)), keyEquivalent: "")
                choice.target = self
                choice.tag = value ? 1 : 0
                choice.state = allowClosedLid == value ? .on : .off
                scopeMenu.addItem(choice)
            }
            let scope = NSMenuItem(title: tr("Keep Mac awake"), action: nil, keyEquivalent: "")
            scope.submenu = scopeMenu
            menu.addItem(scope)

            let stopMenu = NSMenu()
            for (title, mode) in [("Until I turn it off", SessionMode.untilStopped),
                                  ("Until unplugged", .untilUnplugged), ("After a time limit", .timed)] {
                let choice = NSMenuItem(title: tr(title), action: #selector(selectMode(_:)), keyEquivalent: "")
                choice.target = self
                choice.tag = mode.rawValue
                choice.state = chosenMode == mode ? .on : .off
                choice.isEnabled = mode != .untilUnplugged || powerSource == .ac
                stopMenu.addItem(choice)
            }
            let stopWhen = NSMenuItem(title: tr("Stop when"), action: nil, keyEquivalent: "")
            stopWhen.submenu = stopMenu
            menu.addItem(stopWhen)

            if chosenMode == .timed {
                let durationMenu = NSMenu()
                for minutes in SessionPolicy.allowedMinutes {
                    let title = durationLabel(minutes)
                    let choice = NSMenuItem(title: title, action: #selector(selectDuration(_:)), keyEquivalent: "")
                    choice.target = self
                    choice.tag = minutes
                    choice.state = chosenMinutes == minutes ? .on : .off
                    durationMenu.addItem(choice)
                }
                let duration = NSMenuItem(title: trf("Time limit · %@", durationLabel(chosenMinutes)), action: nil, keyEquivalent: "")
                duration.submenu = durationMenu
                menu.addItem(duration)
            }
            let start = NSMenuItem(title: tr("Start Keeping Awake"), action: #selector(toggleAwake), keyEquivalent: "")
            start.target = self
            start.isEnabled = !busy && !repairing && observed == false && !helperNeedsRepair
                && (chosenMode != .untilUnplugged || powerSource == .ac)
            menu.addItem(start)
        }

        if helper.status != .enabled {
            let setup = NSMenuItem(title: tr(helper.status == .requiresApproval ? "Approve Helper…" : "Set Up Helper…"), action: #selector(setupHelper), keyEquivalent: "")
            setup.target = self
            menu.addItem(setup)
        }
        if helperNeedsRepair && helper.status == .enabled {
            let repair = NSMenuItem(title: tr("Repair Helper…"), action: #selector(repairHelper), keyEquivalent: "")
            repair.target = self
            repair.isEnabled = !repairing && !busy && !active && observed == false
            menu.addItem(repair)
        }
        if observed == true && (!active || recoveryIssue != nil || helperNeedsRepair) {
            let recovery = NSMenuItem(title: tr("Sleep Recovery Instructions…"), action: #selector(showRecovery), keyEquivalent: "")
            recovery.target = self
            menu.addItem(recovery)
        }
        menu.addItem(.separator())

        let safety = NSMenuItem(title: trf("Safety · battery cutoff %@ · stop on serious heat", batteryCutoff == 0 ? tr("Off") : "\(batteryCutoff)%"), action: nil, keyEquivalent: "")
        safety.isEnabled = false
        menu.addItem(safety)
        let settings = NSMenuItem(title: tr("Settings…"), action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let report = NSMenuItem(title: tr("Report a Problem…"), action: #selector(reportProblem), keyEquivalent: "")
        report.target = self
        menu.addItem(report)
        let feedback = NSMenuItem(title: tr("Send Feedback…"), action: #selector(sendFeedback), keyEquivalent: "")
        feedback.target = self
        menu.addItem(feedback)
        let uninstall = NSMenuItem(title: tr("Uninstall…"), action: #selector(uninstall), keyEquivalent: "")
        uninstall.target = self
        menu.addItem(uninstall)
        menu.addItem(.separator())

        let update = NSMenuItem(title: tr("Check for Updates…"), action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        update.isEnabled = !active && observed == false && !repairing && updater.updater.canCheckForUpdates
        menu.addItem(update)
        let checks = NSMenuItem(title: tr("Automatically Check for Updates"), action: #selector(toggleAutomaticChecks), keyEquivalent: "")
        checks.target = self
        checks.state = updater.updater.automaticallyChecksForUpdates ? .on : .off
        menu.addItem(checks)
        let login = NSMenuItem(title: tr("Launch at Login"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: tr("Quit Lid Awake"), action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        chosenMinutes = sender.tag
        UserDefaults.standard.set(chosenMinutes, forKey: "durationMinutes")
        renderMenu()
    }

    @objc private func selectScope(_ sender: NSMenuItem) {
        allowClosedLid = sender.tag == 1
        UserDefaults.standard.set(allowClosedLid, forKey: "allowClosedLid")
        renderMenu()
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let mode = SessionMode(rawValue: sender.tag) else { return }
        chosenMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "sessionMode")
        renderMenu()
    }

    private func durationLabel(_ minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = minutes < 60 ? [.minute] : [.hour]
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes) min"
    }

    private func powerSourceLabel() -> String {
        switch powerSource {
        case .ac: return tr("Charging")
        case .battery(let percent): return trf("On battery · %d%%", percent)
        case .unknown: return tr("Power source unavailable")
        }
    }

    @objc private func toggleAwake() {
        guard !busy else { return }
        if active {
            busy = true
            helper.disable { [weak self] ok, error in
                guard let self else { return }
                self.busy = false
                if ok { self.active = false }
                if !ok { self.showError(error ?? tr("Could not restore sleep.")) }
                self.refresh(checkHelper: true)
            }
            return
        }
        guard helper.status == .enabled else { setupHelper(); return }
        guard !helperNeedsRepair else { showError(helperProblem ?? tr("Repair the helper before starting a session.")); return }
        busy = true
        renderMenu()
        helper.getHealth { [weak self] health, error in
            guard let self else { return }
            guard let health else {
                self.busy = false
                self.helperNeedsRepair = true
                let problem = error ?? tr("The helper is not responding.")
                self.helperProblem = problem
                self.renderMenu()
                self.showError(problem)
                return
            }
            guard health.build == self.expectedHelperBuild else {
                self.busy = false
                self.helperNeedsRepair = true
                let problem = "The registered helper is build \(health.build); this app is build \(self.expectedHelperBuild)."
                self.helperProblem = problem
                self.renderMenu()
                self.showError(problem)
                return
            }
            self.active = health.active
            self.remaining = health.remaining
            self.recoveryIssue = health.recoveryIssue
            guard !health.active && self.observed == false else {
                self.busy = false
                self.refresh()
                return
            }
            self.confirmAwake()
        }
    }

    private func confirmAwake() {
        let alert = NSAlert()
        alert.messageText = tr(allowClosedLid ? "Keep running even with the lid closed?" : "Keep the Mac awake while the lid is open?")
        let durationText: String
        switch chosenMode {
        case .timed: durationText = trf("after %@", durationLabel(chosenMinutes))
        case .untilStopped: durationText = tr("when you turn it off")
        case .untilUnplugged: durationText = tr("when you unplug the charger")
        }
        let batteryText: String
        if chosenMode == .untilUnplugged {
            batteryText = tr("Unplugging ends the session before the battery cutoff applies.")
        } else {
            batteryText = batteryCutoff == 0 ? tr("The app's battery cutoff is off.") : trf("On battery, it stops at %d%%.", batteryCutoff)
        }
        alert.informativeText = trf("The session ends %@, on serious heat, or if the app stops responding. %@ Keep the Mac ventilated while it runs.", durationText, batteryText)
        alert.addButton(withTitle: tr("Keep Awake"))
        alert.addButton(withTitle: tr("Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            busy = false
            renderMenu()
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        let configuration = SessionConfiguration(mode: chosenMode,
                                                 minutes: chosenMode == .timed ? chosenMinutes : 0,
                                                 allowClosedLid: allowClosedLid,
                                                 batteryCutoff: batteryCutoff)
        helper.start(configuration) { [weak self] ok, error in
            guard let self else { return }
            self.busy = false
            if ok {
                self.active = true
                self.lastShownStopReason = nil
                self.remaining = configuration.mode == .timed ? configuration.minutes * 60 : 0
                self.sessionDetails = SessionDetails(active: true, configuration: configuration,
                                                     remaining: self.remaining, lastStopReason: nil,
                                                     recoveryIssue: nil)
                self.log.notice("Started session mode=\(configuration.mode.rawValue) closedLid=\(configuration.allowClosedLid)")
            }
            if !ok { self.showError(error ?? tr("Could not enable Lid Awake.")) }
            self.refresh()
        }
    }

    @objc private func setupHelper() {
        if helper.status == .requiresApproval {
            setupPending = true
            helper.openApprovalSettings()
            showInfo(tr("Approve the Helper"), tr("In System Settings > General > Login Items & Extensions, allow Lid Awake to run in the background. An administrator may need to authenticate."))
            return
        }
        let alert = NSAlert()
        alert.messageText = tr("Set up the Lid Awake helper?")
        alert.informativeText = tr("The signed helper changes the system sleep setting so future toggles do not require a sudo password. macOS will ask you to approve it once.")
        alert.addButton(withTitle: tr("Set Up Helper"))
        alert.addButton(withTitle: tr("Cancel"))
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
        let problem = recoveryIssue ?? helperProblem ?? tr("Lid Awake cannot control the current sleep setting.")
        showInfo(tr("Restore Normal Sleep"), trf("%@\n\nIf no other tool should own this setting, run in Terminal:\n\nsudo /usr/bin/pmset -a disablesleep 0", problem))
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
                self.showInfo(tr("Approve the Helper"), tr("macOS needs approval for the updated helper in System Settings > General > Login Items & Extensions."))
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

    @objc private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(batteryCutoff: batteryCutoff) { [weak self] cutoff in
                guard let self else { return }
                self.batteryCutoff = cutoff
                UserDefaults.standard.set(cutoff, forKey: "batteryCutoff")
                self.renderMenu()
            }
        }
        settingsWindow?.present()
    }

    private func maybeNotifyStop(_ reason: StopReason?) {
        defer { lastKnownActive = active }
        guard lastKnownActive, !active, let reason, reason != .manual,
              reason != lastShownStopReason else { return }
        lastShownStopReason = reason
        log.notice("Session ended reason=\(reason.rawValue, privacy: .public)")
        let content = UNMutableNotificationContent()
        content.title = tr("Lid Awake turned off")
        content.body = stopReasonText(reason)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private func stopReasonText(_ reason: StopReason) -> String {
        switch reason {
        case .manual: return tr("You stopped the session.")
        case .deadline: return tr("The time limit ended.")
        case .unplugged: return tr("The charger was unplugged.")
        case .lowBattery: return tr("The battery reached the selected cutoff.")
        case .highThermal: return tr("macOS reported serious heat.")
        case .unknownPower: return tr("The power source could not be read.")
        case .heartbeatLost: return tr("The app stopped responding.")
        case .helperRestart: return tr("The helper restarted and restored normal sleep.")
        case .externalChange: return tr("The sleep setting changed outside Lid Awake.")
        case .restorationFailed: return tr("The helper had trouble restoring normal sleep.")
        }
    }

    private func diagnosticSummary() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let configuration = sessionDetails?.configuration
        let mode = configuration?.mode ?? chosenMode
        let scope = (configuration?.allowClosedLid ?? allowClosedLid) ? "Even when closed" : "Lid open only"
        let state = observed == true ? "Disabled" : observed == false ? "Normal" : "Unknown"
        let lastStop = sessionDetails?.lastStopReason?.rawValue ?? "None"
        let thermal = String(describing: ProcessInfo.processInfo.thermalState)
        return """
        Lid Awake: \(version) (build \(build))
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Sleep setting: \(state)
        Session active: \(active)
        Session mode: \(mode)
        Selected time limit: \(chosenMinutes) minutes
        Lid coverage: \(scope)
        Power: \(powerSourceLabel())
        Battery cutoff: \((configuration?.batteryCutoff ?? batteryCutoff) == 0 ? "Off" : "\(configuration?.batteryCutoff ?? batteryCutoff)%")
        Thermal state: \(thermal)
        Helper registration: \(helper.status)
        Helper needs repair: \(helperNeedsRepair)
        Recovery issue: \(recoveryIssue ?? "None")
        Last stop reason: \(lastStop)
        """
    }

    private func recentOwnEvents() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        process.arguments = ["show", "--last", "1h", "--style", "compact", "--predicate",
                             "subsystem == \"com.kzahel.lidawake\""]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return tr("Recent events unavailable.") }
            return String(String(decoding: data, as: UTF8.self).suffix(6_000))
        } catch { return tr("Recent events unavailable.") }
    }

    @objc private func reportProblem() {
        let summary = diagnosticSummary()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let events = self.recentOwnEvents()
            DispatchQueue.main.async { self.presentProblemReport(summary: summary, events: events) }
        }
    }

    private func presentProblemReport(summary: String, events: String) {
        let report = summary + "\nRecent Lid Awake events:\n" + events
        let alert = NSAlert()
        alert.messageText = tr("Report a Problem")
        alert.informativeText = tr("Review this diagnostic report before opening a GitHub issue. You can edit it or copy it. Nothing is sent automatically.")
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 230))
        editor.string = report
        editor.isEditable = true
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 230))
        scroll.hasVerticalScroller = true
        scroll.documentView = editor
        alert.accessoryView = scroll
        alert.addButton(withTitle: tr("Open GitHub Issue…"))
        alert.addButton(withTitle: tr("Copy Report"))
        alert.addButton(withTitle: tr("Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        let result = alert.runModal()
        if result == .alertFirstButtonReturn {
            var components = URLComponents(string: "https://github.com/kzahel/lid-awake/issues/new")!
            let issueBody = trf("Describe the problem:\n\n\nDiagnostics (reviewed by user):\n```\n%@\n```", editor.string)
            components.queryItems = [URLQueryItem(name: "title", value: tr("Problem with Lid Awake")),
                                     URLQueryItem(name: "body", value: issueBody)]
            if let url = components.url { NSWorkspace.shared.open(url) }
        } else if result == .alertSecondButtonReturn {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(editor.string, forType: .string)
        }
    }

    @objc private func sendFeedback() {
        if let url = URL(string: "https://github.com/kzahel/lid-awake/issues/new?title=Feedback%3A%20") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func uninstall() {
        let alert = NSAlert()
        alert.messageText = tr("Uninstall Lid Awake?")
        alert.informativeText = tr("Lid Awake will restore normal sleep, remove its helper and launch-at-login registration, then quit. Move the app to Trash afterward.")
        alert.addButton(withTitle: tr("Uninstall and Remove Preferences"))
        alert.addButton(withTitle: tr("Uninstall, Keep Preferences"))
        alert.addButton(withTitle: tr("Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        let choice = alert.runModal()
        guard choice == .alertFirstButtonReturn || choice == .alertSecondButtonReturn else { return }
        let removePreferences = choice == .alertFirstButtonReturn
        let proceed: () -> Void = { [weak self] in
            guard let self else { return }
            self.observed = PowerState.observedSleepDisabled()
            guard self.observed == false else {
                self.showError(tr("Normal sleep could not be verified. Restore it before uninstalling."))
                return
            }
            let unregister: () -> Void = {
                if self.helper.status == .notRegistered {
                    self.finishUninstall(removePreferences: removePreferences)
                    return
                }
                self.helper.unregister { error in
                if let error {
                    self.showError(trf("Could not unregister the helper: %@", error))
                    return
                }
                self.finishUninstall(removePreferences: removePreferences)
                }
            }
            if self.helper.status == .enabled {
                self.helper.getDetails { details in
                    guard let details, !details.active, details.recoveryIssue == nil else {
                        self.showError(tr("Normal sleep could not be verified. Restore it before uninstalling."))
                        return
                    }
                    if removePreferences {
                        self.helper.removeDiagnostics { ok, error in
                            if ok { unregister() }
                            else { self.showError(error ?? tr("Could not remove diagnostic state.")) }
                        }
                    } else { unregister() }
                }
            } else { unregister() }
        }
        if active {
            helper.disable { [weak self] ok, error in
                guard let self else { return }
                if ok { self.active = false; proceed() }
                else { self.showError(error ?? tr("Could not restore normal sleep.")) }
            }
        } else { proceed() }
    }

    private func finishUninstall(removePreferences: Bool) {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
        } catch {
            showError(trf("The helper was removed, but launch at login could not be removed: %@", error.localizedDescription))
            return
        }
        if removePreferences, let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        showInfo(tr("Lid Awake Uninstalled"), tr("The helper and login item are removed. Quit the app and move Lid Awake.app to Trash."))
        NSApp.terminate(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showError(_ message: String) { showInfo(tr("Lid Awake Error"), tr(message)) }
    private func showInfo(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: tr("OK"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
