import Foundation

enum PowerState {
    static func sleepDisabled(from output: String) -> Bool? {
        for line in output.split(separator: "\n") where line.contains("\"SleepDisabled\"") {
            if line.contains("= Yes") { return true }
            if line.contains("= No") { return false }
        }
        return nil
    }

    static func observedSleepDisabled() -> Bool? {
        guard let result = command("/usr/sbin/ioreg", ["-r", "-c", "IOPMrootDomain", "-d", "1", "-l"]), result.code == 0 else { return nil }
        return sleepDisabled(from: result.output)
    }

    static func batteryPercent() -> Int? {
        guard let result = command("/usr/bin/pmset", ["-g", "batt"]), result.code == 0 else { return nil }
        guard result.output.contains("Battery Power") else { return nil }
        let pattern = try? NSRegularExpression(pattern: "([0-9]{1,3})%")
        let range = NSRange(result.output.startIndex..., in: result.output)
        guard let match = pattern?.firstMatch(in: result.output, range: range),
              let numberRange = Range(match.range(at: 1), in: result.output) else { return nil }
        return Int(result.output[numberRange])
    }

    static func command(_ executable: String, _ arguments: [String]) -> (code: Int32, output: String)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}
