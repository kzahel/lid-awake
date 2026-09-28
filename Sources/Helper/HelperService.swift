import Foundation
import Darwin
import os

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
    private let log = Logger(subsystem: "com.kzahel.lidawake", category: "helper")
    private let marker: URL
    private let lastStopFile: URL
    private let power: PowerController
    private var configuration: SessionConfiguration?
    private var activity: NSObjectProtocol?
    private var active = false
    private var deadline: TimeInterval?
    private var lastHeartbeat: TimeInterval = 0
    private var unknownPowerSince: TimeInterval?
    private var recoveryIssue: String?
    private var lastStopReason: StopReason?
    private var lastPowerKind: String?
    private var lastThermalState: ProcessInfo.ThermalState?
    private var sleepReadUnavailable = false
    private var lastRequest = ProcessInfo.processInfo.systemUptime
    private var timer: DispatchSourceTimer?

    init(label: String, markerDirectory: URL? = nil, power: PowerController = SystemPowerController()) {
        precondition(geteuid() == 0, "Lid Awake helper must run as root")
        self.power = power
        let dir = markerDirectory ?? URL(fileURLWithPath: "/Library/Application Support/LidAwake", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        marker = dir.appendingPathComponent(label + ".session")
        lastStopFile = dir.appendingPathComponent(label + ".last-stop")
        if let raw = try? String(contentsOf: lastStopFile, encoding: .utf8) {
            lastStopReason = StopReason(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        super.init()
        if FileManager.default.fileExists(atPath: marker.path) {
            active = true
            configuration = SessionConfiguration(mode: .untilStopped, minutes: 0,
                                                 allowClosedLid: true, batteryCutoff: 15)
            log.error("Found interrupted closed-lid session; restoring normal sleep")
            _ = restore(reason: .helperRestart)
        }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5)
        timer.setEventHandler { [weak self] in self?.enforceLimits() }
        timer.resume()
        self.timer = timer
    }

    func enable(forMinutes minutes: Int, withReply reply: @escaping (Bool, String?) -> Void) {
        start(mode: SessionMode.timed.rawValue, minutes: minutes, allowClosedLid: true,
              batteryCutoff: 15, withReply: reply)
    }

    func start(mode: Int, minutes: Int, allowClosedLid: Bool, batteryCutoff: Int,
               withReply reply: @escaping (Bool, String?) -> Void) {
        queue.async {
            self.lastRequest = ProcessInfo.processInfo.systemUptime
            guard let mode = SessionMode(rawValue: mode) else { reply(false, "Unsupported session mode."); return }
            let requested = SessionConfiguration(mode: mode, minutes: minutes,
                                                 allowClosedLid: allowClosedLid,
                                                 batteryCutoff: batteryCutoff)
            guard SessionPolicy.valid(requested) else { reply(false, "Unsupported session settings."); return }
            guard !self.active && !FileManager.default.fileExists(atPath: self.marker.path) else {
                reply(false, "A session or recovery is still in progress.")
                return
            }
            guard self.power.observedSleepDisabled() == false else {
                reply(false, "Sleep is already disabled or its state cannot be read.")
                return
            }
            let source = self.power.powerSource()
            switch source {
            case .unknown:
                reply(false, "Cannot determine whether the Mac is on battery power.")
                return
            case .battery(let percent):
                if mode == .untilUnplugged {
                    reply(false, "Connect a charger before starting an Until Unplugged session.")
                    return
                }
                if batteryCutoff > 0 && percent <= batteryCutoff {
                    reply(false, "Battery is at or below the selected cutoff.")
                    return
                }
            case .ac:
                break
            }
            let thermal = self.power.thermalState()
            guard thermal != .serious && thermal != .critical else {
                reply(false, "The Mac is too warm to start a session.")
                return
            }
            if allowClosedLid {
                do {
                    try Data("active".utf8).write(to: self.marker, options: .atomic)
                } catch {
                    reply(false, "Cannot create recovery marker: \(error.localizedDescription)")
                    return
                }
                let result = self.power.setSleepDisabled(true)
                guard result.0, self.power.observedSleepDisabled() == true else {
                    self.active = true
                    self.configuration = requested
                    let restored = self.restore(reason: .restorationFailed)
                    let error = result.1 ?? "macOS did not confirm sleep suppression."
                    reply(false, restored.0 ? error : "\(error) \(restored.1 ?? "Normal sleep could not be verified.")")
                    return
                }
            } else {
                self.activity = ProcessInfo.processInfo.beginActivity(
                    options: [.idleSystemSleepDisabled, .suddenTerminationDisabled],
                    reason: "Lid Awake open-lid session")
            }
            self.active = true
            self.configuration = requested
            self.recoveryIssue = nil
            self.unknownPowerSince = nil
            self.lastPowerKind = nil
            self.lastThermalState = nil
            self.sleepReadUnavailable = false
            self.lastHeartbeat = ProcessInfo.processInfo.systemUptime
            self.deadline = mode == .timed ? self.lastHeartbeat + Double(minutes * 60) : nil
            self.log.notice("Started session mode=\(mode.rawValue) closedLid=\(allowClosedLid) cutoff=\(batteryCutoff)")
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
            let result = self.restore(reason: .manual)
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
            reply(self.active, self.remainingSeconds())
        }
    }

    func health(withReply reply: @escaping (Int, Bool, Int, String?) -> Void) {
        queue.async {
            self.lastRequest = ProcessInfo.processInfo.systemUptime
            let build = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
            reply(build, self.active, self.remainingSeconds(), self.recoveryIssue)
        }
    }

    func details(withReply reply: @escaping (String) -> Void) {
        queue.async {
            self.lastRequest = ProcessInfo.processInfo.systemUptime
            let details = SessionDetails(active: self.active, configuration: self.configuration,
                                         remaining: self.remainingSeconds(),
                                         lastStopReason: self.lastStopReason,
                                         recoveryIssue: self.recoveryIssue)
            let data = (try? JSONEncoder().encode(details)) ?? Data("{}".utf8)
            reply(String(decoding: data, as: UTF8.self))
        }
    }

    func removeDiagnostics(withReply reply: @escaping (Bool, String?) -> Void) {
        queue.async {
            guard !self.active, !FileManager.default.fileExists(atPath: self.marker.path),
                  self.power.observedSleepDisabled() == false else {
                reply(false, "Restore normal sleep before removing diagnostics.")
                return
            }
            do {
                if FileManager.default.fileExists(atPath: self.lastStopFile.path) {
                    try FileManager.default.removeItem(at: self.lastStopFile)
                }
                self.lastStopReason = nil
                reply(true, nil)
            } catch { reply(false, error.localizedDescription) }
        }
    }

    private func remainingSeconds() -> Int {
        guard active, recoveryIssue == nil, let deadline else { return 0 }
        return max(0, Int(deadline - ProcessInfo.processInfo.systemUptime))
    }

    private func enforceLimits() {
        guard active else {
            if FileManager.default.fileExists(atPath: marker.path) {
                active = true
                configuration = SessionConfiguration(mode: .untilStopped, minutes: 0,
                                                     allowClosedLid: true, batteryCutoff: 15)
                _ = restore(reason: .helperRestart)
            } else if ProcessInfo.processInfo.systemUptime - lastRequest >= 30 {
                exit(EXIT_SUCCESS)
            }
            return
        }
        guard let configuration else { _ = restore(reason: .restorationFailed); return }
        if recoveryIssue != nil {
            _ = restore(reason: .restorationFailed)
            return
        }
        if configuration.allowClosedLid {
            switch power.observedSleepDisabled() {
            case .some(false):
                _ = restore(reason: .externalChange)
                return
            case .none:
                if !sleepReadUnavailable { log.error("SleepDisabled readback unavailable") }
                sleepReadUnavailable = true
            case .some(true):
                if sleepReadUnavailable { log.notice("SleepDisabled readback recovered") }
                sleepReadUnavailable = false
            }
        }
        let now = ProcessInfo.processInfo.systemUptime
        let source = power.powerSource()
        let powerKind: String
        switch source {
        case .ac: powerKind = "ac"
        case .battery: powerKind = "battery"
        case .unknown: powerKind = "unknown"
        }
        if lastPowerKind != powerKind {
            log.notice("Power source=\(powerKind, privacy: .public)")
            lastPowerKind = powerKind
        }
        let thermal = power.thermalState()
        if lastThermalState != thermal {
            log.notice("Thermal state=\(String(describing: thermal), privacy: .public)")
            lastThermalState = thermal
        }
        if source == .unknown {
            if unknownPowerSince == nil { unknownPowerSince = now }
        } else {
            unknownPowerSince = nil
        }
        if let reason = SessionPolicy.stopReason(now: now, lastHeartbeat: lastHeartbeat,
                                                 deadline: deadline, power: source,
                                                 unknownPowerSince: unknownPowerSince,
                                                 thermal: thermal,
                                                 configuration: configuration) {
            _ = restore(reason: reason)
        }
    }

    private func restore(reason: StopReason) -> (Bool, String?) {
        let shouldRestoreSystem = configuration?.allowClosedLid == true
            || FileManager.default.fileExists(atPath: marker.path)
        if shouldRestoreSystem {
            var commandResult: (Bool, String?) = (true, nil)
            if power.observedSleepDisabled() != false {
                commandResult = power.setSleepDisabled(false)
            }
            guard power.observedSleepDisabled() == false else {
                recoveryIssue = commandResult.1 ?? "Normal sleep could not be verified; the helper will retry."
                log.error("Sleep restoration could not be verified")
                return (false, recoveryIssue)
            }
            do {
                if FileManager.default.fileExists(atPath: marker.path) {
                    try FileManager.default.removeItem(at: marker)
                }
            } catch {
                recoveryIssue = "Normal sleep returned, but the recovery marker could not be cleared: \(error.localizedDescription)"
                log.error("Could not clear recovery marker")
                return (false, recoveryIssue)
            }
        }
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        active = false
        configuration = nil
        deadline = nil
        unknownPowerSince = nil
        recoveryIssue = nil
        lastStopReason = reason
        try? reason.rawValue.write(to: lastStopFile, atomically: true, encoding: .utf8)
        log.notice("Stopped session reason=\(reason.rawValue, privacy: .public)")
        return (true, nil)
    }
}
