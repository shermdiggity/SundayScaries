import Foundation
import Observation
import SwiftUI
import FantasyCore
import FantasyProviders

/// Everything one league contributes to the weekly view.
struct LeagueSnapshot: Identifiable, Sendable {
    let league: League
    /// Every team in the league, so standings can be shown by name rather than by id.
    let teams: [Team]
    let myTeam: Team?
    let opponent: Team?
    let myRoster: Roster?
    let opponentRoster: Roster?
    /// Every team's roster this week, so the podium can show a face per team.
    let rosters: [Roster]
    let matchup: Matchup?
    let analytics: LeagueAnalytics?
    let outlook: SeasonOutlook
    /// Projections for the current week, so an unplayed lineup still says what it is
    /// worth. Empty when the (undocumented) projections endpoint had nothing.
    let projections: Projections
    /// The league's schedule, for "@ KC" next to a player's name.
    let schedule: ByeWeeks
    let syncState: SyncState

    var id: String { league.id }

    var myScore: Double { matchup.flatMap { m in myTeam.flatMap { m.score(for: $0.id) } } ?? 0 }
    var opponentScore: Double { matchup.flatMap { m in opponent.flatMap { m.score(for: $0.id) } } ?? 0 }

    var standing: Int? {
        guard let myTeam else { return nil }
        return analytics?.team(myTeam.id)?.standingsRank
    }

    var issues: [LineupIssue] { myRoster?.issues(in: league) ?? [] }

    /// Whether this week's game has actually started. A 0-0 bar has nothing to say.
    var hasKickedOff: Bool { myScore > 0 || opponentScore > 0 }

    func projectedTotal(for roster: Roster?) -> Double? {
        guard let roster else { return nil }
        let values = roster.starters.compactMap { projections.projection(for: $0.player) }
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    /// Points still to be scored, as a share of the projected total. Drives how much
    /// uncertainty is left in the win probability.
    private func remainingShare(_ roster: Roster?, scored: Double) -> Double {
        guard let projected = projectedTotal(for: roster), projected > 0 else { return 1 }
        return min(max(1 - (scored / projected), 0), 1)
    }

    /// `nil` when there is no opponent or nothing to project — better to show nothing
    /// than a number with no basis.
    var winProbability: Double? {
        guard opponent != nil else { return nil }
        guard let mine = projectedTotal(for: myRoster),
              let theirs = projectedTotal(for: opponentRoster) else { return nil }
        guard hasKickedOff else {
            return WinProbability.value(margin: mine - theirs)
        }
        let myShare = remainingShare(myRoster, scored: myScore)
        let theirShare = remainingShare(opponentRoster, scored: opponentScore)
        return WinProbability.live(
            myScore: myScore, opponentScore: opponentScore,
            myRemainingProjection: mine * myShare,
            opponentRemainingProjection: theirs * theirShare,
            remainingShare: max(myShare, theirShare)
        )
    }

    var isLineupSet: Bool { issues.isEmpty }

    /// Banked points, and how much of the lineup is still to come.
    var progress: LineupProgress {
        guard let myRoster else { return .empty }
        return LineupProgressBuilder.build(roster: myRoster, schedule: schedule)
    }

    var opponentProgress: LineupProgress {
        guard let opponentRoster else { return .empty }
        return LineupProgressBuilder.build(roster: opponentRoster, schedule: schedule)
    }

    /// A carried-over keeper roster is real, current data, but it reads as stale
    /// unless the card says the league has not drafted.
    var isPreDraftCarryover: Bool {
        guard let myRoster else { return false }
        return myRoster.isPreDraftCarryover(in: league)
    }
}

@MainActor
@Observable
final class WeeklyModel {
    private(set) var snapshots: [LeagueSnapshot] = []
    /// The leagues we know exist, in display order, as soon as the league list returns.
    ///
    /// The list is built from this rather than from `snapshots`, so it is the right
    /// length from the first moment and each card fills in where its placeholder was —
    /// instead of three generic skeletons being replaced wholesale by five real cards.
    private(set) var knownLeagues: [League] = []
    private(set) var positions: [PlayerPosition] = []
    private(set) var isLoading = false
    private(set) var loadError: String?
    private(set) var week: Int?
    private(set) var attribution: [String] = []

    var handle: String {
        get { UserDefaults.standard.string(forKey: Self.handleKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.handleKey) }
    }

    private static let handleKey = "sleeperHandle"

    var hasAccount: Bool { !handle.trimmingCharacters(in: .whitespaces).isEmpty }

