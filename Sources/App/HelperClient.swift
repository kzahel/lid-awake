import AppKit
import Foundation
import ServiceManagement

final class HelperClient {
    private var connection: NSXPCConnection?

    private var label: String {
        HelperIdentity.label(for: Bundle.main.bundleIdentifier ?? "com.kzahel.lidawake")
    }

    private var service: SMAppService { SMAppService.daemon(plistName: label + ".plist") }

    var status: SMAppService.Status { service.status }

    func register() throws { try service.register() }

    func openApprovalSettings() { SMAppService.openSystemSettingsLoginItems() }

    private func proxy(onError: @escaping (String) -> Void) -> LidAwakeHelperProtocol? {
        if connection == nil {
            let newConnection = NSXPCConnection(machServiceName: label, options: .privileged)
            newConnection.remoteObjectInterface = NSXPCInterface(with: LidAwakeHelperProtocol.self)
            newConnection.invalidationHandler = { [weak self] in self?.connection = nil }
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
