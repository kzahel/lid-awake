import AppKit
import Foundation
import ServiceManagement

struct HelperHealth {
    let build: Int
    let active: Bool
    let remaining: Int
    let recoveryIssue: String?
}

final class HelperClient {
    private var connection: NSXPCConnection?

    private var label: String {
        HelperIdentity.label(for: Bundle.main.bundleIdentifier ?? "com.kzahel.lidawake")
    }

    private var service: SMAppService { SMAppService.daemon(plistName: label + ".plist") }

    var status: SMAppService.Status { service.status }

    func register() throws { try service.register() }

    func unregister(completion: @escaping (String?) -> Void) {
        connection?.invalidate()
        connection = nil
        service.unregister { error in
            DispatchQueue.main.async { completion(error?.localizedDescription) }
        }
    }

    func openApprovalSettings() { SMAppService.openSystemSettingsLoginItems() }

    func repair(completion: @escaping (String?) -> Void) {
        connection?.invalidate()
        connection = nil
        let registeredService = service
        registeredService.unregister { error in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let error { completion(error.localizedDescription); return }
                do {
                    try registeredService.register()
                    completion(nil)
                } catch {
                    completion(error.localizedDescription)
                }
            }
        }
    }

    private func proxy(onError: @escaping (String) -> Void) -> LidAwakeHelperProtocol? {
        if connection == nil {
            let newConnection = NSXPCConnection(machServiceName: label, options: .privileged)
            newConnection.remoteObjectInterface = NSXPCInterface(with: LidAwakeHelperProtocol.self)
            let clearConnection = { [weak self, weak newConnection] in
                DispatchQueue.main.async {
                    guard let self, let newConnection, self.connection === newConnection else { return }
                    self.connection = nil
                }
            }
            newConnection.interruptionHandler = clearConnection
            newConnection.invalidationHandler = clearConnection
            newConnection.resume()
            connection = newConnection
        }
        return connection?.remoteObjectProxyWithErrorHandler { error in
            DispatchQueue.main.async { onError(error.localizedDescription) }
        } as? LidAwakeHelperProtocol
    }

    func enable(minutes: Int, completion: @escaping (Bool, String?) -> Void) {
        call(completion) { proxy, finish in
            proxy.enable(forMinutes: minutes) { ok, error in finish(ok, error) }
        }
    }

    func start(_ configuration: SessionConfiguration, completion: @escaping (Bool, String?) -> Void) {
        call(completion) { proxy, finish in
            proxy.start(mode: configuration.mode.rawValue, minutes: configuration.minutes,
                        allowClosedLid: configuration.allowClosedLid,
                        batteryCutoff: configuration.batteryCutoff) { ok, error in finish(ok, error) }
        }
    }

    func disable(completion: @escaping (Bool, String?) -> Void) {
        call(completion) { proxy, finish in proxy.disable { ok, error in finish(ok, error) } }
    }

    func heartbeat() {
        proxy(onError: { _ in })?.heartbeat { _ in }
    }

    func getStatus(completion: @escaping (Bool?, Int) -> Void) {
        var finished = false
        let finish: (Bool?, Int) -> Void = { active, remaining in
            DispatchQueue.main.async {
                guard !finished else { return }
                finished = true
                completion(active, remaining)
            }
        }
        guard let remote = proxy(onError: { _ in finish(nil, 0) }) else { finish(nil, 0); return }
        remote.status { active, remaining in finish(active, remaining) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { finish(nil, 0) }
    }

    func getHealth(completion: @escaping (HelperHealth?, String?) -> Void) {
        var finished = false
        let finish: (HelperHealth?, String?) -> Void = { health, error in
            DispatchQueue.main.async {
                guard !finished else { return }
                finished = true
                completion(health, error)
            }
        }
        guard let remote = proxy(onError: { finish(nil, $0) }) else {
            finish(nil, "Cannot connect to the helper.")
            return
        }
        remote.health { build, active, remaining, recoveryIssue in
            finish(HelperHealth(build: build, active: active, remaining: remaining,
                                recoveryIssue: recoveryIssue), nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            finish(nil, "The helper did not answer its health check.")
        }
    }

    func getDetails(completion: @escaping (SessionDetails?) -> Void) {
        var finished = false
        let finish: (SessionDetails?) -> Void = { details in
            DispatchQueue.main.async {
                guard !finished else { return }
                finished = true
                completion(details)
            }
        }
        guard let remote = proxy(onError: { _ in finish(nil) }) else { finish(nil); return }
        remote.details { text in
            let details = try? JSONDecoder().decode(SessionDetails.self, from: Data(text.utf8))
            finish(details)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { finish(nil) }
    }

    func removeDiagnostics(completion: @escaping (Bool, String?) -> Void) {
        call(completion) { proxy, finish in
            proxy.removeDiagnostics { ok, error in finish(ok, error) }
        }
    }

    private func call(_ completion: @escaping (Bool, String?) -> Void,
                      _ operation: (LidAwakeHelperProtocol, @escaping (Bool, String?) -> Void) -> Void) {
        var finished = false
        let finish: (Bool, String?) -> Void = { ok, error in
            DispatchQueue.main.async {
                guard !finished else { return }
                finished = true
                completion(ok, error)
            }
        }
        guard let remote = proxy(onError: { finish(false, $0) }) else {
            finish(false, "Cannot connect to the helper.")
            return
        }
        operation(remote, finish)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { finish(false, "The helper did not respond.") }
    }
}
