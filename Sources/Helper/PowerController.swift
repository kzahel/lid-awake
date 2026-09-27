import Foundation

protocol PowerController {
    func observedSleepDisabled() -> Bool?
    func powerSource() -> PowerSource
    func thermalState() -> ProcessInfo.ThermalState
    func setSleepDisabled(_ disabled: Bool) -> (Bool, String?)
}

struct SystemPowerController: PowerController {
    func observedSleepDisabled() -> Bool? { PowerState.observedSleepDisabled() }
    func powerSource() -> PowerSource { PowerState.currentPowerSource() }
    func thermalState() -> ProcessInfo.ThermalState { ProcessInfo.processInfo.thermalState }

    func setSleepDisabled(_ disabled: Bool) -> (Bool, String?) {
        guard let result = PowerState.command("/usr/bin/pmset", ["-a", "disablesleep", disabled ? "1" : "0"]) else {
            return (false, "Could not launch pmset.")
        }
        return result.code == 0 ? (true, nil) : (false, result.output.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