    func snapshot(for leagueID: String) -> LeagueSnapshot? {
        snapshots.first { $0.id == leagueID }
    }

    var reliedUpon: [PlayerPosition] { Portfolio.reliedUpon(positions) }

    /// Opponents' starters you face in more than one league. When none overlap there is
    /// no cross-league story to tell, so the section falls back to the most dangerous
    /// individuals instead of showing nothing.
    func upAgainst(limit: Int = 8) -> [PlayerPosition] {
        let shared = Portfolio.counterExposed(positions).filter { $0.facedCount > 1 }
        if !shared.isEmpty { return Array(shared.prefix(limit)) }
        return Array(
            Portfolio.counterExposed(positions)
                .sorted { projectedPoints(for: $0) > projectedPoints(for: $1) }
                .prefix(limit)
        )
    }

    /// Highest projection this player carries in any league we loaded.
    private func projectedPoints(for position: PlayerPosition) -> Double {
        projection(for: position.player) ?? 0
    }

    func projection(for player: PlayerRef) -> Double? {
        snapshots.compactMap { $0.projections.projection(for: player) }.max()
    }

    /// What to show on a player card: actual points once his game is under way,
    /// otherwise the projection, flagged so the card can label it.
    func points(for player: PlayerRef) -> (value: Double?, isProjected: Bool) {
        for snapshot in snapshots {
            let state = snapshot.schedule.gameState(nflTeam: player.nflTeam, week: snapshot.myRoster?.week ?? 1)
            guard state == .inProgress || state == .final else { continue }
            let scored = snapshot.rosters
                .flatMap(\.slots)
                .first { $0.player.canonicalID == player.canonicalID }?
                .points
            if let scored { return (scored, false) }
        }
        return (projection(for: player), true)
    }

    /// "Sun 1:00 PM" in the reader's timezone.
    func kickoff(for player: PlayerRef) -> String? {
        for snapshot in snapshots {
            if let label = snapshot.schedule.kickoffLabel(
                nflTeam: player.nflTeam, week: snapshot.myRoster?.week ?? snapshot.league.currentWeek ?? 1
            ) { return label }
        }
        return nil
    }
    var counterExposed: [PlayerPosition] { Portfolio.counterExposed(positions) }

    /// Leagues with at least one problem — not the total number of problems. "Nine
    /// lineups need you" for two undrafted leagues is both alarming and untrue.
    var leaguesNeedingAttention: Int { snapshots.count { !$0.issues.isEmpty } }

    func load(season: String? = nil) async {
        guard hasAccount else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        let store: any SnapshotStore =
            (try? FileSnapshotStore.applicationSupport()) ?? InMemorySnapshotStore()
        let http = URLSessionHTTPClient()

        let crosswalkStore = CrosswalkStore(http: http, store: store)
        let crosswalk: PlayerCrosswalk
        do {
            crosswalk = try await crosswalkStore.crosswalk()
        } catch {
            loadError = "Couldn't load the player index. It downloads once and is cached after that, so this needs a connection the first time."
            return
        }

        // A season override, for looking at a finished season during development.
        // Set with a launch argument: -seasonOverride 2025
        let override = UserDefaults.standard.string(forKey: "seasonOverride")
        let resolvedSeason = season ?? override.flatMap { $0.isEmpty ? nil : $0 } ?? Self.currentSeason()

        // One limiter and one player directory shared by every store, so the catalog is
        // fetched once and every id resolves through the same path.
        let sharedLimiter = TokenBucket.sleeperDefault()
        let directory = SleeperPlayerDirectory(http: http, store: store, limiter: sharedLimiter)
        let projectionStore = SleeperProjectionStore(
            http: http, store: store,
            limiter: sharedLimiter,
            resolver: IdentityResolver(crosswalk: crosswalk),
            directory: directory
        )
        let provider = SleeperProvider(
            http: http, store: store,
            resolver: IdentityResolver(crosswalk: crosswalk),
            season: resolvedSeason,
            limiter: sharedLimiter,
            directory: directory
        )


        let scheduleStore = ByeWeekStore(http: http, store: store)

        let account = LinkedAccount(platform: .sleeper, handle: handle)
        let leagues: [League]
        do {
            leagues = try await provider.leagues(for: account)
        } catch {
            loadError = "Couldn't find leagues for \"\(handle)\" in \(resolvedSeason)."
            return
        }

        guard !leagues.isEmpty else {
            loadError = "No leagues for \"\(handle)\" in \(resolvedSeason)."
            snapshots = []
            knownLeagues = []
            positions = []
            return
        }

        // Names and platforms are known now, so placeholders can carry them and only
        // the matchup needs to be skeletal.
        knownLeagues = leagues.sorted { $0.name < $1.name }

        week = (try? await provider.currentWeek()) ?? leagues.compactMap(\.currentWeek).max()

        var portfolioInput: [LeagueWeekRosters] = []
        snapshots = []

        // Every league is isolated: one failing must never cost you the others. Each is
        // published the moment it is ready, so cards resolve one at a time rather than
        // the whole screen changing at once.
        for league in knownLeagues {
            let resolved: LeagueSnapshot
            do {
                let snapshot = try await Self.snapshot(
                    for: league, provider: provider,
                    projectionStore: projectionStore, scheduleStore: scheduleStore
                )
                resolved = snapshot.0
                if let rosters = snapshot.1 { portfolioInput.append(rosters) }
            } catch {
                resolved = LeagueSnapshot(
                    league: league, teams: [], myTeam: nil, opponent: nil, myRoster: nil,
                    opponentRoster: nil, rosters: [], matchup: nil, analytics: nil, outlook: .empty,
                    projections: .empty(week: 0), schedule: .empty(season: "0"),
                    syncState: .failed(ProviderError.transport(underlying: String(describing: error)))
                )
            }
            withAnimation(SWMotion.standard) {
                snapshots.append(resolved)
            }
        }

        // Diagnostics for the ranking, which is invisible when there is nothing to rank.
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
        withAnimation(SWMotion.standard) {
            positions = Portfolio.positions(across: portfolioInput)
        }
        attribution = [await crosswalkStore.attribution, ScheduleSource.nflverse.attribution]
    }

