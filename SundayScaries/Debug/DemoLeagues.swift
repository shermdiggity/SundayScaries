#if DEBUG
import Foundation
import FantasyCore
import FantasyProviders

/// The demo's three leagues: who is in them, what everyone started, and what it scored.
extension DemoData {
    struct Lineup {
        let starters: [(SlotKind, String)]
        let bench: [String]
    }

    struct LeagueSpec {
        let id: String
        let platform: Platform
        let name: String
        let kind: ScoringKind
        let teams: [String]
        let mine: Lineup
        let theirs: Lineup
        /// Week 1 and week 2, my score then theirs — so the record is what it says.
        let played: [(Double, Double)]
    }

    /// What one league contributes to the account.
    struct BuiltLeague {
        let league: League
        let snapshot: LeagueSnapshot
        let weekRosters: LeagueWeekRosters
        let option: WeeklyModel.ScoringOption
    }

    // MARK: The three leagues

    static func specs(for scenario: Scenario) -> [LeagueSpec] {
        [dormRoomDynasty, officeRedraft(scenario), hometownKeeper]
    }

    private static let dormRoomDynasty = LeagueSpec(
        id: "demo-sleeper", platform: .sleeper, name: "Dorm Room Dynasty", kind: .halfPPR,
        teams: ["Purple Cobras", "Mahomies", "Gridiron Gang", "Bye Week Blues",
                "Chase-ing Titles", "Waddle I Do", "Sacko Survivors", "Dak to the Future"],
        mine: Lineup(
            starters: [(.qb, "Josh Allen"), (.rb, "Jahmyr Gibbs"), (.rb, "Ashton Jeanty"),
                       (.wr, "Justin Jefferson"), (.wr, "Puka Nacua"), (.te, "Brock Bowers"),
                       (.flex, "Ladd McConkey"), (.k, "Jake Bates"), (.def, "DEF-PIT")],
            bench: ["Chase Brown", "Rome Odunze", "Tucker Kraft"]
        ),
        theirs: Lineup(
            starters: [(.qb, "Patrick Mahomes"), (.rb, "Bijan Robinson"), (.rb, "De'Von Achane"),
                       (.wr, "Ja'Marr Chase"), (.wr, "Amon-Ra St. Brown"), (.te, "Trey McBride"),
                       (.flex, "Kyren Williams"), (.k, "Brandon Aubrey"), (.def, "DEF-DEN")],
            bench: ["Josh Jacobs", "DK Metcalf"]
        ),
        played: [(131.2, 118.4), (140.1, 121.6)]
    )

    /// On a Sunday morning this is the league with the hole: a receiver on his bye in
    /// the second slot, the one who should be there on the bench.
    private static func officeRedraft(_ scenario: Scenario) -> LeagueSpec {
        let starter = scenario == .morning ? "Rome Odunze" : "Nico Collins"
        let benched = scenario == .morning ? "Nico Collins" : "Rome Odunze"
        return LeagueSpec(
            id: "demo-espn", platform: .espn, name: "Office Redraft", kind: .ppr,
            teams: ["Kupp of Ambition", "Sacks and the City", "Lamb Chops", "Zero RB Club",
                    "Boom or Bust", "Monday Morning QBs"],
            mine: Lineup(
                starters: [(.qb, "Jayden Daniels"), (.rb, "Saquon Barkley"), (.rb, "Bucky Irving"),
                           (.wr, "CeeDee Lamb"), (.wr, starter), (.te, "George Kittle"),
                           (.flex, "Omarion Hampton"), (.k, "Cameron Dicker"), (.def, "DEF-PHI")],
                bench: [benched, "Chuba Hubbard", "Jake Ferguson"]
            ),
            theirs: Lineup(
                starters: [(.qb, "Joe Burrow"), (.rb, "Derrick Henry"), (.rb, "Christian McCaffrey"),
                           (.wr, "Malik Nabers"), (.wr, "Drake London"), (.te, "Sam LaPorta"),
                           (.flex, "James Cook"), (.k, "Harrison Butker"), (.def, "DEF-BAL")],
                bench: ["Terry McLaurin", "TreVeyon Henderson"]
            ),
            played: [(102.7, 128.9), (119.4, 96.0)]
        )
    }

