import Foundation
import Security
import FantasyProviders

/// The keychain, for the only secrets this app holds: platform session credentials.
///
/// `nonisolated` (the app defaults to MainActor isolation): the Security calls are
/// thread-safe and a provider hands a refreshed token back from a non-main context, so
/// nothing here may be pinned to the main actor.
///
/// Deliberately not `UserDefaults`. A cookie that reads a private league is a live
/// credential — it is exactly as sensitive as the password that produced it, and
/// `UserDefaults` is a plist any backup or file dump can read.
///
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` keeps the item off backups and off
/// other devices, so a restored phone asks for a fresh sign-in rather than silently
/// carrying someone's ESPN session onto new hardware.
nonisolated enum Keychain {
    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        var query = baseQuery(key)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        #if DEBUG
        // A write that fails is otherwise silent: the next load just says "sign in
        // again" with nothing to explain why.
        if status != errSecSuccess { print("[keychain] write for \(key) failed: \(status)") }
        #endif
    }

    static func string(for key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
    }

    private static func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.sundayscaries.credentials",
            kSecAttrAccount as String: key,
        ]
    }
}

/// Where ESPN's harvested cookies live between launches.
nonisolated enum ESPNCredentialStore {
    private static let swidKey = "espn.swid"
    private static let s2Key = "espn.s2"

    static var current: ESPNCredentials? {
        guard let swid = Keychain.string(for: swidKey),
              let s2 = Keychain.string(for: s2Key),
              !swid.isEmpty, !s2.isEmpty else { return nil }
        return ESPNCredentials(swid: swid, espnS2: s2)
    }

    static func save(_ credentials: ESPNCredentials) {
        Keychain.set(credentials.swid, for: swidKey)
        Keychain.set(credentials.espnS2, for: s2Key)
    }

    static func clear() {
        Keychain.remove(swidKey)
        Keychain.remove(s2Key)
    }
}

/// The MyFantasyLeague user cookie: a documented login token, good for the season. The
/// password that produced it went to MFL once over HTTPS and was never kept.
nonisolated enum MFLCredentialStore {
    private static let cookieKey = "mfl.userCookie"

    static var current: MFLCredentials? {
        guard let cookie = Keychain.string(for: cookieKey), !cookie.isEmpty else { return nil }
        return MFLCredentials(userCookie: cookie)
    }

    static func save(_ credentials: MFLCredentials) { Keychain.set(credentials.userCookie, for: cookieKey) }
    static func clear() { Keychain.remove(cookieKey) }
}

/// Yahoo's OAuth tokens plus the app's own client id and secret, as one keychain item.
/// The provider refreshes the access token itself and hands the new set back here.
nonisolated enum YahooCredentialStore {
    private static let key = "yahoo.credentials"

    static var current: YahooCredentials? {
        guard let json = Keychain.string(for: key), let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(YahooCredentials.self, from: data)
    }

    static func save(_ credentials: YahooCredentials) {
        guard let data = try? JSONEncoder().encode(credentials), let json = String(data: data, encoding: .utf8) else { return }
        Keychain.set(json, for: key)
    }

    static func clear() { Keychain.remove(key) }
}
