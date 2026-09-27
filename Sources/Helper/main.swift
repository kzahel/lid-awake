import Foundation

let label = ProcessInfo.processInfo.environment[HelperIdentity.environmentKey] ?? HelperIdentity.fallbackLabel
let delegate = HelperListener(label: label)
let listener = NSXPCListener(machServiceName: label)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
