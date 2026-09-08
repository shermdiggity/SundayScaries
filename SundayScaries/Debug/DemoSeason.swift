#if DEBUG
import Foundation
import FantasyCore
import FantasyProviders

/// A demo player's season: weeks 1 and 2 as the league scored them, this week as far as
/// it has got, and the road ahead — through the real builder, so the sheet shows exactly
/// what it would.
extension DemoData {
    static func playerSeason(for player: PlayerRef, under snapshot: LeagueSnapshot, kind: ScoringKind) -> PlayerSeason {
        guard let scenario else { preconditionFailure("demo season outside demo mode") }
        var scored: [Int: Double] = [:]
        var projected: [Int: Double] = [:]
        var stats: [Int: [String: Double]] = [:]
        for pastWeek in 1...week {
            let value = points(player, week: pastWeek, league: snapshot.id, scenario: scenario) ?? 0
            let started = pastWeek < week || gameState(of: player.nflTeam, in: scenario) != .pre
            if started, value > 0 {
                scored[pastWeek] = value
                stats[pastWeek] = line(for: player, points: value, seed: "\(snapshot.id)/\(pastWeek)")
            }
            let drift = 0.85 + unit("\(pastWeek)/\(player.name)") * 0.3
            projected[pastWeek] = (projection(player) * drift * 10).rounded() / 10
        }
        projected[week] = projection(player)
        let peers = pool.values.count { $0.position == player.position }
        return PlayerSeasonBuilder.build(
            player: player, weeks: 1...18, stats: stats, projections: [:],
            leagueScored: scored, leagueProjected: projected, throughWeek: week,
            rules: nil, fallbackKind: kind, schedule: snapshot.schedule, now: Date(),
            positionRank: PositionRank(
                rank: 1 + Int(unit(player.name) * 6), of: max(peers, 24), position: player.position
            )
        )
    }

    /// A box-score line that could have produced the points.
    private static func line(for player: PlayerRef, points: Double, seed: String) -> [String: Double] {
        let roll = unit(seed + player.name)
        switch player.position {
        case .qb:
            return ["pass_cmp": 18 + (roll * 10).rounded(), "pass_att": 29 + (roll * 12).rounded(),
                    "pass_yd": (150 + points * 8).rounded(), "pass_td": (points / 8).rounded(.down),
                    "rush_yd": (roll * 40).rounded()]
        case .rb:
            let receptions = 2 + (roll * 4).rounded()
            return ["rush_att": 12 + (roll * 10).rounded(), "rush_yd": (points * 5).rounded(),
                    "rush_td": points > 16 ? 1 : 0, "rec": receptions, "rec_yd": receptions * 8]
        case .wr, .te:
            let receptions = 3 + (roll * 6).rounded()
            return ["rec": receptions, "rec_tgt": receptions + 2 + (roll * 3).rounded(),
                    "rec_yd": (points * 6).rounded(), "rec_td": points > 17 ? 1 : 0]
        case .k:
            let made = (points / 3.5).rounded(.down)
            return ["fgm": made, "fga": made + (roll > 0.7 ? 1 : 0), "xpm": 2, "xpa": 2]
        case .def:
            return ["pts_allow": 24 - (points * 1.2).rounded(), "sack": (roll * 5).rounded(), "int": roll > 0.5 ? 1 : 0]
        case .other:
            return [:]
        }
    }
}
#endif
