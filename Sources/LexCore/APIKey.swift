import Foundation
import Security

/// Der OpenRouter-Key liegt im Schlüsselbund. `OPENROUTER_API_KEY` in der Umgebung hat Vorrang (für lex-eval).
public enum APIKey {
    static let service = "Lex"
    static let account = "openrouter"

    public static func load() -> String? {
        if let env = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !env.isEmpty { return env }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public static func save(_ key: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(key.utf8)
        add[kSecAttrLabel as String] = "Lex – OpenRouter API-Key"
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }
}
