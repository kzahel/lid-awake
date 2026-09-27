import Foundation

enum SessionPolicy {
    static let allowedMinutes = [30, 60, 120, 240]
    static let heartbeatTimeout: TimeInterval = 90
    static let minimumBatteryPercent = 15

    static func shouldRestore(now: TimeInterval, lastHeartbeat: TimeInterval,
                              deadline: TimeInterval, batteryPercent: Int?) -> Bool {
        now >= deadline || now - lastHeartbeat > heartbeatTimeout ||
        (batteryPercent.map { $0 <= minimumBatteryPercent } ?? false)
    }
}
