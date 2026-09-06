import SwiftUI
import FantasyCore

/// Your score against theirs, as one proportional bar. Readable from across the room,
/// which is the entire requirement.
///
/// No labels: the name on the left is yours, the name on the right is theirs, and the
/// bar shows who is ahead. A tie renders as a genuine half, not a rounding artefact.
struct MatchupBar: View {
    let myName: String
    let myScore: Double
    let opponentName: String
    let opponentScore: Double
    var isLive: Bool = false

    private var total: Double { myScore + opponentScore }
    private var hasStarted: Bool { total > 0 }
    /// Before kickoff the bar is empty rather than half full — a half bar asserts a tie
    /// that has not happened.
    private var share: Double { hasStarted ? myScore / total : 0 }
    private var isAhead: Bool { myScore > opponentScore }

    var body: some View {
        VStack(spacing: SWSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(myScore, format: .number.precision(.fractionLength(1)))
                    .font(SWType.scoreLarge)
                    .foregroundStyle(SWColor.primary)
                Spacer(minLength: SWSpacing.md)
                Text(opponentScore, format: .number.precision(.fractionLength(1)))
                    .font(SWType.scoreLarge)
                    .foregroundStyle(isAhead ? SWColor.secondary : SWColor.primary)
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(SWColor.onSky.opacity(0.16))
                    if hasStarted {
                        Capsule(style: .continuous)
                            .fill(isAhead ? SWColor.accent : SWColor.onSky.opacity(0.42))
                            .frame(width: max(2, width * share))
                    }
                }
            }
            .frame(height: 6)
            .animation(SWMotion.standard, value: share)

            HStack {
                Text(myName)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: SWSpacing.md)
                Text(opponentName)
                    .lineLimit(2, reservesSpace: true)
                    .minimumScaleFactor(0.75)
            }
            .font(SWType.caption)
            .foregroundStyle(SWColor.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("\(myName) \(myScore.formatted(.number.precision(.fractionLength(1)))), \(opponentName) \(opponentScore.formatted(.number.precision(.fractionLength(1))))")
        )
    }
}

#Preview {
    VStack(spacing: SWSpacing.xl) {
        MatchupBar(myName: "You", myScore: 118.4, opponentName: "Mahomies", opponentScore: 102.1)
        MatchupBar(myName: "You", myScore: 74.2, opponentName: "Arctic9", opponentScore: 131.8)
        MatchupBar(myName: "You", myScore: 0, opponentName: "Not started", opponentScore: 0)
    }
    .padding(SWSpacing.xl)
    .background(SWColor.canvas)
}
