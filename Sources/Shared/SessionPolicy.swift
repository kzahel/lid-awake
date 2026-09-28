import Foundation

enum SessionMode: Int, Codable {
    case timed = 0
    case untilStopped = 1
    case untilUnplugged = 2
}

enum StopReason: String, Codable {
    case manual, deadline, unplugged, lowBattery, highThermal, unknownPower
    case heartbeatLost, helperRestart, externalChange, restorationFailed
}

struct SessionConfiguration: Codable, Equatable {
    let mode: SessionMode
    let minutes: Int
    let allowClosedLid: Bool
    let batteryCutoff: Int
}

struct SessionDetails: Codable {
    let active: Bool
    let configuration: SessionConfiguration?
    let remaining: Int
    let lastStopReason: StopReason?
    let recoveryIssue: String?
}

enum SessionPolicy {
    static let allowedMinutes = [15, 30, 60, 120, 180, 240]
    static let allowedBatteryCutoffs = [0, 15, 20, 30]
    static let heartbeatTimeout: TimeInterval = 90
    static let unknownPowerGrace: TimeInterval = 30

    static func valid(_ configuration: SessionConfiguration) -> Bool {
        allowedBatteryCutoffs.contains(configuration.batteryCutoff)
            && (configuration.mode == .timed
                ? allowedMinutes.contains(configuration.minutes)
                : configuration.minutes == 0)
    }

    static func stopReason(now: TimeInterval, lastHeartbeat: TimeInterval,
                           deadline: TimeInterval?, power: PowerSource,
                           unknownPowerSince: TimeInterval?,
                           thermal: ProcessInfo.ThermalState,
                           configuration: SessionConfiguration) -> StopReason? {
        if let deadline, now >= deadline { return .deadline }
        if now - lastHeartbeat > heartbeatTimeout { return .heartbeatLost }
        if thermal == .serious || thermal == .critical { return .highThermal }
        switch power {
        case .ac:
            return nil
        case .battery(let percent):
            if configuration.mode == .untilUnplugged { return .unplugged }
            if configuration.batteryCutoff > 0 && percent <= configuration.batteryCutoff {
                return .lowBattery
            }
            return nil
        case .unknown:
            return unknownPowerSince.map { now - $0 >= unknownPowerGrace } == true ? .unknownPower : nil
        }
    }

    // Preserve the original policy entry point for older tests and helper harnesses.
    static func shouldRestore(now: TimeInterval, lastHeartbeat: TimeInterval,
                              deadline: TimeInterval, power: PowerSource,
                              unknownPowerSince: TimeInterval?,
                              thermal: ProcessInfo.ThermalState) -> Bool {
        stopReason(now: now, lastHeartbeat: lastHeartbeat, deadline: deadline, power: power,
                   unknownPowerSince: unknownPowerSince, thermal: thermal,
                   configuration: SessionConfiguration(mode: .timed, minutes: 30,
                                                       allowClosedLid: true, batteryCutoff: 15)) != nil
    }
}
