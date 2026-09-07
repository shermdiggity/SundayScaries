import Foundation
import SwiftUI
import FantasyCore
import FantasyProviders

/// The parallel fetch of every league in a load, and what a failed one leaves behind.
extension WeeklyModel {
    typealias LeagueOutcome = (League, Result<LeagueSnapshotBuilder.Load, any Error>)

    /// Every league is isolated: one failing must never cost you the others. They are
    /// fetched IN PARALLEL — each platform's own rate limiter is the only throttle —
    /// and each is published the moment it is ready, so cards resolve one at a time
    /// rather than the whole screen changing at once. Returns the rosters the portfolio
    /// counts, for every league that has a team of yours.
    func fetchLeagues(_ plan: LoadPlan, generation: Int) async -> [LeagueWeekRosters] {
        let quiet = !allSnapshots.isEmpty
        var portfolioInput: [LeagueWeekRosters] = []
        for await (league, outcome) in outcomes(for: plan) {
            // A newer load owns the screen now. Let the stream drain; publish nothing.
            guard generation == loadGeneration else { continue }
            let resolved: LeagueSnapshot
            switch outcome {
            case let .success(load):
                resolved = load.snapshot
                if let rosters = load.weekRosters { portfolioInput.append(rosters) }
            case let .failure(error):
                // A refresh that fails keeps what was on screen. Last known good beats a
                // failure card, especially mid-game.
                if quiet, let existing = allSnapshots.first(where: { $0.id == league.id }) {
                    if let kept = Self.weekRosters(of: existing) { portfolioInput.append(kept) }
                    continue
                }
                resolved = Self.failedSnapshot(league: league, week: plan.week, error: error)
            }
            // Replaced in place when it exists, so a quiet refresh rolls the card's
            // numbers instead of removing and re-adding it.
            if let index = allSnapshots.firstIndex(where: { $0.id == league.id }) {
                allSnapshots[index] = resolved
            } else {
                allSnapshots.append(resolved)
            }
            logLineup(resolved, note: "forced=\(plan.mode == .refresh)")
            // Published through the same derivation as everything else, so a hidden
            // league's card never flashes on screen before being filtered away.
            applyPreferences()
        }
        return portfolioInput
    }

    /// One outcome per league, in the order they finish.
    private func outcomes(for plan: LoadPlan) -> AsyncStream<LeagueOutcome> {
        AsyncStream { continuation in
            let task = Task {
                await withTaskGroup(of: LeagueOutcome.self) { group in
                    for league in plan.leagues {
                        let source = plan.sourceOfLeague[league.id]
                        group.addTask {
                            do {
                                guard let source else {
                                    throw ProviderError.notFound(resource: "source for league \(league.id)")
                                }
                                let builder = LeagueSnapshotBuilder(
                                    source: source, scheduleStore: plan.context.scheduleStore,
                                    scoreboard: plan.context.scoreboard, mode: plan.mode
                                )
                                return (league, .success(try await builder.build(league: league, week: plan.week)))
                            } catch {
                                return (league, .failure(error))
                            }
                        }
                    }
                    for await outcome in group { continuation.yield(outcome) }
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The rosters a snapshot already holds, in the portfolio's shape.
    private static func weekRosters(of snapshot: LeagueSnapshot) -> LeagueWeekRosters? {
        guard let mine = snapshot.myTeam else { return nil }
        return LeagueWeekRosters(
            league: snapshot.league, myTeamID: mine.id, rosters: snapshot.rosters,
            matchups: snapshot.currentMatchups,
            teamNames: Dictionary(uniqueKeysWithValues: snapshot.teams.map { ($0.id, $0.displayName) })
        )
    }

    /// A card that says the league could not be read, carrying the real failure so it
    /// can one day say "sign in again" rather than "couldn't refresh" for everything.
    private static func failedSnapshot(league: League, week: Int, error: any Error) -> LeagueSnapshot {
        LeagueSnapshot(
            league: league, week: week, teams: [], myTeam: nil, opponent: nil, myRoster: nil,
            opponentRoster: nil, rosters: [], matchup: nil, currentMatchups: [],
            seasonMatchups: [], weeklyRosters: [], analytics: nil, outlook: .empty,
            projections: .empty(week: 0), schedule: .empty(season: "0"),
            syncState: .failed((error as? ProviderError)
                ?? ProviderError.transport(underlying: String(describing: error)))
        )
    }

    /// What a load actually saw for the lineup, so "refresh didn't update" can be told
    /// apart from "refresh fetched, and the platform had not changed yet".
    func logLineup(_ snapshot: LeagueSnapshot, note: String) {
        #if DEBUG
        let starters = snapshot.myRoster?.starters ?? []
        let empty = starters.filter { $0.player.isEmptyLineupSlot }.count
        print("[lineup] \(snapshot.league.name) w\(snapshot.week) \(note) starters=\(starters.count) "
            + "empty=\(empty) issues=\(snapshot.issues.count)")
        #endif
    }

    /// Diagnostics for the ranking, which is invisible when there is nothing to rank.
    func logRankingDiagnostics() {
        #if DEBUG
        for snapshot in snapshots {
            let weeks = snapshot.analytics?.weeksAnalyzed ?? []
            let projected = snapshot.rosters.compactMap { snapshot.projectedTotal(for: $0) }
            print("""
            [rank] \(snapshot.league.name): status=\(snapshot.league.status.rawValue) \
            teams=\(snapshot.teams.count) rosters=\(snapshot.rosters.count) \
            weeksScored=\(weeks) projections=\(snapshot.projections.count) \
            teamsWithProjection=\(projected.count)
            """)
        }
        #endif
    }
}
