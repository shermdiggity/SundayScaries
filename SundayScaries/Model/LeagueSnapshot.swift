import Foundation
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