    private static let hometownKeeper = LeagueSpec(
        id: "demo-fleaflicker", platform: .fleaflicker, name: "Hometown Keeper", kind: .standard,
        teams: ["Run CMC", "FumbleFree", "NorthernBlitz", "Hail Marys", "Tush Push", "The Replacements"],
        mine: Lineup(
            starters: [(.qb, "Lamar Jackson"), (.rb, "Christian McCaffrey"), (.rb, "James Cook"),
                       (.wr, "Jaxon Smith-Njigba"), (.wr, "Tee Higgins"), (.te, "Travis Kelce"),
                       (.flex, "Jahmyr Gibbs"), (.k, "Chris Boswell"), (.def, "DEF-SF")],
            bench: ["Zay Flowers", "Jonathan Taylor", "David Njoku"]
        ),
        theirs: Lineup(
            starters: [(.qb, "Jalen Hurts"), (.rb, "Bijan Robinson"), (.rb, "Breece Hall"),
                       (.wr, "Justin Jefferson"), (.wr, "A.J. Brown"), (.te, "Mark Andrews"),
                       (.flex, "Garrett Wilson"), (.k, "Ka'imi Fairbairn"), (.def, "DEF-DET")],
            bench: ["Jameson Williams", "Rashee Rice"]
        ),
        played: [(118.3, 104.9), (127.0, 112.2)]
    )

    // MARK: Points

    /// A final score against a projection: most land within reach of it, a few blow up
    /// or bust, and kickers never score forty.
    private static func finalPoints(_ player: PlayerRef, seed: String) -> Double {
        let proj = projection(player)
        let roll = unit(seed)
        let factor: Double
        switch roll {
        case ..<0.12: factor = 0.25 + roll               // a dud
        case ..<0.85: factor = 0.75 + (roll - 0.12) * 0.75
        default:      factor = 1.3 + (roll - 0.85) * 3   // a monster
        }
        return (proj * factor * 10).rounded() / 10
    }

    /// What a starter has banked given his game's state. A nil scenario is a played week.
    static func points(_ player: PlayerRef, week: Int, league: String, scenario: Scenario?) -> Double? {
        let seed = "\(league)/\(week)/\(player.name)"
        guard let scenario, week == DemoData.week else { return finalPoints(player, seed: seed) }
        guard let state = gameState(of: player.nflTeam, in: scenario) else { return 0 }
        switch state {
        case .post: return finalPoints(player, seed: seed)
        case .in:   return (finalPoints(player, seed: seed) * (0.35 + unit(seed + "q") * 0.3) * 10).rounded() / 10
        case .pre:  return 0
        }
    }

    // MARK: Rosters

    /// One week of one league, as the roster builder needs it.
    struct RosterContext {
        let league: LeagueSpec
        let week: Int
        /// Nil for a played week: every game is over.
        let scenario: Scenario?
        let schedule: ByeWeeks
    }

    private static func roster(_ lineup: Lineup, teamID: String, in context: RosterContext) -> Roster {
        func slot(_ kind: SlotKind, _ key: String, starter: Bool) -> RosterSlot {
            let player = ref(key)
            let bye = context.schedule.isOnBye(nflTeam: player.nflTeam, week: context.week)
            return RosterSlot(
                slot: kind, isStarter: starter, player: player,
                points: bye ? 0 : points(
                    player, week: context.week, league: context.league.id, scenario: context.scenario
                ),
                projectedPoints: starter && context.league.platform == .espn ? projection(player) : nil,
                isOnBye: bye
            )
        }
        let starters = lineup.starters.map { slot($0.0, $0.1, starter: true) }
        let bench = lineup.bench.map { slot(.bench, $0, starter: false) }
        return Roster(teamID: teamID, leagueID: context.league.id, week: context.week, slots: starters + bench)
    }

