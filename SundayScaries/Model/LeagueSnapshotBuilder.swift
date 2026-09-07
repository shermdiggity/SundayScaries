import Foundation
import FantasyCore
import FantasyProviders

/// One league, fetched end to end for one week: teams, every week's rosters and
/// matchups, projections, the live schedule, and the analytics over all of it.
///
/// A value, built per load, so the provider, the stores and the fetch mode are fixed
/// for every league in that load. The full load and the single-league refresh both go
/// through here, which is what keeps them from drifting apart.
struct LeagueSnapshotBuilder {
    let source: any PlatformProvider
    let scheduleStore: ByeWeekStore
    let scoreboard: ScoreboardStore
    let mode: FetchMode

    /// What a league contributes: its snapshot, and its rosters for the cross-league
    /// portfolio when the reader has a team in it.
    struct Load {
        let snapshot: LeagueSnapshot
        let weekRosters: LeagueWeekRosters?
    }

    /// One fetched week.
    private struct WeekFetch {
        let week: Int
        let rosters: [Roster]
        let matchups: [Matchup]
    }

    func build(league: League, week shown: Int) async throws -> Load {
        // Step timings, so a slow load says WHICH step. Kept in DEBUG only.
        let t0 = Date()
        var marks: [(String, TimeInterval)] = []
        func mark(_ name: String) { marks.append((name, Date().timeIntervalSince(t0))) }
        defer {
            #if DEBUG
            let line = marks.map { String(format: "%@ %.2f", $0.0, $0.1) }.joined(separator: " | ")
            print("[timing] \(league.name): \(line)")
            #endif
        }
        let teams = try await source.teams(in: league)
        mark("teams")
        // Two weeks matter here. `platformWeek` is what this league believes is current —
        // it bounds what has been played and what rosters exist. `shown` is the week the
        // screen is on, which may be one ahead of a league that has not flipped yet.
        let platformWeek = league.currentWeek ?? shown
        let myTeam = teams.first(where: \.isOwnedByUser)

        let fetchedThrough = max(platformWeek, shown, 1)
        let played = await playedWeeks(league: league, through: fetchedThrough)
        mark("played weeks")
        // Every week fetched for analytics also carries per-player points, which is
        // what makes the season outlook free.
        var allMatchups = played.flatMap(\.matchups)
        let allWeeklyRosters = played.flatMap(\.rosters)
        let myWeeklyRosters = played.compactMap { entry in
            myTeam.flatMap { team in entry.rosters.first { $0.teamID == team.id } }
        }
        let currentRosters = played.first { $0.week == shown }?.rosters ?? []

        // The road ahead: who plays whom, no lineups yet. Sleeper publishes every week's
        // matchups from day one and ESPN's schedule is the whole season, so this is the
        // same call the played weeks made, on a slow cache. The schedule store is cached
        // in memory, so asking it how long the season is here costs nothing.
        let lastWeek = max(fetchedThrough, (await scheduleStore.byeWeeks(season: league.season)).weeks.max() ?? 18)
        allMatchups += await futureMatchups(league: league, from: fetchedThrough + 1, through: lastWeek)
        mark("future weeks")

        // However this platform supplies them — Sleeper scores raw stat lines under the
        // league's own weights, ESPN scores server-side — the result is the same value.
        let projections = await source.projections(for: league, week: shown)
        mark("projections")
        // The season's schedule, with this week's live game states laid over it.
        let live = await scoreboard.liveGames(season: league.season, week: shown, mode: mode)
        mark("scoreboard")
        let schedule = await scheduleStore.byeWeeks(season: league.season).withLive(live)
        mark("schedule")
        let pieces = Pieces(
            league: league, week: shown, teams: teams, myTeam: myTeam, allMatchups: allMatchups,
            allWeeklyRosters: allWeeklyRosters, myWeeklyRosters: myWeeklyRosters,
            currentRosters: currentRosters, projections: projections, schedule: schedule
        )
        defer { mark("analytics") }
        return Self.assemble(pieces)
    }

    /// Everything fetched for one league, before analytics and the snapshot.
    private struct Pieces {
        let league: League
        let week: Int
        let teams: [Team]
        let myTeam: Team?
        let allMatchups: [Matchup]
        let allWeeklyRosters: [Roster]
        let myWeeklyRosters: [Roster]
        let currentRosters: [Roster]
        let projections: Projections
        let schedule: ByeWeeks
    }

    private static func assemble(_ pieces: Pieces) -> Load {
        let analytics = LeagueAnalyticsBuilder.build(
            league: pieces.league, teams: pieces.teams, matchups: pieces.allMatchups
        )
        let currentMatchups = pieces.allMatchups.filter { $0.week == pieces.week }
        let myTeam = pieces.myTeam
        let matchup = myTeam.flatMap { team in currentMatchups.first { $0.score(for: team.id) != nil } }
        let opponentID = myTeam.flatMap { team in matchup?.opponentID(of: team.id) }

        let weekRosters = LeagueWeekRosters(
            league: pieces.league,
            myTeamID: myTeam?.id,
            rosters: pieces.currentRosters,
            matchups: currentMatchups,
            teamNames: Dictionary(uniqueKeysWithValues: pieces.teams.map { ($0.id, $0.displayName) })
        )

        let snapshot = LeagueSnapshot(
            league: pieces.league,
            week: pieces.week,
            teams: pieces.teams,
            myTeam: myTeam,
            opponent: opponentID.flatMap { id in pieces.teams.first { $0.id == id } },
            myRoster: weekRosters.myRoster,
            opponentRoster: weekRosters.opponentRoster,
            rosters: pieces.currentRosters,
            matchup: matchup,
            currentMatchups: currentMatchups,
            seasonMatchups: pieces.allMatchups,
            weeklyRosters: pieces.allWeeklyRosters,
            analytics: analytics,
            outlook: SeasonOutlookBuilder.build(weeklyRosters: pieces.myWeeklyRosters),
            projections: pieces.projections,
            schedule: pieces.schedule,
            syncState: .fresh(Date())
        )
        return Load(snapshot: snapshot, weekRosters: myTeam != nil ? weekRosters : nil)
    }

    /// Every week at once. Played weeks answer from a six-hour cache and the live week
    /// from the network; done one after another this was the long pole of every load.
    /// Sorted by week afterwards so nothing depends on arrival order.
    private func playedWeeks(league: League, through lastWeek: Int) async -> [WeekFetch] {
        await withTaskGroup(of: WeekFetch?.self) { group in
            for week in 1...lastWeek {
                group.addTask {
                    guard let rosters = try? await source.rosters(in: league, week: week) else { return nil }
                    let matchups = (try? await source.matchups(league: league, week: week)) ?? []
                    return WeekFetch(week: week, rosters: rosters, matchups: matchups)
                }
            }
            var collected: [WeekFetch] = []
            for await fetched in group {
                if let fetched { collected.append(fetched) }
            }
            return collected.sorted { $0.week < $1.week }
        }
    }

    private func futureMatchups(league: League, from first: Int, through last: Int) async -> [Matchup] {
        guard first <= last else { return [] }
        return await withTaskGroup(of: (Int, [Matchup]).self) { group in
            for week in first...last {
                group.addTask { (week, (try? await source.matchups(league: league, week: week)) ?? []) }
            }
            var collected: [(Int, [Matchup])] = []
            for await result in group { collected.append(result) }
            return collected.sorted { $0.0 < $1.0 }.flatMap(\.1)
        }
    }
}
