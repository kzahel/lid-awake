import Foundation
import Darwin

private let label = "com.kzahel.lidawake.helper.integration"

private final class FakePower: PowerController {
    private let queue = DispatchQueue(label: "com.kzahel.lidawake.fakepower")
    private var state: Bool? = false
    private var failing = false
    private var source: PowerSource = .ac
    var disabled: Bool? {
        get { queue.sync { state } }
        set { queue.sync { state = newValue } }
    }
    var failRestoration: Bool {
        get { queue.sync { failing } }
        set { queue.sync { failing = newValue } }
    }
    var power: PowerSource {
        get { queue.sync { source } }
        set { queue.sync { source = newValue } }
    }
    func observedSleepDisabled() -> Bool? { disabled }
    func powerSource() -> PowerSource { power }
    func thermalState() -> ProcessInfo.ThermalState { .nominal }
    func setSleepDisabled(_ value: Bool) -> (Bool, String?) {
        queue.sync {
            if !value && failing { return (true, nil) }
            state = value
            return (true, nil)
        }
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Helper integration failure: \(message)\n", stderr)
        exit(1)
    }
}

private func enable(_ service: HelperService) {
    let finished = DispatchSemaphore(value: 0)
    var result: (Bool, String?) = (false, "No reply")
    service.enable(forMinutes: 30) { ok, error in
        result = (ok, error)
        finished.signal()
    }
    require(finished.wait(timeout: .now() + 15) == .success, "enable timed out")
    require(result.0, "enable failed: \(result.1 ?? "unknown")")
    require(PowerState.observedSleepDisabled() == true, "sleep was not disabled")
}

private func disable(_ service: HelperService) {
    let finished = DispatchSemaphore(value: 0)
    var result: (Bool, String?) = (false, "No reply")
    service.disable { ok, error in
        result = (ok, error)
        finished.signal()
    }
    require(finished.wait(timeout: .now() + 15) == .success, "disable timed out")
    require(result.0, "disable failed: \(result.1 ?? "unknown")")
    require(PowerState.observedSleepDisabled() == false, "sleep was not restored")
}

private func testFailedRestoreRetries() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let fake = FakePower()
    let service = HelperService(label: label, markerDirectory: dir, power: fake)
    let marker = dir.appendingPathComponent(label + ".session")
    let enabled = DispatchSemaphore(value: 0)
    service.enable(forMinutes: 30) { ok, error in
        require(ok, "fake enable failed: \(error ?? "unknown")")
        enabled.signal()
    }
    require(enabled.wait(timeout: .now() + 15) == .success, "fake enable timed out")
    require(fake.disabled == true && FileManager.default.fileExists(atPath: marker.path), "fake session did not start")

    fake.failRestoration = true
    let disabled = DispatchSemaphore(value: 0)
    service.disable { ok, _ in
        require(!ok, "a successful pmset exit without observed restoration must fail")
        disabled.signal()
    }
    require(disabled.wait(timeout: .now() + 15) == .success, "fake disable timed out")
    require(fake.disabled == true && FileManager.default.fileExists(atPath: marker.path),
            "failed restoration lost the recovery marker")

    fake.failRestoration = false
    var restored = false
    for _ in 0..<4 {
        Thread.sleep(forTimeInterval: 2)
        if fake.disabled == false && !FileManager.default.fileExists(atPath: marker.path) {
            restored = true
            break
        }
    }
    withExtendedLifetime(service) { require(restored, "helper did not retry and verify restoration") }
    print("Helper failed-readback retry passed")
}

private func testNewSessionModes() {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let fake = FakePower()
    let service = HelperService(label: label, markerDirectory: dir, power: fake)
    let closedStart = DispatchSemaphore(value: 0)
    service.start(mode: SessionMode.untilUnplugged.rawValue, minutes: 0,
                  allowClosedLid: true, batteryCutoff: 0) { ok, error in
        require(ok, "until-unplugged start failed: \(error ?? "unknown")")
        closedStart.signal()
    }
    require(closedStart.wait(timeout: .now() + 15) == .success, "until-unplugged start timed out")
    require(fake.disabled == true, "closed-lid session did not set SleepDisabled")
    fake.power = .battery(99)
    Thread.sleep(forTimeInterval: 6)
    require(fake.disabled == false, "unplugging did not restore normal sleep")

    let openStart = DispatchSemaphore(value: 0)
    service.start(mode: SessionMode.untilStopped.rawValue, minutes: 0,
                  allowClosedLid: false, batteryCutoff: 0) { ok, error in
        require(ok, "open-lid start failed: \(error ?? "unknown")")
        openStart.signal()
    }
    require(openStart.wait(timeout: .now() + 15) == .success, "open-lid start timed out")
    require(fake.disabled == false, "open-lid session changed global SleepDisabled")
    let details = DispatchSemaphore(value: 0)
    service.details { text in
        let state = try? JSONDecoder().decode(SessionDetails.self, from: Data(text.utf8))
        require(state?.active == true && state?.configuration?.mode == .untilStopped,
                "open-lid session details are wrong")
        details.signal()
    }
    require(details.wait(timeout: .now() + 15) == .success, "session details timed out")
    disable(service)
    print("Helper unplugged and open-lid modes passed")
}

require(geteuid() == 0, "run as root in a disposable VM")
require(CommandLine.arguments.count == 2, "expected exercise, recover, watchdog, retry, or modes")

switch CommandLine.arguments[1] {
case "exercise":
    require(PowerState.observedSleepDisabled() == false, "normal sleep must be enabled before testing")
    let service = HelperService(label: label)
    enable(service)
    disable(service)
    enable(service)
    print("Helper on/off passed; recovery marker left for a fresh process")
case "recover":
    require(PowerState.observedSleepDisabled() == true, "expected the previous process to leave sleep disabled")
    let service = HelperService(label: label)
    withExtendedLifetime(service) {
        require(PowerState.observedSleepDisabled() == false, "restart did not restore normal sleep")
    }
    print("Helper restart recovery passed")
case "watchdog":
    require(PowerState.observedSleepDisabled() == false, "normal sleep must be enabled before watchdog testing")
    let service = HelperService(label: label)
    enable(service)
    var restored = false
    for _ in 0..<12 {
        Thread.sleep(forTimeInterval: 10)
        if PowerState.observedSleepDisabled() == false {
            restored = true
            break
        }
    }
    withExtendedLifetime(service) {
        require(restored, "watchdog did not restore normal sleep within 120 seconds")
    }
    print("Helper no-heartbeat watchdog passed")
case "retry":
    testFailedRestoreRetries()
case "modes":
    testNewSessionModes()
default:
    require(false, "expected exercise, recover, watchdog, retry, or modes")
}
