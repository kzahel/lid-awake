import Foundation
import Darwin

final class HelperListener: NSObject, NSXPCListenerDelegate {
    private let appID: String
    private let service: HelperService

    init(label: String) {
        appID = HelperIdentity.appID(for: label)
        service = HelperService(label: label)
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.setCodeSigningRequirement(HelperIdentity.signingRequirement(for: appID))
        connection.exportedInterface = NSXPCInterface(with: LidAwakeHelperProtocol.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }
}

final class HelperService: NSObject, LidAwakeHelperProtocol {
    private let queue = DispatchQueue(label: "com.kzahel.lidawake.helper")
    private let marker: URL
    private var active = false
    private var deadline: TimeInterval = 0
    private var lastHeartbeat: TimeInterval = 0
    private var timer: DispatchSourceTimer?

    init(label: String) {
        precondition(geteuid() == 0, "Lid Awake helper must run as root")
        let dir = URL(fileURLWithPath: "/Library/Application Support/LidAwake", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        marker = dir.appendingPathComponent(label + ".session")
        super.init()
        if FileManager.default.fileExists(atPath: marker.path) {
            if setSleepDisabled(false).0 {
                try? FileManager.default.removeItem(at: marker)
            } else {
                // Keep retrying if recovery failed during startup.
                active = true
                deadline = 0
                lastHeartbeat = 0
            }
        }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in self?.enforceLimits() }
        timer.resume()
        self.timer = timer
    }

    func enable(forMinutes minutes: Int, withReply reply: @escaping (Bool, String?) -> Void) {
        queue.async {
            guard SessionPolicy.allowedMinutes.contains(minutes) else { reply(false, "Unsupported duration"); return }
            guard !self.active else { reply(false, "Already active"); return }
            guard PowerState.observedSleepDisabled() == false else {
                reply(false, "Sleep is already disabled or its state cannot be read.")
                return
            }
            if let battery = PowerState.batteryPercent(), battery <= SessionPolicy.minimumBatteryPercent {
                reply(false, "Battery is at or below 15%.")
                return
            }
            do {
                try Data("active".utf8).write(to: self.marker, options: .atomic)
            } catch {
                reply(false, "Cannot create recovery marker: \(error.localizedDescription)")
                return
            }
            let result = self.setSleepDisabled(true)
            guard result.0, PowerState.observedSleepDisabled() == true else {
                _ = self.setSleepDisabled(false)
                try? FileManager.default.removeItem(at: self.marker)
                reply(false, result.1 ?? "macOS did not confirm sleep suppression.")
                return
            }
            self.active = true
            self.lastHeartbeat = ProcessInfo.processInfo.systemUptime
            self.deadline = self.lastHeartbeat + Double(minutes * 60)
            reply(true, nil)
        }
    }

    func disable(withReply reply: @escaping (Bool, String?) -> Void) {
        queue.async {
            guard self.active || FileManager.default.fileExists(atPath: self.marker.path) else {
                reply(false, "Lid Awake does not own the current sleep setting.")
                return
            }
            let result = self.restore()
            reply(result.0, result.1)
        }
    }

    func heartbeat(withReply reply: @escaping (Bool) -> Void) {
        queue.async {
            if self.active { self.lastHeartbeat = ProcessInfo.processInfo.systemUptime }
            reply(self.active)
        }
    }

    func status(withReply reply: @escaping (Bool, Int) -> Void) {
        queue.async {
            let remaining = self.active ? max(0, Int(self.deadline - ProcessInfo.processInfo.systemUptime)) : 0
            reply(self.active, remaining)
        }
    }

    private func enforceLimits() {
        guard active else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if SessionPolicy.shouldRestore(now: now, lastHeartbeat: lastHeartbeat,
                                       deadline: deadline, batteryPercent: PowerState.batteryPercent()) {
            _ = restore()
        }
    }

    private func restore() -> (Bool, String?) {
        let result = setSleepDisabled(false)
        if result.0 {
            active = false
            deadline = 0
            try? FileManager.default.removeItem(at: marker)
        }
        return result
    }

    private func setSleepDisabled(_ disabled: Bool) -> (Bool, String?) {
        guard let result = PowerState.command("/usr/bin/pmset", ["-a", "disablesleep", disabled ? "1" : "0"]) else {
            return (false, "Could not launch pmset.")
        }
        return result.code == 0 ? (true, nil) : (false, result.output.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
