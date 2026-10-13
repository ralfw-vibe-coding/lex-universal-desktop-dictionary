import Foundation
import Security

/// Der OpenRouter-Key liegt in `~/.config/lex/openrouter-key` (nur für den Nutzer lesbar).
/// Bewusst nicht im Schlüsselbund: Lex ist ad-hoc signiert, jeder Neubau hätte eine neue
/// Signatur und der Schlüsselbund würde jedes Mal nach dem Passwort fragen.
/// `OPENROUTER_API_KEY` in der Umgebung hat Vorrang.
public enum APIKey {
    static var file: URL { LexConfig.directory.appending(path: "openrouter-key") }
    nonisolated(unsafe) static var cached: String?

    public static func load() -> String? {
        if let env = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !env.isEmpty { return env }
        if let cached { return cached }
        if let text = try? String(contentsOf: file, encoding: .utf8) {
            let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { cached = key; return key }
        }
        if let key = migrateFromKeychain() { return key }
        return nil
    }

    @discardableResult
    public static func save(_ key: String) -> Bool {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try FileManager.default.createDirectory(at: LexConfig.directory, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: file.path, contents: Data(key.utf8),
                                           attributes: [.posixPermissions: 0o600])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            cached = key
            return true
        } catch {
            return false
        }
    }

    /// Frühere Versionen speicherten den Key im Schlüsselbund – einmalig umziehen.
    static func migrateFromKeychain() -> String? {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Lex",
            kSecAttrAccount as String: "openrouter",
        ]
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let key = String(data: data, encoding: .utf8), !key.isEmpty else { return nil }
        guard save(key) else { return key }
        SecItemDelete(base as CFDictionary)
        return key
    }
}
