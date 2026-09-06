import Foundation
import UIKit
import WidgetKit
import FantasyCore

/// Turns the model's state into the widget snapshot and tells WidgetKit. Called at the end
/// of every load, so the widgets are never staler than the last thing the app knew.
enum WidgetBridge {
    @MainActor
    static func publish(from model: WeeklyModel) async {
        let leagues: [WidgetLeague] = model.snapshots.map { snapshot in
            let mine = snapshot.progress
            let theirs = snapshot.opponentProgress
            return WidgetLeague(
                id: snapshot.league.id,
                name: snapshot.league.name,
                platform: snapshot.league.platform.rawValue,
                isLineupSet: snapshot.isLineupSet,
                issueCount: snapshot.issues.count,
                hasMatchup: snapshot.opponent != nil,
                myName: snapshot.myTeam?.displayName,
                myScore: snapshot.myScore,
                myProjected: snapshot.projectedTotal(for: snapshot.myRoster),
                mySummary: mine.summary,
                opponentName: snapshot.opponent?.displayName,
                opponentScore: snapshot.opponentScore,
                opponentProjected: snapshot.projectedTotal(for: snapshot.opponentRoster),
                opponentSummary: theirs.summary,
                winProbability: snapshot.winProbability,
                isLive: mine.inProgress > 0 || theirs.inProgress > 0,
                isFinal: mine.isKnown && mine.yetToPlay == 0 && mine.inProgress == 0
            )
        }

        func players(_ positions: [PlayerPosition], count: (PlayerPosition) -> Int) async -> [WidgetPlayer] {
            var result: [WidgetPlayer] = []
            for position in positions.prefix(8) {
                let player = position.player
                let points = model.points(for: player)
                result.append(WidgetPlayer(
                    id: position.id,
                    name: player.name,
                    position: player.position.rawValue,
                    team: player.nflTeam,
                    value: points.value,
                    isProjected: points.isProjected,
                    leagueCount: count(position),
                    totalLeagues: position.totalLeagues,
                    kickoff: model.kickoff(for: player),
                    headshotFile: await headshotFile(for: player, id: position.id)
                ))
            }
            return result
        }

        let snapshot = WidgetSnapshot(
            generatedAt: Date(),
            week: model.week ?? 0,
            liveNow: model.hasLiveGame,
            leagues: leagues,
            yourGuys: await players(model.yourGuys()) { $0.startedCount },
            upAgainst: await players(model.upAgainst()) { $0.facedCount }
        )
        WidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Copies a small headshot into the container, where the widget can read it without a
    /// network. Already-present files are kept; a face does not change week to week.
    @MainActor
    private static func headshotFile(for player: PlayerRef, id: String) async -> String? {
        guard let url = player.headshotURL, let directory = WidgetStore.headshotsDirectory else { return nil }
        let file = id.replacingOccurrences(of: "/", with: "_") + ".png"
        let destination = directory.appendingPathComponent(file)
        if FileManager.default.fileExists(atPath: destination.path) { return file }
        guard let image = await ImageCache.shared.load(url) else { return nil }
        let side: CGFloat = 96
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let small = renderer.image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        guard let data = small.pngData() else { return nil }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: destination, options: .atomic)
        return file
    }
}
