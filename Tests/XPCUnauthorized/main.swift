import Foundation

@objc protocol ProbeProtocol {
    func status(withReply reply: @escaping (Bool, Int) -> Void)
}

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: unauthorized-probe MACH_SERVICE_LABEL\n", stderr)
    exit(2)
}

let connection = NSXPCConnection(machServiceName: CommandLine.arguments[1], options: .privileged)
connection.remoteObjectInterface = NSXPCInterface(with: ProbeProtocol.self)
connection.resume()

let finished = DispatchSemaphore(value: 0)
var result = "timeout"
let proxy = connection.remoteObjectProxyWithErrorHandler { error in
    let code = (error as NSError).code
    result = code == NSXPCConnectionCodeSigningRequirementFailure
        ? "code-signing-rejected"
        : "unexpected XPC error \(code): \(error.localizedDescription)"
    finished.signal()
} as? ProbeProtocol

guard let proxy else {
    fputs("Could not create the XPC proxy.\n", stderr)
    exit(1)
}
proxy.status { _, _ in
    result = "unauthorized client received a helper reply"
    finished.signal()
}
_ = finished.wait(timeout: .now() + 10)
connection.invalidate()
guard result == "code-signing-rejected" else {
    fputs("XPC denial test failed: \(result)\n", stderr)
    exit(1)
}
print("Unsigned XPC client was rejected by the helper's signing requirement.")
