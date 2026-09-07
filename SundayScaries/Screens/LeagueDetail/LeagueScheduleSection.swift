import SwiftUI
import FantasyCore
import FantasyProviders

/// Every week of your schedule: the result where it has been played, the opponent
/// where it has not. Tap a week to open that matchup — past weeks with the lineups
/// that actually played, future ones with the two teams.
struct LeagueScheduleSection: View {
    let snapshot: LeagueSnapshot
    let onSelect: (LeagueSnapshot.MatchupPair) -> Void

    /// The columns every row holds so its neighbours align: "Week 12", a W or an L.
    private static let weekColumn: CGFloat = 60
    private static let resultColumn: CGFloat = 16

    var body: some View {
        let schedule = snapshot.mySchedule
        if !schedule.isEmpty {
            VStack(alignment: .leading, spacing: SWSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Your season")
                        .font(SWType.headline)
                        .foregroundStyle(SWColor.primary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if let team = snapshot.myTeam {
                        Text(team.record.summary)
                            .font(SWType.scoreCaption)
                            .foregroundStyle(SWColor.secondary)
                    }
                }

                // Rows, spaced. No rule between them: the week numbers down the left
                // already read as a column.
                VStack(spacing: 0) {
                    ForEach(schedule) { entry in
                        Button {
                            onSelect(entry.pair)
                        } label: {
                            scheduleRow(entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(SWSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(SWColor.leagueTint(snapshot.league.platform)),
                         in: .rect(cornerRadius: SWRadius.lg))
        }
    }

    private func scheduleRow(_ entry: LeagueSnapshot.ScheduleEntry) -> some View {
        let format = SWFormat.score
        return HStack(alignment: .firstTextBaseline, spacing: SWSpacing.md) {
            Text("Week \(entry.week)")
                .font(SWType.scoreCaption)
                .foregroundStyle(entry.isCurrent ? SWColor.accent : SWColor.tertiary)
                .monospacedDigit()
                .frame(minWidth: Self.weekColumn, alignment: .leading)

            Text(entry.opponent?.displayName ?? "—")
                .font(SWType.bodyMedium)
                .foregroundStyle(SWColor.primary)
                .lineLimit(1)

            Spacer(minLength: SWSpacing.sm)

            if let won = entry.won {
                // Result first, because that is what a schedule is for.
                Text(won ? "W" : "L")
                    .font(SWType.scoreCaption)
                    .foregroundStyle(won ? SWColor.positive : SWColor.negative)
                    .frame(minWidth: Self.resultColumn)
                Text("\(entry.myScore.formatted(format)) – \(entry.theirScore.formatted(format))")
                    .font(SWType.scoreCaption)
                    .foregroundStyle(SWColor.secondary)
                    .monospacedDigit()
            } else if entry.isCurrent {
                Text(entry.pair.hasKickedOff
                    ? "\(entry.myScore.formatted(format)) – \(entry.theirScore.formatted(format))"
                    : "This week")
                    .font(SWType.scoreCaption)
                    .foregroundStyle(SWColor.accent)
                    .monospacedDigit()
            } else {
                Image(systemName: "chevron.right")
                    .font(SWType.glyph)
                    .foregroundStyle(SWColor.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, SWSpacing.sm)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
