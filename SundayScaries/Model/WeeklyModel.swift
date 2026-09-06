import Foundation
import Observation
import SwiftUI
import FantasyCore
import FantasyProviders

/// Everything one league contributes to the weekly view.
struct LeagueSnapshot: Identifiable, Sendable {
    let league: League
    /// The week this snapshot shows. One week for the whole screen — the leading
    /// platform's, or whatever the reader stepped to — NOT each league's own idea of the
    /// current week. When Sleeper flips on Tuesday and ESPN has not, every card and every
    /// cross-league count still describes the same seven days.
    let week: Int
    /// Every team in the league, so standings can be shown by name rather than by id.
    let teams: [Team]
    let myTeam: Team?
    let opponent: Team?
    let myRoster: Roster?
    let opponentRoster: Roster?
    /// Every team's roster this week, so the podium can show a face per team.
    let rosters: [Roster]
    let matchup: Matchup?
    /// Every game in the league this week, yours included. Already fetched for
    /// analytics; it was simply not being kept.
    let currentMatchups: [Matchup]
    /// Every game of the season, past and future — the platforms publish the whole
    /// schedule from day one — so your own can be read week by week.
    let seasonMatchups: [Matchup]
    /// Every team's roster for every week so far. Each slot carries the points the
    /// LEAGUE awarded — exact under its own rules — which is what a player's season
    /// prefers over anything computed.
    let weeklyRosters: [Roster]
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
        // `projections` is THIS week's. For any other week the only honest number is
        // what the platform projected on the slot back then (ESPN keeps it; Sleeper does
        // not), and nothing at all beats this week's figure wearing last week's date.
        if roster.week != week {
            let values = roster.starters.compactMap(\.projectedPoints)
            return values.isEmpty ? nil : values.reduce(0, +)
        }
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
        return winProbability(
            left: myRoster, leftScore: myScore,
            right: opponentRoster, rightScore: opponentScore
        )
    }

    /// The same calculation for ANY two sides in the league, from the left side's point
    /// of view. Your own matchup is one call of this; so is everyone else's.
    func winProbability(left: Roster?, leftScore: Double, right: Roster?, rightScore: Double) -> Double? {
        guard let leftProjected = projectedTotal(for: left),
              let rightProjected = projectedTotal(for: right) else { return nil }
        guard leftScore > 0 || rightScore > 0 else {
            return WinProbability.value(margin: leftProjected - rightProjected)
        }
        let leftShare = remainingShare(left, scored: leftScore)
        let rightShare = remainingShare(right, scored: rightScore)
        return WinProbability.live(
            myScore: leftScore, opponentScore: rightScore,
            myRemainingProjection: leftProjected * leftShare,
            opponentRemainingProjection: rightProjected * rightShare,
            remainingShare: max(leftShare, rightShare)
        )
    }

    // MARK: Every matchup in the league

    /// One game, resolved to the teams and lineups on each side. Home on the left.
    struct MatchupPair: Identifiable {
        let matchup: Matchup
        let left: Team?
        let right: Team?
        let leftRoster: Roster?
        let rightRoster: Roster?
        /// A week that has been played. There are no odds to show, only a result.
        var isFinal: Bool = false

        var id: String { "\(matchup.week)-\(matchup.homeTeamID)-\(matchup.awayTeamID)" }
        var week: Int { matchup.week }
        var leftScore: Double { matchup.homeScore }
        var rightScore: Double { matchup.awayScore }
        var hasKickedOff: Bool { leftScore > 0 || rightScore > 0 }

        func involves(_ teamID: String?) -> Bool {
            guard let teamID else { return false }
            return matchup.homeTeamID == teamID || matchup.awayTeamID == teamID
        }
    }

    func pair(for matchup: Matchup) -> MatchupPair {
        // The lineups from THAT week, not this one: a past game shows who actually
        // played in it. A future week has no lineups yet and gets none.
        let weekRosters = matchup.week == week ? rosters : weeklyRosters.filter { $0.week == matchup.week }
        return MatchupPair(
            matchup: matchup,
            left: teams.first { $0.id == matchup.homeTeamID },
            right: teams.first { $0.id == matchup.awayTeamID },
            leftRoster: weekRosters.first { $0.teamID == matchup.homeTeamID },
            rightRoster: weekRosters.first { $0.teamID == matchup.awayTeamID },
            // Finality is the platform's word, not the viewed week's: stepping back to
            // look at Week 2 does not make Week 3 "final".
            isFinal: matchup.week < (league.currentWeek ?? week)
        )
    }

    // MARK: Your season

    /// One line of your schedule.
    struct ScheduleEntry: Identifiable {
        let pair: MatchupPair
        let opponent: Team?
        let myScore: Double
        let theirScore: Double
        /// nil until the week has been played.
        let won: Bool?
        let isCurrent: Bool
        var id: String { pair.id }
        var week: Int { pair.week }
    }

    /// Your game every week of the season, in order. Weeks you had no game (a bye in a
    /// league with an odd count, or the playoffs after elimination) are simply absent.
    var mySchedule: [ScheduleEntry] {
        guard let myTeam else { return [] }
        let platformWeek = league.currentWeek ?? week
        return seasonMatchups
            .filter { $0.homeTeamID == myTeam.id || $0.awayTeamID == myTeam.id }
            .sorted { $0.week < $1.week }
            .map { matchup in
                let pair = pair(for: matchup)
                let mine = matchup.score(for: myTeam.id) ?? 0
                let theirs = matchup.opponentID(of: myTeam.id).flatMap { matchup.score(for: $0) } ?? 0
                let played = matchup.week < platformWeek && (mine > 0 || theirs > 0)
                return ScheduleEntry(
                    pair: pair,
                    opponent: matchup.opponentID(of: myTeam.id).flatMap { id in teams.first { $0.id == id } },
                    myScore: mine, theirScore: theirs,
                    won: played ? mine > theirs : nil,
                    isCurrent: matchup.week == week
                )
            }
    }

    /// Everyone else's game this week. Yours is the scoreboard above; repeating it here
    /// would be noise.
    var otherMatchups: [MatchupPair] {
        currentMatchups
            .filter { $0.homeTeamID != myTeam?.id && $0.awayTeamID != myTeam?.id }
            .map(pair(for:))
    }

    func winProbability(for pair: MatchupPair) -> Double? {
        winProbability(
            left: pair.leftRoster, leftScore: pair.leftScore,
            right: pair.rightRoster, rightScore: pair.rightScore
        )
    }

    var isLineupSet: Bool { issues.isEmpty }

    /// Banked points, and how much of the lineup is still to come.
    var progress: LineupProgress {
        guard let myRoster else { return .empty }
        return LineupProgressBuilder.build(roster: myRoster, schedule: schedule)
    }

    /// The same for anyone's lineup, so a matchup you are not in can show what yours
    /// shows: banked points and how much of the week each side has left.
    func progress(for roster: Roster?) -> LineupProgress {
        guard let roster else { return .empty }
        return LineupProgressBuilder.build(roster: roster, schedule: schedule)
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
    /// The week the whole screen shows.
    private(set) var week: Int?
    /// The leading platform's week — Sleeper's `/state`, else the furthest any league
    /// has got. What `week` is unless the reader has stepped away from it.
    private(set) var liveWeek: Int?
    /// Set by the week control; nil means "follow the platforms".
    private var viewedWeek: Int?
    private(set) var attribution: [String] = []
    /// "Showing 2026 — 2027 leagues haven't been created yet." Nil in the normal case.
    private(set) var seasonNote: String?
    /// When the last load finished, so a return to the foreground can decide whether
    /// what is on screen is old enough to re-read.
    private(set) var lastLoaded: Date?
    private var triedPreviousSeason = false
    private var refreshedForWeekFlip = false

    /// One entry per league, in the weekly view's order: the rules a player's season
    /// can be read under. The sheet's one control.
    struct ScoringOption: Identifiable, Hashable {
        let leagueID: String
        let name: String
        let platform: Platform
        let rules: ScoringRuleSet?
        let kind: ScoringKind
        var id: String { leagueID }
    }

    private(set) var scoringOptions: [ScoringOption] = []
    /// What the picker shows. A league you have put away is not one you want to score by.
    var visibleScoringOptions: [ScoringOption] {
        scoringOptions.filter { !hiddenLeagueIDs.contains($0.leagueID) }
    }

    /// Kept from the last load so the player sheet can read a season without rebuilding
    /// the stack. Both cache to disk, so a season opened twice costs nothing the second
    /// time.
    private var statsStore: SleeperStatsStore?
    private var projectionStore: SleeperProjectionStore?
    private var loadedSeason: String = ""

    var handle: String {
        get { UserDefaults.standard.string(forKey: Self.handleKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.handleKey) }
    }

    /// ESPN league ids, comma separated. ESPN has no public "list my leagues" endpoint —
    /// the one that exists sits behind the same login as a private league — so the user
    /// names their leagues and the credentials decide whether private ones can be read.
    var espnLeagueIDs: String {
        get { UserDefaults.standard.string(forKey: Self.espnLeaguesKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.espnLeaguesKey) }
    }

    /// Leagues the user has hidden, and the order they want the rest in.
    ///
    /// Held by league id rather than by index, so adding or leaving a league cannot
    /// silently reshuffle everything else. An id that is not in `leagueOrder` yet — a
    /// league joined since the order was set — sorts to the end by name rather than
    /// disappearing.
    var hiddenLeagueIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: Self.hiddenKey) }
    }

    var leagueOrder: [String] {
        get { UserDefaults.standard.stringArray(forKey: Self.orderKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Self.orderKey) }
    }

    /// Every league we loaded, hidden ones included, in the user's order. This is what
    /// the editor lists — you cannot unhide a league you cannot see.
    private(set) var allLeagues: [League] = []

    /// Rosters for every league we loaded, kept so hiding or unhiding one recomputes
    /// cross-league exposure instantly instead of forcing a refetch.
    private var allWeekRosters: [LeagueWeekRosters] = []

    /// Every loaded snapshot, hidden leagues included. `snapshots` is derived from this.
    ///
    /// Hiding used to FILTER `snapshots` in place, which deleted the hidden league's data
    /// — so un-hiding brought back a league with nothing behind it, and the weekly view
    /// showed a loading skeleton for it until the next refresh refetched. Hidden means
    /// not shown, not not loaded.
    private var allSnapshots: [LeagueSnapshot] = []

    func isHidden(_ league: League) -> Bool { hiddenLeagueIDs.contains(league.id) }

    /// The leagues on screen, in the user's order. The only ones that HAVE an order.
    var visibleLeagues: [League] { allLeagues.filter { !isHidden($0) } }

    /// Put away, alphabetical. Order is meaningless for something that is not shown, so
    /// none is kept: a hidden league has no position to lose or to fight over.
    var hiddenLeagues: [League] {
        allLeagues.filter { isHidden($0) }.sorted { $0.name < $1.name }
    }

    /// Reorders the visible leagues only, from the editor's own indices.
    func moveVisibleLeagues(from source: IndexSet, to destination: Int) {
        var visible = visibleLeagues
        visible.move(fromOffsets: source, toOffset: destination)
        setVisibleOrder(visible)
    }

    func setHidden(_ hidden: Bool, for leagueID: String) {
        var ids = hiddenLeagueIDs
        if hidden { ids.insert(leagueID) } else { ids.remove(leagueID) }
        hiddenLeagueIDs = ids
        applyPreferences()
        // Hidden leagues are not fetched, so one coming back may have nothing behind it
        // yet. Its card shows a skeleton until this lands — never a blank.
        if !hidden, !allSnapshots.contains(where: { $0.id == leagueID }) {
            Task { await refresh(leagueID: leagueID) }
        }
    }

    /// Sets the order outright. Only visible leagues have one: a hidden league is simply
    /// absent from the list, and when it comes back it joins the end — predictable, and
    /// far simpler than the interleaving this used to do to preserve a position for
    /// something that was not on screen.
    func setVisibleOrder(_ visible: [League]) {
        leagueOrder = visible.map(\.id)
        applyPreferences()
    }

    /// Re-derives what the weekly view shows from what was loaded plus the user's
    /// preferences. Called after an edit so hiding or reordering takes effect
    /// immediately, with no refetch.
    func applyPreferences() {
        let order = leagueOrder
        let rank: (League) -> Int = { order.firstIndex(of: $0.id) ?? Int.max }
        allLeagues = allLeagues.sorted {
            rank($0) != rank($1) ? rank($0) < rank($1) : $0.name < $1.name
        }
        let visible = allLeagues.filter { !hiddenLeagueIDs.contains($0.id) }
        withAnimation(SWMotion.standard) {
            knownLeagues = visible
            // Derived, never filtered in place: the hidden league's snapshot stays in
            // `allSnapshots`, so un-hiding is instant and needs no refetch.
            snapshots = allSnapshots
                .filter { !hiddenLeagueIDs.contains($0.league.id) }
                .sorted {
                    rank($0.league) != rank($1.league)
                        ? rank($0.league) < rank($1.league)
                        : $0.league.name < $1.league.name
                }
            // Hidden means hidden. A league you have put away should not be quietly
            // deciding that a player is "in three of your leagues" — the counts, the
            // ranking and the whole cross-league story are about the leagues you are
            // actually looking at.
            positions = Portfolio.positions(
                across: allWeekRosters.filter { !hiddenLeagueIDs.contains($0.league.id) }
            )
        }
    }

    private static let handleKey = "sleeperHandle"
    private static let espnLeaguesKey = "espnLeagueIDs"
    private static let mflLeaguesKey = "mflLeagueIDs"
    private static let fleaflickerKey = "fleaflickerHandle"
    private static let hiddenKey = "hiddenLeagueIDs"
    private static let orderKey = "leagueOrder"

    var hasSleeper: Bool { !handle.trimmingCharacters(in: .whitespaces).isEmpty }

    /// MyFantasyLeague: public league ids typed in, or a sign-in that lists the user's.
    var mflLeagueIDs: String {
        get { UserDefaults.standard.string(forKey: Self.mflLeaguesKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.mflLeaguesKey) }
    }

    var isSignedInToMFL: Bool { MFLCredentialStore.current != nil }
    var hasMFL: Bool { !ESPNProvider.leagueIDs(from: mflLeagueIDs).isEmpty || isSignedInToMFL }

    /// Fleaflicker: the account's email, or its numeric user id. No password exists.
    var fleaflickerHandle: String {
        get { UserDefaults.standard.string(forKey: Self.fleaflickerKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.fleaflickerKey) }
    }

    var hasFleaflicker: Bool { !fleaflickerHandle.trimmingCharacters(in: .whitespaces).isEmpty }

    var hasYahoo: Bool { FeatureFlags.yahooEnabled && YahooCredentialStore.current != nil }

    /// The handle a platform's error message should quote.
    func handle(for platform: Platform) -> String {
        switch platform {
        case .sleeper:         handle
        case .fleaflicker:     fleaflickerHandle
        case .myFantasyLeague: mflLeagueIDs
        case .espn:            espnLeagueIDs
        default:               ""
        }
    }

    /// Signing in is enough on its own: with no ids typed, the provider asks ESPN which
    /// leagues this account plays in. Requiring an id here meant signing in did nothing
    /// at all, which is how this first went wrong.
    var hasESPN: Bool { !ESPNProvider.leagueIDs(from: espnLeagueIDs).isEmpty || isSignedInToESPN }
    var isSignedInToESPN: Bool { ESPNCredentialStore.current != nil }

    var hasAccount: Bool { hasSleeper || hasESPN || hasMFL || hasFleaflicker || hasYahoo }

    func snapshot(for leagueID: String) -> LeagueSnapshot? {
        snapshots.first { $0.id == leagueID }
    }

    /// Everyone you are starting anywhere, most damage first.
    ///
    /// Previously this only showed players started in MORE than one league, which meant
    /// it routinely had one or two entries — or none. Overlap is interesting, but it is
    /// not the question being asked here: the question is who is winning or losing your
    /// week, and that is answered by points.
    func yourGuys(limit: Int = 10) -> [PlayerPosition] {
        ranked(positions.filter { $0.startedCount > 0 }, weight: \.startedCount, limit: limit)
    }

    /// Everyone starting against you, most damage first.
    func upAgainst(limit: Int = 10) -> [PlayerPosition] {
        ranked(positions.filter { $0.facedCount > 0 }, weight: \.facedCount, limit: limit)
    }

    /// Ranked by total exposure: points across every league the player appears in.
    ///
    /// Points alone answered the wrong question. A receiver projected for 18 in one
    /// league outranked a defense you face in three, even though the defense is three
    /// times the problem — and kickers and defenses, which never out-project a skill
    /// player individually, could never surface at all. Multiplying by the number of
    /// leagues is what "how much of my Sunday does this person decide" actually means,
    /// and it lets a kicker in five leagues earn its place without letting one in a
    /// single league near the front.
    private func ranked(
        _ candidates: [PlayerPosition],
        weight: KeyPath<PlayerPosition, Int>,
        limit: Int
    ) -> [PlayerPosition] {
        Array(
            candidates
                .sorted {
                    let left = damage(for: $0, weight: weight)
                    let right = damage(for: $1, weight: weight)
                    return left != right ? left > right : $0.player.name < $1.player.name
                }
                .prefix(limit)
        )
    }

    /// Live points once a player's game is under way, his projection before that,
    /// multiplied by how many of your leagues he is in.
    private func damage(for position: PlayerPosition, weight: KeyPath<PlayerPosition, Int>) -> Double {
        let perLeague = points(for: position.player).value ?? 0
        return perLeague * Double(max(1, position[keyPath: weight]))
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
                nflTeam: player.nflTeam, week: snapshot.week
            ) { return label }
        }
        return nil
    }

    var counterExposed: [PlayerPosition] { Portfolio.counterExposed(positions) }

    // MARK: A player's season

    /// Every week of this player's season, scored under one league's rules.
    ///
    /// The league's own points win whenever it scored him itself — a roster he was on
    /// there, any week. Otherwise his raw public stats are scored under that league's
    /// rules. The stats and projections come from one league-agnostic feed and are
    /// cached per week, so the first sheet of the day fetches and the rest are instant.
    func playerSeason(for player: PlayerRef, under leagueID: String) async -> PlayerSeason? {
        guard let statsStore, let projectionStore else { return nil }
        guard let snapshot = allSnapshots.first(where: { $0.id == leagueID }) else { return nil }
        let option = scoringOptions.first { $0.leagueID == leagueID }
        // The platform's real current week bounds what has been played, whatever week
        // the screen happens to be showing.
        let currentWeek = snapshot.league.currentWeek ?? snapshot.week
        // The whole NFL regular season, not just what has happened: byes and the road
        // ahead are part of the picture. The schedule knows how long the season is.
        let lastWeek = max(currentWeek, snapshot.schedule.weeks.max() ?? 18)
        let weeks = 1...lastWeek
        let season = loadedSeason

        var leagueScored: [Int: Double] = [:]
        var leagueProjected: [Int: Double] = [:]
        for roster in snapshot.weeklyRosters {
            guard let slot = roster.slots.first(where: { $0.player.identity == player.identity }) else { continue }
            if let points = slot.points { leagueScored[roster.week] = points }
            if let projected = slot.projectedPoints { leagueProjected[roster.week] = projected }
        }
        // This week's projection as the matchup shows it — the league's own figure,
        // scored under its own rules on both platforms.
        if let own = snapshot.projections.projection(for: player) {
            leagueProjected[currentWeek] = own
        }

        var stats: [Int: [String: Double]] = [:]
        var projections: [Int: [String: Double]] = [:]
        var statWeeks: [RawStats] = []
        if let id = player.canonicalID {
            // Every week at once. Sequentially this was up to thirty-five round trips.
            let played = Array(1...max(1, currentWeek))
            let fetchedStats = await withTaskGroup(of: RawStats.self, returning: [RawStats].self) { group in
                for week in played {
                    group.addTask { await statsStore.stats(season: season, week: week, currentWeek: currentWeek) }
                }
                var all: [RawStats] = []
                for await raw in group { all.append(raw) }
                return all.sorted { $0.week < $1.week }
            }
            // Projections only through the current week: the platforms publish week by
            // week, and a season-long forecast from another source is not this league's.
            let fetchedProjections = await withTaskGroup(of: RawProjections.self, returning: [RawProjections].self) { group in
                for week in played {
                    group.addTask { await projectionStore.rawProjections(season: season, week: week) }
                }
                var all: [RawProjections] = []
                for await raw in group { all.append(raw) }
                return all
            }
            statWeeks = fetchedStats
            for raw in fetchedStats { if let line = raw.stats(for: id) { stats[raw.week] = line } }
            for raw in fetchedProjections { if let line = raw.stats(for: id) { projections[raw.week] = line } }
        }

        var built = PlayerSeasonBuilder.build(
            player: player, weeks: weeks,
            stats: stats, projections: projections,
            leagueScored: leagueScored, leagueProjected: leagueProjected,
            throughWeek: currentWeek,
            rules: option?.rules, fallbackKind: option?.kind ?? snapshot.league.scoringKind,
            schedule: snapshot.schedule, now: Date()
        )
        if let id = player.canonicalID, !statWeeks.isEmpty {
            built.positionRank = PositionRanker.rank(
                canonicalID: id, position: player.position, weeks: statWeeks,
                rules: option?.rules, fallbackKind: option?.kind ?? snapshot.league.scoringKind
            )
        }
        return built
    }

    // MARK: Stepping through weeks

    var canStepBack: Bool { (week ?? 1) > 1 }
    var canStepForward: Bool { (week ?? 0) < (liveWeek ?? 0) }
    var isOnLiveWeek: Bool { viewedWeek == nil || week == liveWeek }

    /// Shows a different week on every league at once. Nil follows the platforms again.
    /// Past weeks come from cache and appear at once; the leading week refetches live.
    func show(week target: Int?) async {
        if let target {
            viewedWeek = max(1, min(target, liveWeek ?? target))
        } else {
            viewedWeek = nil
        }
        await load()
    }

    /// Whether any starter in any visible league is in a game right now. Drives the
    /// live poll: while this is true the app refreshes itself; while it is false nothing
    /// runs.
    var hasLiveGame: Bool {
        snapshots.contains { snapshot in
            let week = snapshot.week
            return snapshot.rosters.contains { roster in
                roster.starters.contains { slot in
                    snapshot.schedule.gameState(nflTeam: slot.player.nflTeam, week: week) == .inProgress
                }
            }
        }
    }

    /// Leagues with at least one problem — not the total number of problems. "Nine
    /// lineups need you" for two undrafted leagues is both alarming and untrue.
    var leaguesNeedingAttention: Int { snapshots.count { !$0.issues.isEmpty } }

    /// `force` is a user's pull or the live poll: week-scoped data is re-fetched even when
    /// its cache is fresh. Without it a pull inside the TTL showed skeletons and returned
    /// the same numbers.
    ///
    /// A load that already has snapshots is QUIET: cards stay on screen and each is
    /// replaced in place as it resolves, so a poll during a game rolls the numbers rather
    /// than flashing the whole screen to skeletons every minute.
    func load(season: String? = nil, force: Bool = false) async {
        guard hasAccount else {
            // Disconnecting the last platform must clear the screen, not freeze it on
            // whatever was loaded before.
            allLeagues = []
            allSnapshots = []
            knownLeagues = []
            snapshots = []
            positions = []
            scoringOptions = []
            week = nil
            loadError = nil
            return
        }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        let mode: FetchMode = force ? .refresh : .cacheFirst
        let quiet = !allSnapshots.isEmpty
        let loadStarted = Date()
        print("[load] begin forced=\(force) quiet=\(quiet)")
        defer { print(String(format: "[load] end forced=%@ cancelled=%@ after %.2fs", String(force), String(Task.isCancelled), Date().timeIntervalSince(loadStarted))) }

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
        if season == nil, !force {
            // A fresh top-level load: forget the last one's fallbacks.
            triedPreviousSeason = false
            refreshedForWeekFlip = false
            seasonNote = nil
        }
        // The platform's own idea of the season first. A calendar rule cannot know when
        // Sleeper opens the new year; `league_season` can, and until it flips the leagues
        // people actually have are last season's.
        let platformSeason: String? = hasSleeper
            ? (try? await SleeperProvider.state(http: http))?.leagueSeason
            : nil
        let resolvedSeason = season
            ?? override.flatMap { $0.isEmpty ? nil : $0 }
            ?? platformSeason
            ?? Self.currentSeason()

        let ctx = makeContext(http: http, store: store, crosswalk: crosswalk, season: resolvedSeason, mode: mode)
        let scheduleStore = ctx.scheduleStore
        let scoreboard = ctx.scoreboard
        let sources = ctx.sources

        // A platform that fails must never cost you the other one, so each is gathered
        // separately and its error is remembered rather than thrown.
        var leagues: [League] = []
        var sourceOfLeague: [String: any LeagueSource] = [:]
        var failures: [String] = []
        for source in sources {
            do {
                let found = try await source.leagues()
                print("[load] \(source.platform.rawValue): \(found.count) leagues — \(found.map(\.name))")
                for league in found { sourceOfLeague[league.id] = source }
                leagues += found
            } catch {
                print("[load] \(source.platform.rawValue) FAILED: \(error)")
                failures.append(Self.describe(error, platform: source.platform, season: resolvedSeason,
                                              handle: handle(for: source.platform)))
            }
        }

        // A new season with no leagues in it yet is not "you have no leagues": it is
        // March. Show the last season that had some, and say so.
        if leagues.isEmpty, failures.isEmpty, season == nil, override == nil, !triedPreviousSeason,
           let year = Int(resolvedSeason) {
            triedPreviousSeason = true
            let previous = String(year - 1)
            seasonNote = "Showing \(previous) — \(resolvedSeason) leagues haven't been created yet."
            return await load(season: previous, force: force)
        }

        guard !leagues.isEmpty else {
            // "None found" and "we could not ask" are different problems with different
            // fixes, and the empty case used to read as the first no matter which it was.
            loadError = failures.first
                ?? (hasESPN && !hasSleeper
                    ? "Signed in to ESPN, but no \(resolvedSeason) leagues came back. If your league is there, add its ID."
                    : "No leagues found for \(resolvedSeason).")
            snapshots = []
            knownLeagues = []
            positions = []
            return
        }
        // A platform that failed while another worked is worth saying, but must not
        // replace the leagues that did load.
        loadError = failures.first

        // Names and platforms are known now, so placeholders can carry them and only
        // the matchup needs to be skeletal. Hidden leagues are known but not fetched.
        allLeagues = leagues
        applyPreferences()

        // The rules every league scores by, for reading a player under any of them.
        var options: [ScoringOption] = []
        for league in allLeagues {
            guard let source = sourceOfLeague[league.id] else { continue }
            options.append(ScoringOption(
                leagueID: league.id, name: league.name, platform: league.platform,
                rules: await source.scoringRules(for: league), kind: league.scoringKind
            ))
        }
        scoringOptions = options

        // The leading week: the furthest any platform has got. Sleeper's `/state` is read
        // live; a league's own week may lag it by a morning — which is exactly the case
        // showing every league on ONE week is for.
        let platformWeek = await sources.first?.currentWeek()
        liveWeek = [platformWeek, leagues.compactMap(\.currentWeek).max()].compactMap { $0 }.max()
        let shownWeek = max(1, min(viewedWeek ?? liveWeek ?? 1, liveWeek ?? Int.max))
        week = shownWeek

        // The week-flip trigger. The league list is cached for six hours and carries each
        // league's week; Sleeper's `/state` is read live. On a Tuesday morning the hero
        // could say "Week 3" over cards still on Week 2 for the rest of the morning. If
        // the platform is ahead of any cached league, re-read everything in refresh mode
        // — once, so a league that is genuinely behind (a two-week playoff round) cannot
        // loop it.
        if let live = liveWeek, !force, !refreshedForWeekFlip,
           leagues.contains(where: { $0.platform == .sleeper && ($0.currentWeek ?? live) < live }) {
            refreshedForWeekFlip = true
            return await load(season: season, force: true)
        }

        var portfolioInput: [LeagueWeekRosters] = []
        if !quiet {
            allSnapshots = []
            snapshots = []
        }

        // Hidden leagues are not fetched. Loading them "so un-hiding is instant" doubled
        // the work of every pull for cards nobody was looking at; un-hiding now fetches
        // that one league (`setHidden`). Any snapshot a hidden league already has is kept.
        let toLoad = allLeagues.filter { !hiddenLeagueIDs.contains($0.id) }

        // Every league is isolated: one failing must never cost you the others. They are
        // fetched IN PARALLEL — each platform's own rate limiter is the only throttle —
        // and each is published the moment it is ready, so cards resolve one at a time
        // rather than the whole screen changing at once.
        typealias Outcome = (League, Result<(LeagueSnapshot, LeagueWeekRosters?), any Error>)
        let outcomes = AsyncStream<Outcome> { continuation in
            let task = Task {
                await withTaskGroup(of: Outcome.self) { group in
                    for league in toLoad {
                        let source = sourceOfLeague[league.id]
                        group.addTask {
                            do {
                                guard let source else {
                                    throw ProviderError.notFound(resource: "source for league \(league.id)")
                                }
                                let snapshot = try await Self.snapshot(
                                    for: league, week: shownWeek, source: source, scheduleStore: scheduleStore,
                                    scoreboard: scoreboard, mode: mode
                                )
                                return (league, .success(snapshot))
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

        for await (league, outcome) in outcomes {
            let resolved: LeagueSnapshot
            switch outcome {
            case let .success(snapshot):
                resolved = snapshot.0
                if let rosters = snapshot.1 { portfolioInput.append(rosters) }
            case let .failure(error):
                // A refresh that fails keeps what was on screen. Last known good beats a
                // failure card, especially mid-game.
                if quiet, let existing = allSnapshots.first(where: { $0.id == league.id }) {
                    if let mine = existing.myTeam {
                        portfolioInput.append(LeagueWeekRosters(
                            league: league, myTeamID: mine.id, rosters: existing.rosters,
                            matchups: existing.currentMatchups,
                            teamNames: Dictionary(uniqueKeysWithValues: existing.teams.map { ($0.id, $0.displayName) })
                        ))
                    }
                    continue
                }
                resolved = LeagueSnapshot(
                    league: league, week: shownWeek, teams: [], myTeam: nil, opponent: nil, myRoster: nil,
                    opponentRoster: nil, rosters: [], matchup: nil, currentMatchups: [],
                    seasonMatchups: [], weeklyRosters: [], analytics: nil, outlook: .empty,
                    projections: .empty(week: 0), schedule: .empty(season: "0"),
                    syncState: .failed(ProviderError.transport(underlying: String(describing: error)))
                )
            }
            // Replaced in place when it exists, so a quiet refresh rolls the card's
            // numbers instead of removing and re-adding it.
            if let index = allSnapshots.firstIndex(where: { $0.id == league.id }) {
                allSnapshots[index] = resolved
            } else {
                allSnapshots.append(resolved)
            }
            #if DEBUG
            // What this load actually saw for the lineup — so "refresh didn't update" can
            // be told apart from "refresh fetched, and the platform had not changed yet".
            print("[lineup] \(league.name) w\(resolved.week) forced=\(force) starters=\(resolved.myRoster?.starters.count ?? 0) empty=\(resolved.myRoster?.starters.filter { $0.player.isEmptyLineupSlot }.count ?? 0) issues=\(resolved.issues.count)")
            #endif
            // Published through the same derivation as everything else, so a hidden
            // league's card never flashes on screen before being filtered away.
            applyPreferences()
        }
        // Hidden leagues' rosters were not refetched; keep what they had so un-hiding
        // does not blank the portfolio until the next load.
        let loadedIDs = Set(toLoad.map(\.id))
        portfolioInput += allWeekRosters.filter { !loadedIDs.contains($0.league.id) }
        // A league that is gone from the platform is gone from here too.
        let current = Set(allLeagues.map(\.id))
        allSnapshots.removeAll { !current.contains($0.id) }
        applyPreferences()

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
        allWeekRosters = portfolioInput
        applyPreferences()
        attribution = [
            await crosswalkStore.attribution,
            ScheduleSource.nflverse.attribution,
            await scoreboard.attribution,
        ]
        lastLoaded = Date()
        await WidgetBridge.publish(from: self)
    }

    /// Everything a load needs to talk to the platforms, built fresh for one load so the
    /// fetch mode is fixed for its whole duration. Shared by the full load and the
    /// single-league refresh so the two can never drift apart.
    private struct LoadContext {
        let sources: [any LeagueSource]
        let scheduleStore: ByeWeekStore
        let scoreboard: ScoreboardStore
    }

    private func makeContext(
        http: any HTTPClient, store: any SnapshotStore, crosswalk: PlayerCrosswalk,
        season resolvedSeason: String, mode: FetchMode
    ) -> LoadContext {
        // One limiter and one player directory shared by every store, so the catalog is
        // fetched once and every id resolves through the same path.
        let sharedLimiter = TokenBucket.sleeperDefault()
        let directory = SleeperPlayerDirectory(http: http, store: store, limiter: sharedLimiter)
        let projectionStore = SleeperProjectionStore(
            http: http, store: store,
            limiter: sharedLimiter,
            resolver: IdentityResolver(crosswalk: crosswalk),
            directory: directory,
            fetchMode: mode
        )
        let statsStore = SleeperStatsStore(
            http: http, store: store, limiter: sharedLimiter,
            resolver: IdentityResolver(crosswalk: crosswalk), directory: directory,
            fetchMode: mode
        )
        self.statsStore = statsStore
        self.projectionStore = projectionStore
        loadedSeason = resolvedSeason

        let sleeperProvider = SleeperProvider(
            http: http, store: store,
            resolver: IdentityResolver(crosswalk: crosswalk),
            season: resolvedSeason,
            limiter: sharedLimiter,
            directory: directory,
            fetchMode: mode
        )

        let scheduleStore = ByeWeekStore(http: http, store: store)
        // Live game states, so "in progress" and "final" are the platform's word rather
        // than the clock's guess. Shared by every league: it is about NFL games.
        let scoreboard = ScoreboardStore(http: http, store: store)

        // One source per configured platform. ESPN gets its own rate limiter inside its
        // provider, so a slow or angry ESPN can never starve Sleeper.
        var sources: [any LeagueSource] = []
        if hasSleeper {
            sources.append(SleeperSource(
                provider: sleeperProvider,
                projectionStore: projectionStore,
                account: LinkedAccount(platform: .sleeper, handle: handle)
            ))
        }
        if hasESPN {
            sources.append(ESPNSource(
                provider: ESPNProvider(
                    http: http, store: store,
                    resolver: IdentityResolver(crosswalk: crosswalk),
                    season: resolvedSeason,
                    credentials: ESPNCredentialStore.current,
                    fetchMode: mode
                ),
                account: LinkedAccount(platform: .espn, handle: espnLeagueIDs)
            ))
        }
        if hasMFL {
            sources.append(MFLSource(
                provider: MFLProvider(
                    http: http, store: store,
                    resolver: IdentityResolver(crosswalk: crosswalk),
                    season: resolvedSeason,
                    credentials: MFLCredentialStore.current,
                    byeWeeks: scheduleStore,
                    fetchMode: mode
                ),
                account: LinkedAccount(platform: .myFantasyLeague, handle: mflLeagueIDs)
            ))
        }
        if hasFleaflicker {
            sources.append(FleaflickerSource(
                provider: FleaflickerProvider(
                    http: http, store: store,
                    resolver: IdentityResolver(crosswalk: crosswalk),
                    season: resolvedSeason,
                    byeWeeks: scheduleStore,
                    fetchMode: mode
                ),
                account: LinkedAccount(platform: .fleaflicker, handle: fleaflickerHandle)
            ))
        }
        if FeatureFlags.yahooEnabled, let yahoo = YahooCredentialStore.current {
            sources.append(YahooSource(
                provider: YahooProvider(
                    http: http, store: store,
                    resolver: IdentityResolver(crosswalk: crosswalk),
                    season: resolvedSeason,
                    credentials: yahoo,
                    byeWeeks: scheduleStore,
                    fetchMode: mode,
                    // A refreshed token is a new credential; it goes back to the keychain.
                    onCredentialsRefreshed: { YahooCredentialStore.save($0) }
                ),
                account: LinkedAccount(platform: .yahoo, handle: "me")
            ))
        }
        return LoadContext(sources: sources, scheduleStore: scheduleStore, scoreboard: scoreboard)
    }

    /// The pull on the weekly view. The work runs in a task the MODEL owns, not the one
    /// SwiftUI hands `.refreshable`: that task is cancelled when the control decides the
    /// gesture is over, a cancelled URLSession call throws, and every provider's
    /// cache-first fallback then quietly returns the OLD value — so a pull looked like a
    /// refresh and changed nothing. An unstructured task is not cancelled with its
    /// parent, so this one finishes; the pull only waits for it.
    func refreshAll() async {
        let task = Task { await load(force: true) }
        await task.value
    }

    /// One league, refetched in refresh mode, replaced in place. Everything else on the
    /// screen is left alone — the detail's refresh button used to reload every league,
    /// which took as long as a cold start for a screen showing one of them.
    func refresh(leagueID: String) async {
        guard let league = allLeagues.first(where: { $0.id == leagueID }),
              let shownWeek = week ?? liveWeek else { return }
        let season = loadedSeason
        let task = Task { [self] in
            let store: any SnapshotStore =
                (try? FileSnapshotStore.applicationSupport()) ?? InMemorySnapshotStore()
            let http = URLSessionHTTPClient()
            // Cached after the first load; this is a disk read.
            guard let crosswalk = try? await CrosswalkStore(http: http, store: store).crosswalk() else { return }
            let ctx = makeContext(http: http, store: store, crosswalk: crosswalk, season: season, mode: .refresh)
            guard let source = ctx.sources.first(where: { $0.platform == league.platform }) else { return }
            do {
                let (snapshot, rosters) = try await Self.snapshot(
                    for: league, week: shownWeek, source: source,
                    scheduleStore: ctx.scheduleStore, scoreboard: ctx.scoreboard, mode: .refresh
                )
                if let index = allSnapshots.firstIndex(where: { $0.id == leagueID }) {
                    allSnapshots[index] = snapshot
                } else {
                    allSnapshots.append(snapshot)
                }
                allWeekRosters.removeAll { $0.league.id == leagueID }
                if let rosters { allWeekRosters.append(rosters) }
                #if DEBUG
                print("[lineup] \(league.name) w\(snapshot.week) single-refresh starters=\(snapshot.myRoster?.starters.count ?? 0) empty=\(snapshot.myRoster?.starters.filter { $0.player.isEmptyLineupSlot }.count ?? 0) issues=\(snapshot.issues.count)")
                #endif
                applyPreferences()
                await WidgetBridge.publish(from: self)
            } catch {
                // A failed refresh keeps the last good snapshot, same as the full load.
                print("[refresh] \(league.name) failed: \(error)")
            }
        }
        await task.value
    }

    private static func snapshot(
        for league: League,
        week shown: Int,
        source: any LeagueSource,
        scheduleStore: ByeWeekStore,
        scoreboard: ScoreboardStore,
        mode: FetchMode
    ) async throws -> (LeagueSnapshot, LeagueWeekRosters?) {
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
        let currentWeek = shown

        // Every week we already fetch for analytics also carries per-player points,
        // which is what makes the season outlook free.
        var allMatchups: [Matchup] = []
        var myWeeklyRosters: [Roster] = []
        var allWeeklyRosters: [Roster] = []
        var currentRosters: [Roster] = []

        let myTeam = teams.first(where: \.isOwnedByUser)

        // Every week at once. Played weeks answer from a six-hour cache and the live week
        // from the network; done one after another this was the long pole of every load.
        // Results are sorted by week afterwards so nothing depends on arrival order.
        let fetchedThrough = max(platformWeek, currentWeek, 1)
        let played: [(week: Int, rosters: [Roster], matchups: [Matchup])] = await withTaskGroup(
            of: (Int, [Roster], [Matchup])?.self
        ) { group in
            for week in 1...fetchedThrough {
                group.addTask {
                    guard let rosters = try? await source.rosters(in: league, week: week) else { return nil }
                    let matchups = (try? await source.matchups(league: league, week: week)) ?? []
                    return (week, rosters, matchups)
                }
            }
            var collected: [(week: Int, rosters: [Roster], matchups: [Matchup])] = []
            for await result in group {
                if let (week, rosters, matchups) = result { collected.append((week, rosters, matchups)) }
            }
            return collected.sorted { $0.week < $1.week }
        }
        mark("played weeks")
        for entry in played {
            allMatchups += entry.matchups
            allWeeklyRosters += entry.rosters
            if let myTeam, let mine = entry.rosters.first(where: { $0.teamID == myTeam.id }) {
                myWeeklyRosters.append(mine)
            }
            if entry.week == currentWeek { currentRosters = entry.rosters }
        }
        // The road ahead: who plays whom, no lineups yet. Sleeper publishes every week's
        // matchups from day one and ESPN's schedule is the whole season, so this is the
        // same call the played weeks made, on a slow cache. The schedule store is cached
        // in memory, so asking it how long the season is here costs nothing.
        let lastWeek = max(fetchedThrough, (await scheduleStore.byeWeeks(season: league.season)).weeks.max() ?? 18)
        if fetchedThrough < lastWeek {
            let ahead: [(Int, [Matchup])] = await withTaskGroup(of: (Int, [Matchup]).self) { group in
                for week in (fetchedThrough + 1)...lastWeek {
                    group.addTask { (week, (try? await source.matchups(league: league, week: week)) ?? []) }
                }
                var collected: [(Int, [Matchup])] = []
                for await result in group { collected.append(result) }
                return collected.sorted { $0.0 < $1.0 }
            }
            for (_, matchups) in ahead { allMatchups += matchups }
        }
        mark("future weeks")

        // However this platform supplies them — Sleeper scores raw stat lines under the
        // league's own weights, ESPN scores server-side — the result is the same value.
        let projections = await source.projections(for: league, week: currentWeek)
        mark("projections")
        // The season's schedule, with this week's live game states laid over it.
        let live = await scoreboard.liveGames(season: league.season, week: currentWeek, mode: mode)
        mark("scoreboard")
        let schedule = await scheduleStore.byeWeeks(season: league.season).withLive(live)
        mark("schedule")
        let analytics = LeagueAnalyticsBuilder.build(league: league, teams: teams, matchups: allMatchups)
        mark("analytics")
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
            week: shown,
            teams: teams,
            myTeam: myTeam,
            opponent: opponentID.flatMap { id in teams.first { $0.id == id } },
            myRoster: weekRosters.myRoster,
            opponentRoster: weekRosters.opponentRoster,
            rosters: currentRosters,
            matchup: matchup,
            currentMatchups: currentMatchups,
            seasonMatchups: allMatchups,
            weeklyRosters: allWeeklyRosters,
            analytics: analytics,
            outlook: SeasonOutlookBuilder.build(weeklyRosters: myWeeklyRosters),
            projections: projections,
            schedule: schedule,
            syncState: .fresh(Date())
        )
        return (snapshot, myTeam != nil ? weekRosters : nil)
    }

    /// What to tell the user when a platform fails. ESPN's 401 is the one that has an
    /// action attached, so it must not read as a generic network error.
    static func describe(_ error: any Error, platform: Platform, season: String, handle: String) -> String {
        if case let ProviderError.unexpectedStatus(code, body) = error, code == 401 {
            return body ?? "\(platform.displayName) needs you to sign in again."
        }
        if case let ProviderError.notFound(resource) = error {
            return "\(platform.displayName): couldn't find \(resource)."
        }
        switch platform {
        case .sleeper:         return "Couldn't find leagues for \"\(handle)\" in \(season)."
        case .fleaflicker:     return "Couldn't find Fleaflicker leagues for \"\(handle)\" in \(season). Use the email on the account, or the user id."
        case .myFantasyLeague: return "Couldn't load your MyFantasyLeague leagues for \(season). Check the league id, or sign in for a private league."
        case .yahoo:           return "Couldn't load your Yahoo leagues for \(season)."
        default:               return "Couldn't load your \(platform.displayName) leagues for \(season)."
        }
    }

    /// The NFL league year rolls over in March.
    static func currentSeason(now: Date = Date(), calendar: Calendar = .current) -> String {
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        return String(month >= 3 ? year : year - 1)
    }
}
