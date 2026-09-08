#if DEBUG
import SwiftUI
import FantasyCore
import FantasyProviders

/// One league, faked end to end, so the card, the matchup header, the faceoff and the
/// outlook row can be shown in every state without a network. The shapes are the real
/// domain types. Only the names are made up.
enum GallerySamples {
    enum State { case live, upcoming, failed, undrafted, carryover, noTeam, noMatchup, complete }

    // MARK: Players and pieces

    static var sampleProgress: [LineupProgress] {
        [
            LineupProgress(pointsScored: 0, finished: 0, inProgress: 0, yetToPlay: 9, total: 9),
            LineupProgress(pointsScored: 42.6, finished: 3, inProgress: 2, yetToPlay: 4, total: 9),
            LineupProgress(pointsScored: 128.4, finished: 9, inProgress: 0, yetToPlay: 0, total: 9),
            LineupProgress(pointsScored: 88.2, finished: 6, inProgress: 1, yetToPlay: 1, notPlaying: 1, total: 9),
        ]
    }

    static func date(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    static func player(_ name: String, _ position: Position, _ team: String,
                       _ injury: InjuryStatus = .healthy) -> PlayerRef {
        PlayerRef(identity: .canonical(id: name, source: .gsis), name: name,
                  nflTeam: team, position: position, injuryStatus: injury)
    }

    static func faced(_ name: String, _ position: Position, _ team: String, _ sleeperID: String) -> PlayerRef {
        PlayerRef(identity: .canonical(id: name, source: .gsis), name: name, nflTeam: team,
                  position: position,
                  headshotURL: URL(string: "https://sleepercdn.com/content/nfl/players/\(sleeperID).jpg"))
    }

    /// Box-score lines for the live faceoff, keyed the way the snapshot keys players.
    static var statLines: [String: [String: Double]] {
        [
            "Josh Allen": ["pass_cmp": 22, "pass_att": 31, "pass_yd": 268, "pass_td": 2, "rush_yd": 31],
            "Jahmyr Gibbs": ["rush_att": 14, "rush_yd": 72, "rush_td": 1, "rec": 3, "rec_yd": 24],
            "Justin Jefferson": ["rec": 7, "rec_tgt": 10, "rec_yd": 114, "rec_td": 1],
            "Travis Kelce": ["rec": 4, "rec_tgt": 6, "rec_yd": 43],
            "Jake Bates": ["fgm": 2, "fga": 2, "xpm": 2, "xpa": 2],
            "DEF-PIT": ["pts_allow": 13, "sack": 4, "int": 1],
            "Bijan Robinson": ["rush_att": 11, "rush_yd": 58, "rush_td": 1, "rec": 3, "rec_yd": 19],
            "Ja'Marr Chase": ["rec": 8, "rec_tgt": 12, "rec_yd": 131, "rec_td": 1],
        ]
    }

    static var defense: PlayerRef {
        PlayerRef(identity: .canonical(id: "DEF-PIT", source: .teamDefense),
                  name: "Pittsburgh Steelers", nflTeam: "PIT", position: .def,
                  headshotURL: URL(string: "https://sleepercdn.com/images/team_logos/nfl/pit.png"))
    }

    static func involvements(_ names: [String], opponents: [String] = []) -> [LeagueInvolvement] {
        names.enumerated().map { index, name in
            LeagueInvolvement(leagueID: name, leagueName: name,
                              opponentName: index < opponents.count ? opponents[index] : nil)
        }
    }

    static var samplePositions: [PlayerPosition] {
        [
            PlayerPosition(player: player("Travis Kelce", .te, "KC"),
                           ownedIn: involvements(["Alpha", "Beta", "Gamma"]),
                           startedIn: involvements(["Alpha", "Beta", "Gamma"]),
                           facedIn: [], totalLeagues: 3),
            PlayerPosition(player: player("Ashton Jeanty", .rb, "LV"),
                           ownedIn: involvements(["Alpha", "Gamma"]),
                           startedIn: involvements(["Alpha", "Gamma"]),
                           facedIn: [], totalLeagues: 3),
            PlayerPosition(player: player("Puka Nacua", .wr, "LAR"),
                           ownedIn: involvements(["Beta"]),
                           startedIn: involvements(["Beta"]),
                           facedIn: [], totalLeagues: 3),
        ]
    }

    static var sampleFaced: [PlayerPosition] {
        [
            PlayerPosition(player: player("Jahmyr Gibbs", .rb, "DET"),
                           ownedIn: [],
                           facedIn: involvements(["Alpha", "Beta", "Gamma"],
                                                 opponents: ["Mahomies", "NorthernBlitz", "FumbleFree"]),
                           totalLeagues: 3),
            PlayerPosition(player: player("Alec Pierce", .wr, "IND"),
                           ownedIn: involvements(["Alpha"]),
                           facedIn: involvements(["Beta"], opponents: ["NorthernBlitz"]),
                           totalLeagues: 3),
        ]
    }

    // MARK: The league

    static let league = League(
        id: "gallery", platform: .sleeper, name: "SAE Keeper FFL", size: 4,
        scoringKind: .halfPPR, currentWeek: 3, season: "2026", status: .inSeason
    )

    private static func team(
        _ id: String, _ name: String, _ wins: Int, _ losses: Int, _ pointsFor: Double, mine: Bool = false
    ) -> Team {
        Team(id: id, leagueID: league.id, managerName: name, teamName: name,
             record: Record(wins: wins, losses: losses), pointsFor: pointsFor, pointsAgainst: 200,
             isOwnedByUser: mine)
    }

    static let me = team("t1", "Globo Gym Purple Cobras", 2, 0, 271.3, mine: true)
    static let them = team("t2", "Mahomies", 1, 1, 240.8)
    static let third = team("t3", "MyLeekNeighbor", 1, 1, 233.0)
    static let fourth = team("t4", "dirtz", 0, 2, 190.4)
    static var teams: [Team] { [me, them, third, fourth] }

    private static func slot(
        _ kind: SlotKind, _ player: PlayerRef, points: Double? = nil, bye: Bool = false
    ) -> RosterSlot {
        RosterSlot(slot: kind, isStarter: kind != .bench, player: player, points: points, isOnBye: bye)
    }

    /// Yours: nine starters, one of them on a bye, one bench player.
    private static func myRoster(week: Int, scored: Bool) -> Roster {
        func p(_ value: Double) -> Double? { scored ? value : nil }
        return Roster(teamID: me.id, leagueID: league.id, week: week, slots: [
            slot(.qb, faced("Josh Allen", .qb, "BUF", "4984"), points: p(24.1)),
            slot(.rb, faced("Jahmyr Gibbs", .rb, "DET", "9509"), points: p(18.6)),
            slot(.rb, player("Ashton Jeanty", .rb, "LV"), points: p(9.2)),
            slot(.wr, faced("Justin Jefferson", .wr, "MIN", "6794"), points: p(21.4)),
            slot(.wr, player("Rome Odunze", .wr, "CHI"), points: p(0), bye: true),
            slot(.te, faced("Travis Kelce", .te, "KC", "1466"), points: p(6.3)),
            slot(.flex, player("Puka Nacua", .wr, "LAR"), points: p(13.0)),
            slot(.k, player("Jake Bates", .k, "DET"), points: p(8.0)),
            slot(.def, defense, points: p(11.0)),
            slot(.bench, player("Tank Dell", .wr, "HOU"), points: p(3.2)),
        ])
    }

    /// Theirs: an EMPTY quarterback slot and no flex, so the faceoff has holes to pair.
    private static func theirRoster(week: Int, scored: Bool) -> Roster {
        func p(_ value: Double) -> Double? { scored ? value : nil }
        return Roster(teamID: them.id, leagueID: league.id, week: week, slots: [
            slot(.qb, .emptyLineupSlot(platform: .sleeper)),
            slot(.rb, player("Bijan Robinson", .rb, "ATL"), points: p(15.7)),
            slot(.rb, player("De'Von Achane", .rb, "MIA"), points: p(11.1)),
            slot(.wr, player("Ja'Marr Chase", .wr, "CIN"), points: p(19.9)),
            slot(.wr, player("Alec Pierce", .wr, "IND"), points: p(4.4)),
            slot(.te, player("Brock Bowers", .te, "LV"), points: p(9.8)),
            slot(.k, player("Cameron Dicker", .k, "LAC"), points: p(7.0)),
            slot(.def, player("Denver Broncos", .def, "DEN"), points: p(5.0)),
        ])
    }

    private static func otherRoster(team: Team, week: Int) -> Roster {
        Roster(teamID: team.id, leagueID: league.id, week: week, slots: [
            slot(.qb, player("Jordan Love", .qb, "GB"), points: 17.2),
            slot(.rb, player("Saquon Barkley", .rb, "PHI"), points: 22.5),
            slot(.wr, player("CeeDee Lamb", .wr, "DAL"), points: 12.1),
        ])
    }

    /// One number per starter, keyed the way the snapshot looks them up.
    private static var projections: Projections {
        var values: [String: Double] = [:]
        for roster in [myRoster(week: 3, scored: false), theirRoster(week: 3, scored: false),
                       otherRoster(team: third, week: 3), otherRoster(team: fourth, week: 3)] {
            for slot in roster.starters {
                guard let id = slot.player.canonicalID else { continue }
                values[id] = Double(id.utf8.reduce(0) { $0 &+ Int($1) } % 140) / 10 + 6
            }
        }
        return Projections(week: 3, byCanonicalID: values)
    }

    /// Two played weeks and the current one, so standings and the outlook have data.
    private static var seasonMatchups: [Matchup] {
        [
            Matchup(week: 1, homeTeamID: me.id, awayTeamID: third.id, homeScore: 131.2, awayScore: 118.4),
            Matchup(week: 1, homeTeamID: them.id, awayTeamID: fourth.id, homeScore: 120.1, awayScore: 99.0),
            Matchup(week: 2, homeTeamID: me.id, awayTeamID: fourth.id, homeScore: 140.1, awayScore: 91.4),
            Matchup(week: 2, homeTeamID: third.id, awayTeamID: them.id, homeScore: 114.6, awayScore: 120.7),
            Matchup(week: 3, homeTeamID: me.id, awayTeamID: them.id, homeScore: 0, awayScore: 0),
            Matchup(week: 3, homeTeamID: third.id, awayTeamID: fourth.id, homeScore: 0, awayScore: 0),
        ]
    }

    /// The league as each state describes it. The id never changes, so every state is
    /// the same league to the snapshot.
    private static func league(for state: State) -> League {
        switch state {
        case .undrafted:
            League(id: league.id, platform: .espn, name: "Office Redraft", size: 4,
                   scoringKind: .ppr, currentWeek: nil, season: "2026", status: .preDraft)
        case .carryover:
            League(id: league.id, platform: .sleeper, name: "Dynasty of Regret", size: 4,
                   scoringKind: .halfPPR, currentWeek: nil, season: "2026", status: .preDraft,
                   previousLeagueID: "last-year")
        case .complete:
            League(id: league.id, platform: .myFantasyLeague, name: "Work League", size: 4,
                   scoringKind: .standard, currentWeek: 18, season: "2026", status: .complete)
        default:
            league
        }
    }

    private static func disowned(_ team: Team) -> Team {
        Team(id: team.id, leagueID: team.leagueID, managerName: team.managerName,
             teamName: team.teamName, record: team.record, pointsFor: team.pointsFor,
             pointsAgainst: team.pointsAgainst, isOwnedByUser: false)
    }

    static func snapshot(_ state: State) -> LeagueSnapshot {
        let live = state == .live
        let league = league(for: state)
        let teams = state == .noTeam ? teams.map(disowned) : teams
        var matchups = seasonMatchups
        let sync: SyncState = state == .failed
            ? .failed(ProviderError.transport(underlying: "offline"))
            : .fresh(Date())
        if live {
            matchups[4] = Matchup(week: 3, homeTeamID: me.id, awayTeamID: them.id, homeScore: 61.2, awayScore: 48.9)
        }
        let myTeam = teams.first { $0.isOwnedByUser }
        let hasMatchup = state != .noMatchup && state != .complete
        let opponent = hasMatchup && myTeam != nil ? them : nil
        let mine = myTeam.map { _ in myRoster(week: 3, scored: live) }
        let theirs = theirRoster(week: 3, scored: live)
        let current = hasMatchup ? [matchups[4], matchups[5]] : []
        let weekly = (1...2).flatMap { [myRoster(week: $0, scored: true), theirRoster(week: $0, scored: true)] }

        return LeagueSnapshot(
            league: league,
            week: 3,
            teams: teams,
            myTeam: myTeam,
            opponent: opponent,
            myRoster: mine,
            opponentRoster: opponent != nil ? theirs : nil,
            rosters: [mine, theirs, otherRoster(team: third, week: 3), otherRoster(team: fourth, week: 3)]
                .compactMap { $0 },
            matchup: hasMatchup ? matchups[4] : nil,
            currentMatchups: current,
            seasonMatchups: matchups,
            weeklyRosters: weekly,
            analytics: LeagueAnalyticsBuilder.build(league: league, teams: teams, matchups: matchups),
            outlook: SeasonOutlookBuilder.build(weeklyRosters: weekly.filter { $0.teamID == me.id },
                                                minimumStartsForLVP: 1),
            projections: projections,
            schedule: .empty(season: "2026"),
            syncState: sync
        )
    }
}
#endif
