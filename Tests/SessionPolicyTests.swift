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

    func testSessionModesAndSafetyRules() {
        let indefinite = SessionConfiguration(mode: .untilStopped, minutes: 0,
                                              allowClosedLid: true, batteryCutoff: 15)
        XCTAssertTrue(SessionPolicy.valid(indefinite))
        XCTAssertNil(SessionPolicy.stopReason(now: 100_000, lastHeartbeat: 99_995,
                                              deadline: nil, power: .ac, unknownPowerSince: nil,
                                              thermal: .nominal, configuration: indefinite))
        XCTAssertEqual(SessionPolicy.stopReason(now: 100, lastHeartbeat: 100,
                                                 deadline: nil, power: .battery(15),
                                                 unknownPowerSince: nil, thermal: .nominal,
                                                 configuration: indefinite), .lowBattery)

        let noCutoff = SessionConfiguration(mode: .untilStopped, minutes: 0,
                                           allowClosedLid: true, batteryCutoff: 0)
        XCTAssertNil(SessionPolicy.stopReason(now: 100, lastHeartbeat: 100,
                                              deadline: nil, power: .battery(1),
                                              unknownPowerSince: nil, thermal: .nominal,
                                              configuration: noCutoff))
        XCTAssertEqual(SessionPolicy.stopReason(now: 100, lastHeartbeat: 100,
                                                 deadline: nil, power: .battery(80),
                                                 unknownPowerSince: nil, thermal: .serious,
                                                 configuration: noCutoff), .highThermal)

        let unplugged = SessionConfiguration(mode: .untilUnplugged, minutes: 0,
                                             allowClosedLid: false, batteryCutoff: 0)
        XCTAssertEqual(SessionPolicy.stopReason(now: 100, lastHeartbeat: 100,
                                                 deadline: nil, power: .battery(99),
                                                 unknownPowerSince: nil, thermal: .nominal,
                                                 configuration: unplugged), .unplugged)
        XCTAssertNil(SessionPolicy.stopReason(now: 100, lastHeartbeat: 100,
                                              deadline: nil, power: .ac,
                                              unknownPowerSince: nil, thermal: .nominal,
                                              configuration: unplugged))
    }

    func testSettingsValidationAndDetailsRoundTrip() throws {
        XCTAssertFalse(SessionPolicy.valid(SessionConfiguration(mode: .timed, minutes: 0,
                                                                 allowClosedLid: true, batteryCutoff: 15)))
        XCTAssertFalse(SessionPolicy.valid(SessionConfiguration(mode: .untilStopped, minutes: 60,
                                                                 allowClosedLid: true, batteryCutoff: 15)))
        XCTAssertFalse(SessionPolicy.valid(SessionConfiguration(mode: .timed, minutes: 60,
                                                                 allowClosedLid: true, batteryCutoff: 100)))
        XCTAssertTrue(SessionPolicy.valid(SessionConfiguration(mode: .timed, minutes: 180,
                                                                allowClosedLid: false, batteryCutoff: 30)))
        let details = SessionDetails(active: true,
                                     configuration: SessionConfiguration(mode: .untilUnplugged,
                                                                         minutes: 0,
                                                                         allowClosedLid: true,
                                                                         batteryCutoff: 15),
                                     remaining: 0, lastStopReason: .deadline,
                                     recoveryIssue: nil)
        let decoded = try JSONDecoder().decode(SessionDetails.self, from: JSONEncoder().encode(details))
        XCTAssertEqual(decoded.configuration?.mode, .untilUnplugged)
        XCTAssertEqual(decoded.lastStopReason, .deadline)
    }
}
