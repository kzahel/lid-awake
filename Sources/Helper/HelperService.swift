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
    private let power: PowerController
    private var active = false
    private var deadline: TimeInterval = 0
    private var lastHeartbeat: TimeInterval = 0
    private var unknownPowerSince: TimeInterval?
    private var recoveryIssue: String?
    private var lastRequest = ProcessInfo.processInfo.systemUptime
    private var timer: DispatchSourceTimer?

    init(label: String, markerDirectory: URL? = nil, power: PowerController = SystemPowerController()) {
        precondition(geteuid() == 0, "Lid Awake helper must run as root")
        self.power = power
        let dir = markerDirectory ?? URL(fileURLWithPath: "/Library/Application Support/LidAwake", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        marker = dir.appendingPathComponent(label + ".session")
        super.init()
        if FileManager.default.fileExists(atPath: marker.path) {
            active = true
            _ = restore()
        }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in self?.enforceLimits() }
        timer.resume()
        self.timer = timer
    }

    func enable(forMinutes minutes: Int, withReply reply: @escaping (Bool, String?) -> Void) {
        queue.async {
            self.lastRequest = ProcessInfo.processInfo.systemUptime
            guard SessionPolicy.allowedMinutes.contains(minutes) else { reply(false, "Unsupported duration"); return }
            guard !self.active && !FileManager.default.fileExists(atPath: self.marker.path) else {
                reply(false, "A session or recovery is still in progress.")
                return
            }
            guard self.power.observedSleepDisabled() == false else {
                reply(false, "Sleep is already disabled or its state cannot be read.")
                return
            }
            switch self.power.powerSource() {
            case .battery(let battery) where battery <= SessionPolicy.minimumBatteryPercent:
                reply(false, "Battery is at or below 15%.")
                return
            case .unknown:
                reply(false, "Cannot determine whether the Mac is on battery power.")
                return
            default:
                break
            }
            let thermal = self.power.thermalState()
            if thermal == .serious || thermal == .critical {
                reply(false, "The Mac is too warm to start a closed-lid session.")
                return
            }
            do {
                try Data("active".utf8).write(to: self.marker, options: .atomic)
            } catch {
                reply(false, "Cannot create recovery marker: \(error.localizedDescription)")
                return
            }
            let result = self.power.setSleepDisabled(true)
            guard result.0, self.power.observedSleepDisabled() == true else {
                self.active = true
                let restored = self.restore()
                let error = result.1 ?? "macOS did not confirm sleep suppression."
                reply(false, restored.0 ? error : "\(error) \(restored.1 ?? "Normal sleep could not be verified.")")
                return
            }
            self.active = true
            self.recoveryIssue = nil
            self.unknownPowerSince = nil
            self.lastHeartbeat = ProcessInfo.processInfo.systemUptime
            self.deadline = self.lastHeartbeat + Double(minutes * 60)
            reply(true, nil)
        }
    }

    func disable(withReply reply: @escaping (Bool, String?) -> Void) {
        queue.async {
            self.lastRequest = ProcessInfo.processInfo.systemUptime
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
            self.lastRequest = ProcessInfo.processInfo.systemUptime
            if self.active && self.recoveryIssue == nil { self.lastHeartbeat = ProcessInfo.processInfo.systemUptime }
            reply(self.active)
        }
    }

    func status(withReply reply: @escaping (Bool, Int) -> Void) {
        queue.async {
            self.lastRequest = ProcessInfo.processInfo.systemUptime
            let remaining = self.remainingSeconds()
            reply(self.active, remaining)
        }
    }

    func health(withReply reply: @escaping (Int, Bool, Int, String?) -> Void) {
        queue.async {
            self.lastRequest = ProcessInfo.processInfo.systemUptime
            let build = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
            reply(build, self.active, self.remainingSeconds(), self.recoveryIssue)
        }
    }

    private func remainingSeconds() -> Int {
        active && recoveryIssue == nil ? max(0, Int(deadline - ProcessInfo.processInfo.systemUptime)) : 0
    }

    private func enforceLimits() {
        guard active else {
            if FileManager.default.fileExists(atPath: marker.path) {
                active = true
                _ = restore()
            } else if ProcessInfo.processInfo.systemUptime - lastRequest >= 30 {
                exit(EXIT_SUCCESS)
            }
            return
        }
        if recoveryIssue != nil || power.observedSleepDisabled() == false {
            _ = restore()
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let source = power.powerSource()
        if source == .unknown {
            if unknownPowerSince == nil { unknownPowerSince = now }
        } else {
            unknownPowerSince = nil
        }
        if SessionPolicy.shouldRestore(now: now, lastHeartbeat: lastHeartbeat,
                                       deadline: deadline, power: source,
                                       unknownPowerSince: unknownPowerSince,
                                       thermal: power.thermalState()) {
            _ = restore()
        }
    }

    private func restore() -> (Bool, String?) {
        var commandResult: (Bool, String?) = (true, nil)
        if power.observedSleepDisabled() != false {
            commandResult = power.setSleepDisabled(false)
        }
        guard power.observedSleepDisabled() == false else {
            recoveryIssue = commandResult.1 ?? "Normal sleep could not be verified; the helper will retry."
            return (false, recoveryIssue)
        }
        do {
            if FileManager.default.fileExists(atPath: marker.path) {
                try FileManager.default.removeItem(at: marker)
            }
        } catch {
            recoveryIssue = "Normal sleep returned, but the recovery marker could not be cleared: \(error.localizedDescription)"
            return (false, recoveryIssue)
        }
        active = false
        deadline = 0
        unknownPowerSince = nil
        recoveryIssue = nil
        return (true, nil)
    }
}
