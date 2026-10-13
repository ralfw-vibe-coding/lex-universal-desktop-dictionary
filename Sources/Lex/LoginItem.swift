import Foundation

/// Start beim Login über einen LaunchAgent in `~/Library/LaunchAgents`.
/// (SMAppService wäre die moderne Variante, verträgt sich aber schlecht mit der
/// ad-hoc-Signatur, die sich bei jedem Build ändert.)
enum LoginItem {
    static let label = "de.ralfw.lex"
    static var plist: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/LaunchAgents/\(label).plist")
    }

    static var currentExecutable: String { Bundle.main.executablePath ?? CommandLine.arguments[0] }

    /// Das Programm, das beim Login gestartet wird – nil, wenn kein Login-Start eingerichtet ist.
    static var configuredExecutable: String? {
        guard let data = try? Data(contentsOf: plist),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let args = dict["ProgramArguments"] as? [String] else { return nil }
        return args.first
    }

    static var isEnabled: Bool { configuredExecutable != nil }

    /// Beim Einschalten zeigt der Agent auf genau diese laufende App.
    /// Beim Ausschalten wird nur die Datei entfernt – ein `launchctl bootout` würde
    /// ein per Login gestartetes Lex sofort beenden.
    static func set(_ enabled: Bool) throws {
        if enabled {
            let dict: [String: Any] = [
                "Label": label,
                "ProgramArguments": [currentExecutable, "--background"],
                "RunAtLoad": true,
                "ProcessType": "Interactive",
            ]
            try FileManager.default.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
            try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0).write(to: plist, options: .atomic)
        } else if FileManager.default.fileExists(atPath: plist.path) {
            try FileManager.default.removeItem(at: plist)
        }
    }

    static var runsFromApplications: Bool {
        Bundle.main.bundlePath.hasPrefix("/Applications/")
            || Bundle.main.bundlePath.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path + "/Applications/")
    }
}
