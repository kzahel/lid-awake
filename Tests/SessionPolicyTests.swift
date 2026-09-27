import XCTest

final class SessionPolicyTests: XCTestCase {
    func testSessionStopsAtDeadlineAndAfterHeartbeatLoss() {
        XCTAssertFalse(SessionPolicy.shouldRestore(now: 100, lastHeartbeat: 20, deadline: 120,
                                                   power: .ac, unknownPowerSince: nil, thermal: .nominal))
        XCTAssertTrue(SessionPolicy.shouldRestore(now: 120, lastHeartbeat: 120, deadline: 120,
                                                  power: .ac, unknownPowerSince: nil, thermal: .nominal))
        XCTAssertTrue(SessionPolicy.shouldRestore(now: 111, lastHeartbeat: 20, deadline: 200,
                                                  power: .ac, unknownPowerSince: nil, thermal: .nominal))
    }

    func testBatteryCutoffThermalAndUnknownPowerGrace() {
        XCTAssertFalse(SessionPolicy.shouldRestore(now: 10, lastHeartbeat: 10, deadline: 100,
                                                   power: .battery(16), unknownPowerSince: nil, thermal: .nominal))
        XCTAssertTrue(SessionPolicy.shouldRestore(now: 10, lastHeartbeat: 10, deadline: 100,
                                                  power: .battery(15), unknownPowerSince: nil, thermal: .nominal))
        XCTAssertTrue(SessionPolicy.shouldRestore(now: 10, lastHeartbeat: 10, deadline: 100,
                                                  power: .ac, unknownPowerSince: nil, thermal: .serious))
        XCTAssertFalse(SessionPolicy.shouldRestore(now: 29, lastHeartbeat: 29, deadline: 100,
                                                   power: .unknown, unknownPowerSince: 0, thermal: .nominal))
        XCTAssertTrue(SessionPolicy.shouldRestore(now: 30, lastHeartbeat: 30, deadline: 100,
                                                  power: .unknown, unknownPowerSince: 0, thermal: .nominal))
    }

    func testIORegistryParsingDoesNotConfuseUnknownWithOff() {
        XCTAssertEqual(PowerState.sleepDisabled(from: "\"SleepDisabled\" = Yes\n"), true)
        XCTAssertEqual(PowerState.sleepDisabled(from: "\"SleepDisabled\" = No\n"), false)
        XCTAssertNil(PowerState.sleepDisabled(from: "something else = No\n"))
    }

    func testPowerSourceParsingSeparatesACBatteryAndUnknown() {
        XCTAssertEqual(PowerState.powerSource(from: "Now drawing from 'AC Power'\n -InternalBattery-0 87%"), .ac)
        XCTAssertEqual(PowerState.powerSource(from: "Now drawing from 'Battery Power'\n -InternalBattery-0 15%"), .battery(15))
        XCTAssertEqual(PowerState.powerSource(from: "Now drawing from 'Battery Power'\n unknown"), .unknown)
        XCTAssertEqual(PowerState.powerSource(from: "Now drawing from 'Battery Power'\n 120%"), .unknown)
        XCTAssertEqual(PowerState.powerSource(from: "error"), .unknown)
    }
}