    /// A lineup for one of the other teams: nine starters dealt from what is left.
    private static func fillerLineup(index: Int, from filler: [PlayerRef]) -> Lineup {
        func pick(_ position: Position, _ nth: Int) -> String {
            let candidates = filler.filter { $0.position == position }
            return candidates[(index * 3 + nth) % candidates.count].name
        }
        let defenses = ["DEF-MIN", "DEF-BUF", "DEF-HOU", "DEF-KC", "DEF-SEA", "DEF-GB"]
        return Lineup(
            starters: [
                (.qb, pick(.qb, 0)), (.rb, pick(.rb, 0)), (.rb, pick(.rb, 1)),
                (.wr, pick(.wr, 0)), (.wr, pick(.wr, 1)), (.te, pick(.te, 0)),
                (.flex, pick(.wr, 2)), (.k, pick(.k, 0)), (.def, defenses[index % defenses.count]),
            ],
            bench: []
        )
    }

    private static func total(_ roster: Roster) -> Double {
        (roster.starters.reduce(0) { $0 + ($1.points ?? 0) } * 10).rounded() / 10
    }

    // MARK: Matchups

    private static let pairings: [Int: [(Int, Int)]] = [
        1: [(0, 2), (1, 3), (4, 6), (5, 7)],
        2: [(0, 3), (1, 2), (4, 7), (5, 6)],
        3: [(0, 1), (2, 3), (4, 5), (6, 7)],
    ]

    /// The season's matchups. Weeks 1 and 2 are scored; this week's scores are the
    /// lineups' running totals, so the card, the faceoff and the standings agree; the
    /// weeks after are fixtures, unscored, so "your season" has a road ahead.
    private static func matchups(_ spec: LeagueSpec, teamIDs: [String], rosters: [Roster]) -> [Matchup] {
        var matchups: [Matchup] = []
        for matchWeek in 1...week {
            for (home, away) in pairings[matchWeek] ?? [] where home < teamIDs.count && away < teamIDs.count {
                let scores: (Double, Double)
                if matchWeek == week {
                    scores = (total(rosters[home]), total(rosters[away]))
                } else if home == 0 {
                    scores = spec.played[matchWeek - 1]
                } else {
                    scores = (85 + (unit("\(spec.id)/\(matchWeek)/\(home)") * 600).rounded() / 10,
                              85 + (unit("\(spec.id)/\(matchWeek)/\(away)") * 600).rounded() / 10)
                }
                matchups.append(Matchup(
                    week: matchWeek, homeTeamID: teamIDs[home], awayTeamID: teamIDs[away],
                    homeScore: scores.0, awayScore: scores.1
                ))
            }
        }
        for futureWeek in (week + 1)...14 {
            let shift = futureWeek % (teamIDs.count - 1) + 1
            var seen: Set<Int> = []
            for home in teamIDs.indices where !seen.contains(home) {
                let away = (home + shift) % teamIDs.count
                guard !seen.contains(away), away != home else { continue }
                seen.formUnion([home, away])
                matchups.append(Matchup(
                    week: futureWeek, homeTeamID: teamIDs[home], awayTeamID: teamIDs[away], homeScore: 0, awayScore: 0
                ))
            }
        }
        return matchups
    }

    /// Records from the weeks that are actually over.
    private static func teams(_ spec: LeagueSpec, teamIDs: [String], decided: [Matchup]) -> [Team] {
        teamIDs.enumerated().map { index, teamID in
            let mine = decided.filter { $0.homeTeamID == teamID || $0.awayTeamID == teamID }
            let pointsAgainst = mine.reduce(0) { sum, matchup in
                sum + (matchup.opponentID(of: teamID).flatMap { matchup.score(for: $0) } ?? 0)
            }
            return Team(
                id: teamID, leagueID: spec.id, managerName: spec.teams[index], teamName: spec.teams[index],
                record: Record(
                    wins: mine.count { $0.winnerID == teamID },
                    losses: mine.count { $0.winnerID != nil && $0.winnerID != teamID }
                ),
                pointsFor: mine.reduce(0) { $0 + ($1.score(for: teamID) ?? 0) },
                pointsAgainst: pointsAgainst,
                isOwnedByUser: index == 0
            )
        }
    }

