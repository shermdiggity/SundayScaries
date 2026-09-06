import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// A widget with no snapshot behind it yet: the app has never loaded.
    var isEmpty: Bool { snapshot.leagues.isEmpty }
}

/// Reads what the app last wrote. The timeline asks to be re-read every ten minutes while
/// a game is on and every hour otherwise; the app also reloads every widget the moment a
/// load finishes, so the common case is fresher than either.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        if context.isPreview {
            completion(SnapshotEntry(date: .now, snapshot: WidgetStore.load() ?? .sample))
        } else {
            completion(SnapshotEntry(date: .now, snapshot: WidgetStore.load() ?? .empty))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = WidgetStore.load() ?? .empty
        let entry = SnapshotEntry(date: .now, snapshot: snapshot)
        let next = Date.now.addingTimeInterval(snapshot.liveNow ? 10 * 60 : 60 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

extension WidgetSnapshot {
    /// For the gallery and placeholders only. Names are generic on purpose: a widget
    /// preview must not invent real people.
    static let sample = WidgetSnapshot(
        generatedAt: .now, week: 3, liveNow: true,
        leagues: [
            WidgetLeague(id: "a", name: "Sunday Funday", platform: "sleeper", isLineupSet: true, issueCount: 0, hasMatchup: true,
                         myName: "Your team", myScore: 87.4, myProjected: 121.3, mySummary: "5 played · 4 to play",
                         opponentName: "Opponent", opponentScore: 64.1, opponentProjected: 109.8, opponentSummary: "4 played · 5 to play",
                         winProbability: 0.63, isLive: true, isFinal: false),
            WidgetLeague(id: "b", name: "Average Joes", platform: "espn", isLineupSet: false, issueCount: 2, hasMatchup: true,
                         myName: "Your team", myScore: 0, myProjected: 118.0, mySummary: "9 to play",
                         opponentName: "Opponent", opponentScore: 0, opponentProjected: 112.5, opponentSummary: "9 to play",
                         winProbability: 0.54, isLive: false, isFinal: false),
            WidgetLeague(id: "c", name: "Dynasty", platform: "myFantasyLeague", isLineupSet: true, issueCount: 0, hasMatchup: true,
                         myName: "Your team", myScore: 102.2, myProjected: 130.1, mySummary: "7 played · 3 to play",
                         opponentName: "Opponent", opponentScore: 96.7, opponentProjected: 128.4, opponentSummary: "6 played · 4 to play",
                         winProbability: 0.51, isLive: true, isFinal: false),
        ],
        yourGuys: [
            WidgetPlayer(id: "1", name: "Quarterback", position: "QB", team: "KC", value: 24.1, isProjected: false, leagueCount: 3, totalLeagues: 3, kickoff: nil, headshotFile: nil),
            WidgetPlayer(id: "2", name: "Running Back", position: "RB", team: "SF", value: 17.8, isProjected: true, leagueCount: 2, totalLeagues: 3, kickoff: "Sun 4:25 PM", headshotFile: nil),
            WidgetPlayer(id: "3", name: "Wide Receiver", position: "WR", team: "DET", value: 15.2, isProjected: true, leagueCount: 2, totalLeagues: 3, kickoff: "Sun 1:00 PM", headshotFile: nil),
            WidgetPlayer(id: "4", name: "Tight End", position: "TE", team: "LV", value: 9.6, isProjected: true, leagueCount: 2, totalLeagues: 3, kickoff: "Sun 4:05 PM", headshotFile: nil),
        ],
        upAgainst: [
            WidgetPlayer(id: "5", name: "Running Back", position: "RB", team: "PHI", value: 21.0, isProjected: false, leagueCount: 2, totalLeagues: 3, kickoff: nil, headshotFile: nil),
            WidgetPlayer(id: "6", name: "Wide Receiver", position: "WR", team: "MIA", value: 16.4, isProjected: true, leagueCount: 2, totalLeagues: 3, kickoff: "Sun 1:00 PM", headshotFile: nil),
            WidgetPlayer(id: "7", name: "Quarterback", position: "QB", team: "BUF", value: 22.9, isProjected: true, leagueCount: 1, totalLeagues: 3, kickoff: "Mon 8:15 PM", headshotFile: nil),
            WidgetPlayer(id: "8", name: "Defense", position: "DEF", team: "BAL", value: 8.0, isProjected: true, leagueCount: 1, totalLeagues: 3, kickoff: "Sun 1:00 PM", headshotFile: nil),
        ]
    )
}
