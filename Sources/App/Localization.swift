import Foundation

func tr(_ key: String) -> String {
    NSLocalizedString(key, comment: "Lid Awake user interface")
}

func trf(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: tr(key), locale: Locale.current, arguments: arguments)
}
