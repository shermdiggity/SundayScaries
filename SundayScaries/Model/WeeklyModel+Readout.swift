import Foundation
import FantasyCore
import FantasyProviders

/// What the weekly view reads off the loaded snapshots: who is carrying your week, who
/// is coming for it, what a player is worth right now. Pure functions of `snapshots`
/// and `positions`; nothing here fetches.
extension WeeklyModel {
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
            let state = snapshot.schedule.gameState(nflTeam: player.nflTeam, week: snapshot.week)
            guard state == .inProgress || state == .final else { continue }
            let scored = snapshot.rosters
                .flatMap(\.slots)
                .first { $0.player.canonicalID == player.canonicalID }?
                .points
            if let scored { return (scored, false) }
        }
        return (projection(for: player), true)
    }

    func kickoff(for player: PlayerRef) -> String? {
        for snapshot in snapshots {
            if let label = snapshot.schedule.kickoffLabel(
                nflTeam: player.nflTeam, week: snapshot.week
            ) { return label }
        }
        return nil
    }

    /// Whether any starter in any visible league is in a game right now. Drives the
    /// live poll: while this is true the app refreshes itself; while it is false nothing
    /// runs.
    ///
    /// Asked of the LIVE week. The reader may be looking at last week's finals while a
    /// game is on; the poll and the foreground refresh still need to run.
    var hasLiveGame: Bool {
        snapshots.contains { snapshot in
            let week = liveWeek ?? snapshot.week
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
}
