import AppKit

final class SettingsWindowController: NSWindowController {
    private let batteryPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let onBatteryChange: (Int) -> Void

    init(batteryCutoff: Int, onBatteryChange: @escaping (Int) -> Void) {
        self.onBatteryChange = onBatteryChange
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 430, height: 250),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = tr("Lid Awake Settings")
        window.center()
        super.init(window: window)

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 22, left: 22, bottom: 22, right: 22)
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = root

        let heading = NSTextField(labelWithString: tr("Safety"))
        heading.font = .boldSystemFont(ofSize: 16)
        root.addArrangedSubview(heading)

        let batteryRow = NSStackView()
        batteryRow.orientation = .horizontal
        batteryRow.alignment = .centerY
        batteryRow.spacing = 12
        let label = NSTextField(labelWithString: tr("Stop on battery at"))
        batteryRow.addArrangedSubview(label)
        batteryRow.addArrangedSubview(batteryPicker)
        for cutoff in SessionPolicy.allowedBatteryCutoffs {
            batteryPicker.addItem(withTitle: cutoff == 0 ? tr("Off") : "\(cutoff)%")
            batteryPicker.lastItem?.tag = cutoff
        }
        batteryPicker.selectItem(withTag: batteryCutoff)
        batteryPicker.target = self
        batteryPicker.action = #selector(batteryChanged)
        root.addArrangedSubview(batteryRow)

        let explanation = NSTextField(wrappingLabelWithString:
            tr("This applies to sessions that run on battery. Until Unplugged ends as soon as the charger disconnects."))
        explanation.textColor = .secondaryLabelColor
        root.addArrangedSubview(explanation)

        let heat = NSTextField(wrappingLabelWithString: tr("High heat: stop at serious or critical thermal state"))
        root.addArrangedSubview(heat)
        let heatDetail = NSTextField(wrappingLabelWithString:
            tr("The heat safeguard stays on for every session, including while charging."))
        heatDetail.textColor = .secondaryLabelColor
        root.addArrangedSubview(heatDetail)

        NSLayoutConstraint.activate([
            explanation.widthAnchor.constraint(equalToConstant: 380),
            heat.widthAnchor.constraint(equalToConstant: 380),
            heatDetail.widthAnchor.constraint(equalToConstant: 380)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func batteryChanged() {
        onBatteryChange(batteryPicker.selectedItem?.tag ?? 15)
    }

    func present() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
