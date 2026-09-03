import SwiftUI
import FantasyCore
import FantasyProviders

/// A team, in a half sheet. Opened from the power ranking, so you can look at whoever
/// just moved past you without leaving the league.
struct TeamSheet: View {
    let snapshot: LeagueSnapshot
    let teamID: String

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
                            PlayerRow(
                                slot: slot,
                                projection: snapshot.projections.projection(for: slot.player),
                                nflMatchup: snapshot.schedule.opponentLabel(
                                    nflTeam: slot.player.nflTeam, week: roster.week
                                ),
                                hasStarted: snapshot.schedule.gameState(
                                    nflTeam: slot.player.nflTeam, week: roster.week
                                ) != .notStarted,
                                kickoff: snapshot.schedule.kickoffLabel(
                                    nflTeam: slot.player.nflTeam, week: roster.week
                                )
                            )
                        }

                        if !roster.bench.isEmpty {
                            Text("Bench")
                                .font(SWType.section)
                                .foregroundStyle(SWColor.secondary)
                                .padding(.top, SWSpacing.md)
                            ForEach(Array(roster.bench.enumerated()), id: \.offset) { _, slot in
                                PlayerRow(
                                    slot: slot,
                                    projection: snapshot.projections.projection(for: slot.player),
                                    nflMatchup: snapshot.schedule.opponentLabel(
                                        nflTeam: slot.player.nflTeam, week: roster.week
                                    ),
                                    hasStarted: snapshot.schedule.gameState(
                                        nflTeam: slot.player.nflTeam, week: roster.week
                                    ) != .notStarted,
                                    kickoff: snapshot.schedule.kickoffLabel(
                                        nflTeam: slot.player.nflTeam, week: roster.week
                                    )
                                )
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .tint(SWColor.accent)
    }

    private func stats(_ analytics: TeamAnalytics) -> some View {
        VStack(alignment: .leading, spacing: SWSpacing.md) {
            HStack(spacing: SWSpacing.xl) {
                stat("\(analytics.powerRank)", "Power rank")
                stat(analytics.powerScore.formatted(.number.precision(.fractionLength(1))), "Power points")
                stat(analytics.record.summary, "Record")
            }
            HStack(spacing: SWSpacing.xl) {
                stat(analytics.allPlay.summary, "All-play")
                stat(analytics.pointsFor.formatted(.number.precision(.fractionLength(0))), "Points for")
                if let luck = analytics.luckIndex {
                    stat(luck.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always())), "Luck")
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

    private func stat(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(SWType.score)
                .foregroundStyle(SWColor.primary)
            Text(caption)
                .font(SWType.micro)
                .foregroundStyle(SWColor.tertiary)
        }
        .accessibilityElement(children: .combine)
    }
}