    private static func snapshot(
        for league: League,
        provider: SleeperProvider,
        projectionStore: SleeperProjectionStore,
        scheduleStore: ByeWeekStore
    ) async throws -> (LeagueSnapshot, LeagueWeekRosters?) {
        let teams = try await provider.teams(in: league)
        let currentWeek = league.currentWeek ?? 1

        // Every week we already fetch for analytics also carries per-player points,
        // which is what makes the season outlook free.
        var allMatchups: [Matchup] = []
        var myWeeklyRosters: [Roster] = []
        var currentRosters: [Roster] = []

        let myTeam = teams.first(where: \.isOwnedByUser)

        for week in 1...max(currentWeek, 1) {
            guard let rosters = try? await provider.rosters(in: league, week: week) else { continue }
            let weekMatchups = (try? await provider.matchups(league: league, week: week)) ?? []
            allMatchups += weekMatchups
            if let myTeam, let mine = rosters.first(where: { $0.teamID == myTeam.id }) {
                myWeeklyRosters.append(mine)
            }
            if week == currentWeek { currentRosters = rosters }
        }

        let projections = await projectionStore.projections(season: league.season, week: currentWeek)
        let schedule = await scheduleStore.byeWeeks(season: league.season)
        let analytics = LeagueAnalyticsBuilder.build(league: league, teams: teams, matchups: allMatchups)
        let currentMatchups = allMatchups.filter { $0.week == currentWeek }
        let matchup = myTeam.flatMap { team in currentMatchups.first { $0.score(for: team.id) != nil } }
        let opponentID = myTeam.flatMap { team in matchup?.opponentID(of: team.id) }

        let weekRosters = LeagueWeekRosters(
            league: league,
            myTeamID: myTeam?.id,
            rosters: currentRosters,
            matchups: currentMatchups,
            teamNames: Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0.displayName) })
        )

        let snapshot = LeagueSnapshot(
            league: league,
            teams: teams,
            myTeam: myTeam,
            opponent: opponentID.flatMap { id in teams.first { $0.id == id } },
            myRoster: weekRosters.myRoster,
            opponentRoster: weekRosters.opponentRoster,
            rosters: currentRosters,
            matchup: matchup,
            analytics: analytics,
            outlook: SeasonOutlookBuilder.build(weeklyRosters: myWeeklyRosters),
            projections: projections,
            schedule: schedule,
            syncState: .fresh(Date())
        )
        return (snapshot, myTeam != nil ? weekRosters : nil)
    }

    /// The NFL league year rolls over in March.
    static func currentSeason(now: Date = Date(), calendar: Calendar = .current) -> String {
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        return String(month >= 3 ? year : year - 1)
    }
}
