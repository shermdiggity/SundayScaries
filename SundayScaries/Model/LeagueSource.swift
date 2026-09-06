import Foundation
import FantasyCore
import FantasyProviders

/// One platform, and the way that platform supplies projections.
///
/// `LeagueProvider` already abstracts the league data itself. This adds the one thing
/// that genuinely differs between platforms and cannot live behind that protocol:
/// where a projection comes from. Sleeper needs a second endpoint and the league's own
/// scoring weights applied to raw stat lines; ESPN ships projections inside the roster
/// response, already scored server-side. Both end up as the same `Projections` value,
/// so nothing above here knows which platform it is looking at.
protocol LeagueSource: Sendable {
    var platform: Platform { get }
    func leagues() async throws -> [League]
    func teams(in league: League) async throws -> [Team]
    func matchups(league: League, week: Int) async throws -> [Matchup]
    func rosters(in league: League, week: Int) async throws -> [Roster]
    func projections(for league: League, week: Int) async -> Projections
    /// The platform's own idea of the current week, when it has one.
    func currentWeek() async -> Int?
    /// This league's scoring, as a rule set that can score anyone's stats.
    func scoringRules(for league: League) async -> ScoringRuleSet?
}

extension LeagueSource {
    func currentWeek() async -> Int? { nil }
}

struct SleeperSource: LeagueSource {
    let platform: Platform = .sleeper
    let provider: SleeperProvider
    let projectionStore: SleeperProjectionStore
    let account: LinkedAccount

    func leagues() async throws -> [League] { try await provider.leagues(for: account) }
    func teams(in league: League) async throws -> [Team] { try await provider.teams(in: league) }
    func matchups(league: League, week: Int) async throws -> [Matchup] {
        try await provider.matchups(league: league, week: week)
    }

    func rosters(in league: League, week: Int) async throws -> [Roster] {
        try await provider.rosters(in: league, week: week)
    }

    func currentWeek() async -> Int? { try? await provider.currentWeek() }
    func scoringRules(for league: League) async -> ScoringRuleSet? {
        await provider.scoringRules(for: league).map(ScoringRuleSet.sleeper)
    }

    /// Scored under THIS league's rules. A half-PPR league and a full-PPR league share
    /// a fetch but never a number.
    func projections(for league: League, week: Int) async -> Projections {
        let scoring = await provider.scoringRules(for: league)
        return await projectionStore.projections(
            season: league.season, week: week,
            rules: scoring, kind: scoring?.kind ?? league.scoringKind
        )
    }
}

struct ESPNSource: LeagueSource {
    let platform: Platform = .espn
    let provider: ESPNProvider
    let account: LinkedAccount

    func leagues() async throws -> [League] { try await provider.leagues(for: account) }
    func teams(in league: League) async throws -> [Team] { try await provider.teams(in: league) }
    func matchups(league: League, week: Int) async throws -> [Matchup] {
        try await provider.matchups(league: league, week: week)
    }

    func rosters(in league: League, week: Int) async throws -> [Roster] {
        try await provider.rosters(in: league, week: week)
    }

    func scoringRules(for league: League) async -> ScoringRuleSet? {
        await provider.scoringRules(for: league).map(ScoringRuleSet.espn)
    }

    /// Free and already correct: ESPN applies the league's scoring server-side, so there
    /// is no second request and no scoring table to reproduce.
    func projections(for league: League, week: Int) async -> Projections {
        Projections(week: week, byCanonicalID: await provider.projections(league: league, week: week))
    }
}

struct MFLSource: LeagueSource {
    let platform: Platform = .myFantasyLeague
    let provider: MFLProvider
    let account: LinkedAccount

    func leagues() async throws -> [League] { try await provider.leagues(for: account) }
    func teams(in league: League) async throws -> [Team] { try await provider.teams(in: league) }
    func matchups(league: League, week: Int) async throws -> [Matchup] {
        try await provider.matchups(league: league, week: week)
    }

    func rosters(in league: League, week: Int) async throws -> [Roster] {
        try await provider.rosters(in: league, week: week)
    }

    func scoringRules(for league: League) async -> ScoringRuleSet? { nil }

    /// MFL publishes one projection per player under the league's own scoring.
    func projections(for league: League, week: Int) async -> Projections {
        Projections(week: week, byCanonicalID: await provider.projections(league: league, week: week))
    }
}

struct FleaflickerSource: LeagueSource {
    let platform: Platform = .fleaflicker
    let provider: FleaflickerProvider
    let account: LinkedAccount

    func leagues() async throws -> [League] { try await provider.leagues(for: account) }
    func teams(in league: League) async throws -> [Team] { try await provider.teams(in: league) }
    func matchups(league: League, week: Int) async throws -> [Matchup] {
        try await provider.matchups(league: league, week: week)
    }

    func rosters(in league: League, week: Int) async throws -> [Roster] {
        try await provider.rosters(in: league, week: week)
    }

    func scoringRules(for league: League) async -> ScoringRuleSet? { nil }
    /// Fleaflicker's public API carries actual points but no projections; the lineup
    /// check and progress still work from the schedule.
    func projections(for league: League, week: Int) async -> Projections { .empty(week: week) }
}

struct YahooSource: LeagueSource {
    let platform: Platform = .yahoo
    let provider: YahooProvider
    let account: LinkedAccount

    func leagues() async throws -> [League] { try await provider.leagues(for: account) }
    func teams(in league: League) async throws -> [Team] { try await provider.teams(in: league) }
    func matchups(league: League, week: Int) async throws -> [Matchup] {
        try await provider.matchups(league: league, week: week)
    }

    func rosters(in league: League, week: Int) async throws -> [Roster] {
        try await provider.rosters(in: league, week: week)
    }

    func scoringRules(for league: League) async -> ScoringRuleSet? { nil }
    /// Per-player projections ride on the roster (`projectedPoints`); a league total is
    /// not derived here.
    func projections(for league: League, week: Int) async -> Projections { .empty(week: week) }
}