    // MARK: Build

    /// One number per rostered player, keyed the way the snapshot looks them up.
    private static func projections(for rosters: [Roster]) -> Projections {
        var values: [String: Double] = [:]
        for slot in rosters.flatMap(\.slots) {
            if let id = slot.player.canonicalID { values[id] = projection(slot.player) }
        }
        return Projections(week: week, byCanonicalID: values)
    }

    static func buildLeague(
        _ spec: LeagueSpec, scenario: Scenario, schedule: ByeWeeks, platformWeek: Int
    ) -> BuiltLeague {
        let league = League(
            id: spec.id, platform: spec.platform, name: spec.name, size: spec.teams.count,
            scoringKind: spec.kind, currentWeek: platformWeek, season: season, status: .inSeason,
            playoffWeekStart: 15
        )
        let teamIDs = spec.teams.indices.map { "\(spec.id)-t\($0)" }

        // This week's lineups: yours, your opponent's, and one dealt to everyone else.
        let used = Set((spec.mine.starters + spec.theirs.starters).map(\.1) + spec.mine.bench + spec.theirs.bench)
        let filler = fillerPool(excluding: used)
        let context = RosterContext(league: spec, week: week, scenario: scenario, schedule: schedule)
        let rosters = teamIDs.enumerated().map { index, teamID in
            roster(index == 0 ? spec.mine : index == 1 ? spec.theirs : fillerLineup(index: index, from: filler),
                   teamID: teamID, in: context)
        }
        let matchups = matchups(spec, teamIDs: teamIDs, rosters: rosters)
        let decided = matchups.filter { $0.week < platformWeek && ($0.homeScore > 0 || $0.awayScore > 0) }
        let teams = teams(spec, teamIDs: teamIDs, decided: decided)

        // Played weeks' lineups, for the outlook and for a player's season.
        let history = (1..<week).flatMap { pastWeek -> [Roster] in
            let past = RosterContext(league: spec, week: pastWeek, scenario: nil, schedule: schedule)
            return [roster(spec.mine, teamID: teamIDs[0], in: past), roster(spec.theirs, teamID: teamIDs[1], in: past)]
        }
        let thisWeek = matchups.filter { $0.week == week }

        let snapshot = LeagueSnapshot(
            league: league, week: week, teams: teams,
            myTeam: teams[0], opponent: teams[1],
            myRoster: rosters[0], opponentRoster: rosters[1],
            rosters: rosters,
            matchup: thisWeek.first { $0.homeTeamID == teamIDs[0] },
            currentMatchups: thisWeek,
            seasonMatchups: matchups,
            weeklyRosters: history,
            analytics: LeagueAnalyticsBuilder.build(league: league, teams: teams, matchups: decided),
            outlook: SeasonOutlookBuilder.build(weeklyRosters: history.filter { $0.teamID == teamIDs[0] }),
            projections: projections(for: rosters),
            schedule: schedule,
            syncState: .fresh(Date())
        )
        return BuiltLeague(
            league: league,
            snapshot: snapshot,
            weekRosters: LeagueWeekRosters(
                league: league, myTeamID: teamIDs[0], rosters: rosters, matchups: thisWeek,
                teamNames: Dictionary(uniqueKeysWithValues: teams.map { ($0.id, $0.displayName) })
            ),
            option: WeeklyModel.ScoringOption(
                leagueID: spec.id, name: spec.name, platform: spec.platform, rules: nil, kind: spec.kind
            )
        )
    }
}
#endif
