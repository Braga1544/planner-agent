import Foundation
import Security

struct CredentialStore {
    var service: String = "de.planer.app"
    var defaults: UserDefaults = .standard

    private enum Key {
        static let serverURL = "serverURL"
        static let deviceToken = "deviceToken"
        static let accessClientId = "accessClientId"
        static let accessClientSecret = "accessClientSecret"
    }

    func loadConfig() -> ServerConfig? {
        guard let urlString = defaults.string(forKey: Key.serverURL),
              let url = URL(string: urlString),
              let token = read(Key.deviceToken) else { return nil }
        return ServerConfig(
            baseURL: url,
            deviceToken: token,
            accessClientId: read(Key.accessClientId) ?? "",
            accessClientSecret: read(Key.accessClientSecret) ?? ""
        )
    }

    func saveConfig(_ config: ServerConfig) throws {
        try write(config.deviceToken, for: Key.deviceToken)
        try write(config.accessClientId, for: Key.accessClientId)
        try write(config.accessClientSecret, for: Key.accessClientSecret)
        defaults.set(config.baseURL.absoluteString, forKey: Key.serverURL)
    }

    func clear() {
        [Key.deviceToken, Key.accessClientId, Key.accessClientSecret].forEach(remove)
        defaults.removeObject(forKey: Key.serverURL)
    }

    // MARK: keychain

    private func baseQuery(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
    }

    private func read(_ key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String, for key: String) throws {
        remove(key)
        var query = baseQuery(key)
        query[kSecValueData as String] = Data(value.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw APIError.http(status: Int(status), message: "Zugangsdaten konnten nicht gespeichert werden (Keychain \(status)).")
        }
    }

    private func remove(_ key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
    }
}
