#if DEBUG
import Foundation
import FantasyCore

/// The demo's NFL week: a made-up Week 3 slate shaped like a real Sunday, with each
/// game's state set by the scenario rather than the clock.
extension DemoData {
    enum Slot { case thursday, early, late, sunday, monday }

    struct Game {
        let home: String
        let away: String
        let slot: Slot
    }

    static let games: [Game] = [
        Game(home: "BUF", away: "MIA", slot: .thursday),
        Game(home: "DET", away: "CIN", slot: .early), Game(home: "BAL", away: "PHI", slot: .early),
        Game(home: "NYJ", away: "MIN", slot: .early), Game(home: "ATL", away: "PIT", slot: .early),
        Game(home: "HOU", away: "CAR", slot: .early), Game(home: "TB", away: "JAX", slot: .early),
        Game(home: "NYG", away: "WAS", slot: .early), Game(home: "IND", away: "NE", slot: .early),
        Game(home: "LAR", away: "SF", slot: .late), Game(home: "DEN", away: "ARI", slot: .late),
        Game(home: "SEA", away: "LV", slot: .late),
        Game(home: "GB", away: "DAL", slot: .sunday),
        Game(home: "LAC", away: "KC", slot: .monday),
    ]

    static let byeTeams: Set<String> = ["CHI", "TEN", "NO", "CLE"]

    private static var allTeams: [String] {
        games.flatMap { [$0.home, $0.away] } + byeTeams.sorted()
    }

    private static func slot(of team: String) -> Slot? {
        games.first { $0.home == team || $0.away == team }?.slot
    }

    /// The instant a slot kicks off, in the NFL's own time zone: Week 3 of 2026.
    private static func kickoff(_ slot: Slot) -> Date {
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 9
        parts.timeZone = TimeZone(identifier: "America/New_York")
        switch slot {
        case .thursday: parts.day = 24; parts.hour = 20; parts.minute = 15
        case .early:    parts.day = 27; parts.hour = 13; parts.minute = 0
        case .late:     parts.day = 27; parts.hour = 16; parts.minute = 25
        case .sunday:   parts.day = 27; parts.hour = 20; parts.minute = 20
        case .monday:   parts.day = 28; parts.hour = 20; parts.minute = 15
        }
        return Calendar(identifier: .gregorian).date(from: parts) ?? Date()
    }

    /// Whether a slot has been played, is on, or is still to come in each scenario.
    private static func state(_ slot: Slot, in scenario: Scenario) -> LiveGames.State {
        switch scenario {
        case .final: return .post
        case .morning: return slot == .thursday ? .post : .pre
        case .live:
            switch slot {
            case .thursday, .early: return .post
            case .late:             return .in
            case .sunday, .monday:  return .pre
            }
        }
    }

    static func gameState(of team: String?, in scenario: Scenario) -> LiveGames.State? {
        guard let team, let slot = slot(of: team) else { return nil }
        return state(slot, in: scenario)
    }

    /// The kit's schedule type has no public initialiser — it is built by the schedule
    /// store from nflverse — but it decodes, so the demo writes the document the store
    /// would have cached and reads it back through the same door.
    private struct ScheduleDocument: Encodable {
        let season: String
        let byWeek: [Int: Set<String>]
        let opponents: [Int: [String: String]]
        let kickoffs: [Int: [String: Date]]
    }

    private struct LiveDocument: Encodable {
        let season: String
        let week: Int
        let states: [String: String]
        let details: [String: String]
    }

    /// Other weeks rotate the same teams against each other, so a player's season log
    /// has an opponent on every line.
    private static func rotatedOpponents(week: Int) -> [String: String] {
        let teams = allTeams
        let shift = week % (teams.count - 1) + 1
        var opponents: [String: String] = [:]
        for (index, team) in teams.enumerated() {
            let other = teams[(index + shift) % teams.count]
            opponents[team] = index.isMultiple(of: 2) ? other : "@" + other
        }
        return opponents
    }

    static func schedule(for scenario: Scenario) -> ByeWeeks {
        var byWeek: [Int: Set<String>] = [:]
        var opponents: [Int: [String: String]] = [:]
        for week in 1...18 where week != DemoData.week {
            byWeek[week] = []
            opponents[week] = rotatedOpponents(week: week)
        }
        byWeek[week] = byeTeams
        var thisWeek: [String: String] = [:]
        var thisWeekKickoffs: [String: Date] = [:]
        var states: [String: String] = [:]
        for game in games {
            thisWeek[game.home] = game.away
            thisWeek[game.away] = "@" + game.home
            thisWeekKickoffs[game.home] = kickoff(game.slot)
            thisWeekKickoffs[game.away] = kickoff(game.slot)
            states[game.home] = state(game.slot, in: scenario).rawValue
            states[game.away] = states[game.home]
        }
        opponents[week] = thisWeek

        let document = ScheduleDocument(
            season: season, byWeek: byWeek, opponents: opponents, kickoffs: [week: thisWeekKickoffs]
        )
        let live = LiveDocument(season: season, week: week, states: states, details: [:])
        guard let scheduleData = try? JSONEncoder().encode(document),
              let schedule = try? JSONDecoder().decode(ByeWeeks.self, from: scheduleData),
              let liveData = try? JSONEncoder().encode(live),
              let liveGames = try? JSONDecoder().decode(LiveGames.self, from: liveData) else {
            return .empty(season: season)
        }
        return schedule.withLive(liveGames)
    }
}
#endif
