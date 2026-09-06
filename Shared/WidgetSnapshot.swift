import Foundation

/// What the home-screen widgets show, written by the app after every load and read by
/// the widget extension. A widget is another process with a 30MB ceiling: it cannot run
/// the crosswalk, the player directory or four providers, so the app does the work and
/// leaves the answer here, in the App Group container. Everything is already resolved
/// into strings and numbers; the widget only lays it out.
struct WidgetSnapshot: Codable, Sendable {
    var generatedAt: Date
    var week: Int
    /// A starter of yours is in a game right now.
    var liveNow: Bool
    var leagues: [WidgetLeague]
    var yourGuys: [WidgetPlayer]
    var upAgainst: [WidgetPlayer]

    var leaguesNeedingAttention: [WidgetLeague] { leagues.filter { !$0.isLineupSet } }
    var allSet: Bool { leagues.allSatisfy(\.isLineupSet) }

    static let empty = WidgetSnapshot(generatedAt: .distantPast, week: 0, liveNow: false, leagues: [], yourGuys: [], upAgainst: [])
}

struct WidgetLeague: Codable, Sendable, Identifiable {
    var id: String
    var name: String
    /// `Platform.rawValue`; the widget maps it back for the mark and the tint.
    var platform: String
    var isLineupSet: Bool
    var issueCount: Int
    var hasMatchup: Bool
    var myName: String
    var myScore: Double
    var myProjected: Double?
    /// "3 played · 6 to play", the app's own wording.
    var mySummary: String
    var opponentName: String?
    var opponentScore: Double
    var opponentProjected: Double?
    var opponentSummary: String
    var winProbability: Double?
    var isLive: Bool
    var isFinal: Bool
}

struct WidgetPlayer: Codable, Sendable, Identifiable {
    var id: String
    var name: String
    var position: String
    var team: String?
    var value: Double?
    var isProjected: Bool
    var leagueCount: Int
    var totalLeagues: Int
    var kickoff: String?
    /// File name of a headshot the app copied into the container, if it had one.
    var headshotFile: String?
}

/// The App Group container both processes read.
enum WidgetStore {
    static let groupID = "group.colesherman.SundayScaries"
    static let refreshTaskID = "colesherman.SundayScaries.refresh"
    static let urlScheme = "sundayscaries"

    static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }
    static var snapshotURL: URL? { container?.appendingPathComponent("widget-snapshot.json") }
    static var headshotsDirectory: URL? { container?.appendingPathComponent("headshots", isDirectory: true) }

    static func headshotURL(file: String) -> URL? { headshotsDirectory?.appendingPathComponent(file) }

    static func load() -> WidgetSnapshot? {
        guard let url = snapshotURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let url = snapshotURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Opens the app on a league. `sundayscaries://league/<id>`.
    static func leagueURL(_ id: String) -> URL? {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = "league"
        components.path = "/\(id)"
        return components.url
    }
    static var homeURL: URL? { URL(string: "\(urlScheme)://home") }
}
