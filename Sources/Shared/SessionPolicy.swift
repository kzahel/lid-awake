import Foundation

enum SessionPolicy {
    static let allowedMinutes = [30, 60, 120, 240]
    static let heartbeatTimeout: TimeInterval = 90
    static let minimumBatteryPercent = 15
    static let unknownPowerGrace: TimeInterval = 30

    static func shouldRestore(now: TimeInterval, lastHeartbeat: TimeInterval,
                              deadline: TimeInterval, power: PowerSource,
                              unknownPowerSince: TimeInterval?,
                              thermal: ProcessInfo.ThermalState) -> Bool {
        if now >= deadline || now - lastHeartbeat > heartbeatTimeout { return true }
        if thermal == .serious || thermal == .critical { return true }
        switch power {
        case .ac:
            return false
        case .battery(let percent):
            return percent <= minimumBatteryPercent
        case .unknown:
            return unknownPowerSince.map { now - $0 >= unknownPowerGrace } ?? false
        }
    }
}
