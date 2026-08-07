import Foundation
import Security

/// Per-host pairing state: a stable per-install deviceId, the pinned certificate
/// fingerprint (trust-on-first-use), and the bearer token issued on pairing.
/// Fingerprints/host bookkeeping live in UserDefaults; the bearer token -- the
/// one piece that actually grants control of someone's radio -- lives in the Keychain.
final class PairingStore {
    private var defaults: UserDefaults { HandoffDefaults.store }
    private let deviceIdDefaultsKey = "handoff.deviceId"

    var deviceId: String {
        if let existing = defaults.string(forKey: deviceIdDefaultsKey) {
            return existing
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: deviceIdDefaultsKey)
        return generated
    }

    func pinnedFingerprint(forHost host: String) -> String? {
        defaults.string(forKey: fingerprintKey(host))
    }

    func setPinnedFingerprint(_ fingerprint: String, forHost host: String) {
        defaults.set(fingerprint, forKey: fingerprintKey(host))
    }

    /// Deliberately forgets the pin so the next connection re-pins whatever answers.
    /// Only ever called when the pilot has confirmed an identity change by typing the
    /// code shown on that PC -- never automatically.
    func clearPinnedFingerprint(forHost host: String) {
        defaults.removeObject(forKey: fingerprintKey(host))
    }

    func token(forHost host: String) -> String? {
        KeychainHelper.read(key: tokenKey(host))
    }

    func setToken(_ token: String, forHost host: String) {
        KeychainHelper.save(key: tokenKey(host), value: token)
    }

    func clearToken(forHost host: String) {
        KeychainHelper.delete(key: tokenKey(host))
    }

    private func fingerprintKey(_ host: String) -> String { "handoff.fingerprint.\(host)" }
    private func tokenKey(_ host: String) -> String { "handoff.token.\(host)" }
}

private enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = Data(value.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(baseQuery as CFDictionary)
        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
