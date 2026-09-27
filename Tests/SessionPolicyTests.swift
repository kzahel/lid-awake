import XCTest

final class SessionPolicyTests: XCTestCase {
    func testSessionStopsAtDeadlineAndAfterHeartbeatLoss() {
        XCTAssertFalse(SessionPolicy.shouldRestore(now: 100, lastHeartbeat: 20, deadline: 120, batteryPercent: 80))
        XCTAssertTrue(SessionPolicy.shouldRestore(now: 120, lastHeartbeat: 120, deadline: 120, batteryPercent: 80))
        XCTAssertTrue(SessionPolicy.shouldRestore(now: 111, lastHeartbeat: 20, deadline: 200, batteryPercent: 80))
    }

    func testBatteryCutoffAndUnknownBattery() {
        XCTAssertFalse(SessionPolicy.shouldRestore(now: 10, lastHeartbeat: 10, deadline: 100, batteryPercent: 16))
        XCTAssertTrue(SessionPolicy.shouldRestore(now: 10, lastHeartbeat: 10, deadline: 100, batteryPercent: 15))
        XCTAssertFalse(SessionPolicy.shouldRestore(now: 10, lastHeartbeat: 10, deadline: 100, batteryPercent: nil))
    }

    func testIORegistryParsingDoesNotConfuseUnknownWithOff() {
        XCTAssertEqual(PowerState.sleepDisabled(from: "\"SleepDisabled\" = Yes\n"), true)
        XCTAssertEqual(PowerState.sleepDisabled(from: "\"SleepDisabled\" = No\n"), false)
        XCTAssertNil(PowerState.sleepDisabled(from: "something else = No\n"))
    }
}
