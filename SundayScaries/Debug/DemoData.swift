#if DEBUG
import Foundation
import FantasyCore
import FantasyProviders

/// A whole in-season account, faked end to end, for App Store screenshots.
///
/// Launch with `-sw.demo live` (a Sunday afternoon: the early games final, the late ones
/// on, the night games still to come), `-sw.demo morning` (Sunday morning, nothing kicked
/// off, one lineup with a hole in it) or `-sw.demo final` (Tuesday, looking back at the
/// week just played). `-sw.debugHour 16.5` pins the sky to match.
///
/// Every shape is the real domain type and every number flows through the real builders:
/// standings from the matchups, progress from the schedule, the hero from the tally. The
/// leagues and the teams are invented. The players are real, because a lineup of made-up
/// names looks like nothing. Never compiled into Release; never touches the network
/// except for headshots.
///
/// Split by concern: the players (`DemoPlayers`), the NFL week (`DemoSchedule`), the
/// leagues and their lineups (`DemoLeagues`), a player's season (`DemoSeason`).
enum DemoData {
    enum Scenario: String { case live, morning, final }

    static var scenario: Scenario? {
        Scenario(rawValue: UserDefaults.standard.string(forKey: "sw.demo") ?? "")
    }

    static var isActive: Bool { scenario != nil }

    static let season = "2026"
    static let week = 3

    /// What the model installs.
    struct Account {
        let leagues: [League]
        let snapshots: [LeagueSnapshot]
        let weekRosters: [LeagueWeekRosters]
        let scoringOptions: [WeeklyModel.ScoringOption]
        let liveWeek: Int
        let viewedWeek: Int?
    }

    static func build(_ scenario: Scenario) -> Account {
        let schedule = schedule(for: scenario)
        let liveWeek = scenario == .final ? week + 1 : week
        var account = Account(
            leagues: [], snapshots: [], weekRosters: [], scoringOptions: [],
            liveWeek: liveWeek, viewedWeek: scenario == .final ? week : nil
        )
        for spec in specs(for: scenario) {
            let built = buildLeague(spec, scenario: scenario, schedule: schedule, platformWeek: liveWeek)
            account = Account(
                leagues: account.leagues + [built.league],
                snapshots: account.snapshots + [built.snapshot],
                weekRosters: account.weekRosters + [built.weekRosters],
                scoringOptions: account.scoringOptions + [built.option],
                liveWeek: account.liveWeek, viewedWeek: account.viewedWeek
            )
        }
        return account
    }

    /// Deterministic: the same player scores the same in the same league on every launch.
    static func unit(_ seed: String) -> Double {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return Double(hash % 10_000) / 10_000
    }

    static func slug(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
    }
}

extension WeeklyModel {
    /// Puts the demo account on screen in place of a load. Called at the top of `load()`
    /// whenever `-sw.demo` is set, so every path that would fetch — the pull, the poll, a
    /// week step — installs the same fixed world instead.
    func installDemo(_ scenario: DemoData.Scenario) {
        let demo = DemoData.build(scenario)
        if handle.isEmpty { handle = "purplecobras" }
        loadedSeason = DemoData.season
        liveWeek = demo.liveWeek
        if viewedWeek == nil { viewedWeek = demo.viewedWeek }
        week = viewedWeek ?? demo.liveWeek
        allLeagues = demo.leagues
        allSnapshots = demo.snapshots
        allWeekRosters = demo.weekRosters
        scoringOptions = demo.scoringOptions
        // The real attribution lines, so the You sheet reads as it ships.
        attribution = [
            "Player ID crosswalk by DynastyProcess (github.com/dynastyprocess/data), GPL-3.0.",
            ScheduleSource.nflverse.attribution,
            "Live game status from ESPN's public scoreboard.",
        ]
        loadProblem = nil
        seasonFallback = nil
        isLoading = false
        lastLoaded = Date()
        applyPreferences()
    }
}
#endif
