import AppKit

enum SettingsAction {
    case checkForUpdates
    case toggleAutomaticChecks
    case toggleLaunchAtLogin
    case toggleSkipStartConfirmation
    case reportProblem
    case sendFeedback
    case uninstall
}

final class SettingsWindowController: NSWindowController {
    private let batteryPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let automaticChecks = NSButton(checkboxWithTitle: tr("Automatically Check for Updates"), target: nil, action: nil)
    private let launchAtLogin = NSButton(checkboxWithTitle: tr("Launch at Login"), target: nil, action: nil)
    private let skipStartConfirmation = NSButton(checkboxWithTitle: tr("Don't show start confirmation"), target: nil, action: nil)
    private let checkUpdates = NSButton(title: tr("Check for Updates…"), target: nil, action: nil)
    private let updateStatus = NSTextField(wrappingLabelWithString: "")
    private let onBatteryChange: (Int) -> Void
    private let onAction: (SettingsAction) -> Void

    init(batteryCutoff: Int, onBatteryChange: @escaping (Int) -> Void,
         onAction: @escaping (SettingsAction) -> Void) {
        self.onBatteryChange = onBatteryChange
        self.onAction = onAction
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 370),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = tr("Lid Awake Settings")
        super.init(window: window)

        let tabs = NSTabView(frame: NSRect(x: 0, y: 0, width: 500, height: 370))
        tabs.autoresizingMask = [.width, .height]
        tabs.addTabViewItem(makeSafetyTab(batteryCutoff: batteryCutoff))
        tabs.addTabViewItem(makeGeneralTab())
        tabs.addTabViewItem(makeSupportTab())
        window.contentView = tabs
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func makeSafetyTab(batteryCutoff: Int) -> NSTabViewItem {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.addArrangedSubview(NSTextField(labelWithString: tr("Stop on battery at")))
        for cutoff in SessionPolicy.allowedBatteryCutoffs {
            batteryPicker.addItem(withTitle: cutoff == 0 ? tr("Off") : "\(cutoff)%")
            batteryPicker.lastItem?.tag = cutoff
        }
        batteryPicker.selectItem(withTag: batteryCutoff)
        batteryPicker.target = self
        batteryPicker.action = #selector(batteryChanged)
        row.addArrangedSubview(batteryPicker)

        let explanation = wrappingLabel(tr("This applies to sessions that run on battery. Until Unplugged ends as soon as the charger disconnects."))
        explanation.textColor = .secondaryLabelColor
        let heat = wrappingLabel(tr("High heat: stop at serious or critical thermal state"))
        let heatDetail = wrappingLabel(tr("The heat safeguard stays on for every session, including while charging."))
        heatDetail.textColor = .secondaryLabelColor
        skipStartConfirmation.target = self
        skipStartConfirmation.action = #selector(skipStartConfirmationChanged)
        return makeTab(tr("Safety"), views: [heading(tr("Safety")), row, explanation, heat, heatDetail,
                                             heading(tr("Confirmation")), skipStartConfirmation])
    }

    private func makeGeneralTab() -> NSTabViewItem {
        automaticChecks.target = self
        automaticChecks.action = #selector(automaticChecksChanged)
        checkUpdates.target = self
        checkUpdates.action = #selector(checkForUpdates)
        checkUpdates.bezelStyle = .rounded
        updateStatus.textColor = .secondaryLabelColor
        updateStatus.widthAnchor.constraint(equalToConstant: 420).isActive = true
        launchAtLogin.target = self
        launchAtLogin.action = #selector(launchAtLoginChanged)
        return makeTab(tr("General"), views: [
            heading(tr("Updates")), automaticChecks, checkUpdates, updateStatus,
            heading(tr("Startup")), launchAtLogin
        ])
    }

    private func makeSupportTab() -> NSTabViewItem {
        return makeTab(tr("Support"), views: [
            heading(tr("Support")),
            button(tr("Report a Problem…"), #selector(reportProblem)),
            button(tr("Send Feedback…"), #selector(sendFeedback)),
            heading(tr("Removal")),
            button(tr("Uninstall…"), #selector(uninstall))
        ])
    }

    private func makeTab(_ title: String, views: [NSView]) -> NSTabViewItem {
        let tab = NSTabViewItem(identifier: title)
        tab.label = title
        let container = NSView()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        views.forEach { stack.addArrangedSubview($0) }
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -20)
        ])
        tab.view = container
        return tab
    }

    private func heading(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: 15)
        return label
    }

    private func wrappingLabel(_ title: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: title)
        label.widthAnchor.constraint(equalToConstant: 420).isActive = true
        return label
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    func updateControls(automaticChecks: Bool, launchAtLogin: Bool,
                        skipStartConfirmation: Bool, canCheckForUpdates: Bool, updateStatus: String) {
        self.automaticChecks.state = automaticChecks ? .on : .off
        self.launchAtLogin.state = launchAtLogin ? .on : .off
        self.skipStartConfirmation.state = skipStartConfirmation ? .on : .off
        checkUpdates.isEnabled = canCheckForUpdates
        self.updateStatus.stringValue = updateStatus
        self.updateStatus.isHidden = updateStatus.isEmpty
    }

    func present() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func batteryChanged() { onBatteryChange(batteryPicker.selectedItem?.tag ?? 15) }
    @objc private func automaticChecksChanged() { onAction(.toggleAutomaticChecks) }
    @objc private func launchAtLoginChanged() { onAction(.toggleLaunchAtLogin) }
    @objc private func skipStartConfirmationChanged() { onAction(.toggleSkipStartConfirmation) }
    @objc private func checkForUpdates() { onAction(.checkForUpdates) }
    @objc private func reportProblem() { onAction(.reportProblem) }
    @objc private func sendFeedback() { onAction(.sendFeedback) }
    @objc private func uninstall() { onAction(.uninstall) }
}
