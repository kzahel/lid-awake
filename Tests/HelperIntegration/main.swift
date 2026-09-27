import Foundation
import Darwin

private let label = "com.kzahel.lidawake.helper.integration"

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

require(geteuid() == 0, "run as root in a disposable VM")
require(CommandLine.arguments.count == 2, "expected exercise, recover, or watchdog")

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
default:
    require(false, "expected exercise, recover, or watchdog")
}
