import Foundation

enum HelperIdentity {
    static let teamID = "VD7BYQ6ABM"
    static let environmentKey = "LID_AWAKE_MACH_LABEL"
    static let fallbackLabel = "com.kzahel.lidawake.helper"

    static func label(for bundleID: String) -> String { "\(bundleID).helper" }

    static func appID(for label: String) -> String {
        String(label.dropLast(".helper".count))
    }

    static func signingRequirement(for appID: String) -> String {
        "identifier \"\(appID)\" and anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\""
    }
}

@objc protocol LidAwakeHelperProtocol {
    func enable(forMinutes minutes: Int, withReply reply: @escaping (Bool, String?) -> Void)
    func start(mode: Int, minutes: Int, allowClosedLid: Bool, batteryCutoff: Int,
               withReply reply: @escaping (Bool, String?) -> Void)
    func disable(withReply reply: @escaping (Bool, String?) -> Void)
    func heartbeat(withReply reply: @escaping (Bool) -> Void)
    func status(withReply reply: @escaping (Bool, Int) -> Void)
    func health(withReply reply: @escaping (Int, Bool, Int, String?) -> Void)
    func details(withReply reply: @escaping (String) -> Void)
    func removeDiagnostics(withReply reply: @escaping (Bool, String?) -> Void)
}
