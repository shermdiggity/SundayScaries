import SwiftUI
import FantasyCore
import FantasyProviders

/// Someone else's matchup, in a half sheet: the scoreboard, then both starting lineups
/// opposed slot by slot. Opened from "Around the league" on the detail screen.
///
/// Nothing here is new UI. The scoreboard is `MatchupHeader` in its neutral perspective
/// and the lineups are `LineupFaceoff` — the same two blocks that show your own game at
/// the top of the detail screen, pointed at a different pair of teams. That is the point:
/// every matchup in the league reads the same way, whether or not you are in it.
struct MatchupSheet: View {
    let snapshot: LeagueSnapshot
    let pair: LeagueSnapshot.MatchupPair
    let model: WeeklyModel
    @Environment(\.dismiss) private var dismiss
    @State private var inspector = PlayerInspector(owner: "matchup")
    @State private var statLines: [String: [String: Double]] = [:]

    private var week: Int { pair.matchup.week }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SWSpacing.lg) {
                    VStack(spacing: SWSpacing.lg) {
                        let left = snapshot.progress(for: pair.leftRoster)
                        let right = snapshot.progress(for: pair.rightRoster)
                        if left.total > 0 || right.total > 0 {
                            ProgressRow(mine: left, theirs: right)
                        }
                        MatchupHeader(snapshot: snapshot, pair: pair, isExpanded: true)
                    }
                    .padding(SWSpacing.lg)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: SWRadius.md, style: .continuous)
                            .fill(SWColor.surface)
                    )

                    if let left = pair.leftRoster, !left.starters.isEmpty {
                        VStack(alignment: .leading, spacing: SWSpacing.md) {
                            HStack {
                                Text(pair.left?.displayName ?? "—")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("Starters")
                                    .frame(minWidth: SWSize.slotColumn)
                                Text(pair.right?.displayName ?? "—")
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .font(SWType.micro)
                            .foregroundStyle(SWColor.tertiary)
                            .lineLimit(1)
                            .accessibilityElement(children: .combine)

                            LineupFaceoff(
                                snapshot: snapshot, mine: left, theirs: pair.rightRoster, statLines: statLines
                            )
                        }
                        .padding(SWSpacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: SWRadius.md, style: .continuous)
                                .fill(SWColor.surface)
                        )
                        .task(id: "\(pair.leftScore)|\(pair.rightScore)") {
                            let players = (left.starters + (pair.rightRoster?.starters ?? [])).map(\.player)
                            statLines = await model.statLines(for: players, in: snapshot)
                        }
                    } else {
                        StateView(kind: .empty, title: "No lineups to show for this matchup yet.")
                    }
                }
                .padding(SWSpacing.lg)
            }
            .background {
                SWColor.canvas
                    .overlay(SWColor.leagueTint(snapshot.league.platform).opacity(0.5))
                    .ignoresSafeArea()
            }
            .navigationTitle("Week \(week)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        // Its own inspector: a sheet presented from a sheet must come from the top. And
        // the sheet is attached BEFORE the environment so that environment encloses it.
        .playerSheetHost(inspector, model: model, leagueID: snapshot.league.id)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .tint(SWColor.accent)
    }
}
