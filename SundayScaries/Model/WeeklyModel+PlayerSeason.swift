import Foundation
import FantasyCore
import FantasyProviders

/// A player's season, read under any visible league's rules. The sheet's whole data path.
extension WeeklyModel {
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

    /// What the picker shows. A league you have put away is not one you want to score by.
    var visibleScoringOptions: [ScoringOption] {
        scoringOptions.filter { !hiddenLeagueIDs.contains($0.leagueID) }
    }

    /// This week's box-score line for each player, by canonical id, for the lineup rows.
    ///
    /// Read through the same season path the sheet uses, so the feed is fetched once per
    /// week and cached, and a second league's lineup costs dictionary lookups. A player
    /// whose game has not started, or who is not in the feed, has no entry.
    func statLines(for players: [PlayerRef], in snapshot: LeagueSnapshot) async -> [String: [String: Double]] {
        let week = snapshot.week
        let leagueID = snapshot.id
        return await withTaskGroup(of: (String, [String: Double])?.self) { group in
            for player in players {
                guard let id = player.canonicalID else { continue }
                group.addTask { [self] in
                    guard let season = await playerSeason(for: player, under: leagueID),
                          let line = season.weeks.first(where: { $0.week == week })?.stats,
                          line.values.contains(where: { $0 != 0 }) else { return nil }
                    return (id, line)
                }
            }
            var lines: [String: [String: Double]] = [:]
            for await entry in group {
                if let (id, line) = entry { lines[id] = line }
            }
            return lines
        }
    }

    /// Every week of this player's season, scored under one league's rules.
    ///
    /// The league's own points win whenever it scored him itself — a roster he was on
    /// there, any week. Otherwise his raw public stats are scored under that league's
    /// rules. The stats and projections come from one league-agnostic feed and are
    /// cached per week, so the first sheet of the day fetches and the rest are instant.
    func playerSeason(for player: PlayerRef, under leagueID: String) async -> PlayerSeason? {
        guard let snapshot = allSnapshots.first(where: { $0.id == leagueID }) else { return nil }
        let option = scoringOptions.first { $0.leagueID == leagueID }
        #if DEBUG
        if DemoData.isActive {
            let kind = option?.kind ?? snapshot.league.scoringKind
            return DemoData.playerSeason(for: player, under: snapshot, kind: kind)
        }
        #endif
        guard let playerSeasons else { return nil }
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

        return await playerSeasons.season(
            for: player, season: season, weeks: weeks, throughWeek: currentWeek,
            leagueScored: leagueScored, leagueProjected: leagueProjected,
            rules: option?.rules, fallbackKind: option?.kind ?? snapshot.league.scoringKind,
            schedule: snapshot.schedule
        )
    }
}
