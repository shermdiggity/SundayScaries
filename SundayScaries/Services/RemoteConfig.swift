import Foundation
import FantasyCore

/// The kill switch (spec §4). A small JSON file in the app's repository names platforms
/// that should not be read right now and why: `{"disabled": {"espn": "reason"}}`. ESPN
/// has no sanctioned API and can change under the app, and a takedown request has to be
/// answerable without waiting for a release. The file is read once per load with a short
/// timeout; the last answer is kept, so an offline load behaves like the last online one.
nonisolated enum RemoteConfig {
    private struct Payload: Codable { var disabled: [String: String] }

    static let url = URL(string: "https://raw.githubusercontent.com/shermdiggity/SundayScaries/main/config/providers.json")
    private static let cacheKey = "remoteConfig.disabled"

    /// Platforms that are paused, with the reason to show.
    static func disabledPlatforms() async -> [Platform: String] {
        if let url {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            request.cachePolicy = .reloadIgnoringLocalCacheData
            if let (data, response) = try? await URLSession.shared.data(for: request),
               (response as? HTTPURLResponse)?.statusCode == 200,
               let payload = try? JSONDecoder().decode(Payload.self, from: data) {
                UserDefaults.standard.set(payload.disabled, forKey: cacheKey)
                return resolve(payload.disabled)
            }
        }
        return resolve(UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: String] ?? [:])
    }

    private static func resolve(_ raw: [String: String]) -> [Platform: String] {
        var result: [Platform: String] = [:]
        for (key, reason) in raw {
            if let platform = Platform(rawValue: key) { result[platform] = reason }
        }
        return result
    }
}
