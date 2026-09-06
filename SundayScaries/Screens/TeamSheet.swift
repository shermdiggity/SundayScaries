import SwiftUI
import FantasyCore
import FantasyProviders

/// A team, in a half sheet. Opened from the power ranking, so you can look at whoever
/// just moved past you without leaving the league.
struct TeamSheet: View {
    let snapshot: LeagueSnapshot
    let teamID: String
    let model: WeeklyModel
    @State private var inspector = PlayerInspector()

    private var team: Team? { snapshot.teams.first { $0.id == teamID } }
    private var roster: Roster? { snapshot.rosters.first { $0.teamID == teamID } }
    private var analytics: TeamAnalytics? { snapshot.analytics?.team(teamID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SWSpacing.lg) {
                    if let analytics { stats(analytics) }

                    if let roster, !roster.starters.isEmpty {
                        Text("Starters")
                            .font(SWType.headline)
                            .foregroundStyle(SWColor.primary)
                        ForEach(Array(roster.starters.enumerated()), id: \.offset) { _, slot in
                            PlayerRow(slot: slot, in: snapshot, week: roster.week)
                        }

                        if !roster.bench.isEmpty {
                            Text("Bench")
                                .font(SWType.section)
                                .foregroundStyle(SWColor.secondary)
                                .padding(.top, SWSpacing.md)
                            ForEach(Array(roster.bench.enumerated()), id: \.offset) { _, slot in
                                PlayerRow(slot: slot, in: snapshot, week: roster.week)
                                    .opacity(0.72)
                            }
                        }
                    } else {
                        Text("No roster to show for this team.")
                            .font(SWType.body)
                            .foregroundStyle(SWColor.tertiary)
                    }
                }
                .padding(SWSpacing.lg)
            }
            .background {
                SWColor.canvas
                    .overlay(SWColor.leagueTint(snapshot.league.platform).opacity(0.5))
                    .ignoresSafeArea()
            }
            .navigationTitle(team?.displayName ?? "Team")
            .navigationBarTitleDisplayMode(.inline)
        }
        // Its own inspector: a sheet presented from a sheet must come from the top. And
        // the sheet is attached BEFORE the environment so that environment encloses it.
        .playerSheetHost(inspector, model: model, leagueID: snapshot.league.id)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .tint(SWColor.accent)
    }

    private func stats(_ analytics: TeamAnalytics) -> some View {
        VStack(alignment: .leading, spacing: SWSpacing.md) {
            HStack(spacing: SWSpacing.xl) {
                StatCell(value: "\(analytics.powerRank)", caption: "Power rank")
                StatCell(value: analytics.powerScore.formatted(SWFormat.score), caption: "Power points")
                StatCell(value: analytics.record.summary, caption: "Record")
            }
            HStack(spacing: SWSpacing.xl) {
                StatCell(value: analytics.allPlay.summary, caption: "All-play")
                StatCell(value: analytics.pointsFor.formatted(.number.precision(.fractionLength(0))), caption: "Points for")
                if let luck = analytics.luckIndex {
                    StatCell(value: luck.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always())), caption: "Luck")
                }
            }
        }
        .padding(SWSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SWRadius.md, style: .continuous)
                .fill(SWColor.surface)
        )
    }
}
