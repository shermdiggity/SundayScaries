import SwiftUI
import FantasyCore
import FantasyProviders

/// One week of a player's season: the opponent, the box-score line, and what it was
/// worth. An estimate is the same number, dimmed. Nothing else changes.
struct PlayerWeekRow: View {
    let week: PlayerWeek
    let isCurrent: Bool
    let position: Position

    var body: some View {
        let line = StatLine.summary(week.stats, position: position)
        HStack(alignment: .firstTextBaseline, spacing: SWSpacing.md) {
            Text("\(week.week)")
                .font(SWType.scoreCaption)
                .foregroundStyle(isCurrent ? SWColor.accent : SWColor.tertiary)
                .frame(minWidth: SWSpacing.xl, alignment: .leading)

            VStack(alignment: .leading, spacing: SWSpacing.xxs) {
                Text(week.isBye ? "Bye" : (week.opponent ?? "—"))
                    .font(SWType.bodyMedium)
                    .foregroundStyle(week.isBye ? SWColor.tertiary : SWColor.primary)
                if !line.isEmpty {
                    Text(line)
                        .font(SWType.micro)
                        .foregroundStyle(SWColor.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }

            Spacer(minLength: SWSpacing.sm)

            VStack(alignment: .trailing, spacing: SWSpacing.xxs) {
                if let actual = week.actual {
                    // An estimate is the same number, quieter. Nothing else changes.
                    Text(actual.points, format: SWFormat.score)
                        .font(SWType.score)
                        .foregroundStyle(actual.isExact ? tone(week) : SWColor.tertiary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if let projected = week.projected {
                        Text("proj \(projected.points.formatted(SWFormat.score))")
                            .font(SWType.micro)
                            .foregroundStyle(SWColor.tertiary)
                    }
                } else if let projected = week.projected {
                    Text("proj \(projected.points.formatted(SWFormat.score))")
                        .font(SWType.scoreCaption)
                        .foregroundStyle(SWColor.secondary)
                }
            }
        }
        .padding(.vertical, SWSpacing.sm)
        .opacity(week.isBye ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }

    /// The colour says one thing only: did they beat their projection.
    private func tone(_ week: PlayerWeek) -> Color {
        guard let actual = week.actual, let projected = week.projected else { return SWColor.primary }
        return actual.points >= projected.points ? SWColor.positive : SWColor.negative
    }
}
