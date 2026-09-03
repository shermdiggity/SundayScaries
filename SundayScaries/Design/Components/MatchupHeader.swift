import SwiftUI
import FantasyCore
import FantasyProviders

/// The matchup, as one block: two faces, two names, two numbers, and how likely you
/// are to win. Shared by the weekly card and the top of the detail screen, so the zoom
/// transition lands on the same thing it left — which is what makes it feel continuous
/// rather than like two different screens stitched together.
struct MatchupHeader: View {
    let snapshot: LeagueSnapshot
    /// The detail screen gets more room and larger type.
    var isExpanded: Bool = false

    private var faceSize: CGFloat { isExpanded ? 44 : 34 }

    var body: some View {
        VStack(spacing: isExpanded ? SWSpacing.lg : SWSpacing.md) {
            HStack(alignment: .top, spacing: SWSpacing.sm) {
                side(name: snapshot.myTeam?.displayName ?? "You",
                     score: snapshot.myScore,
                     projection: snapshot.projectedTotal(for: snapshot.myRoster),
                     roster: snapshot.myRoster,
                     isMine: true)

                Text("vs.")
                    .font(SWType.section)
                    .foregroundStyle(SWColor.tertiary)
                    .padding(.top, faceSize / 2 - 10)

                side(name: snapshot.opponent?.displayName ?? "—",
                     score: snapshot.opponentScore,
                     projection: snapshot.projectedTotal(for: snapshot.opponentRoster),
                     roster: snapshot.opponentRoster,
                     isMine: false)
            }

            if let probability = snapshot.winProbability {
                WinBar(probability: probability,
                       height: isExpanded ? 10 : 8,
                       isLive: snapshot.hasKickedOff)
            }
        }
    }

    private func side(name: String, score: Double, projection: Double?, roster: Roster?, isMine: Bool) -> some View {
        VStack(spacing: SWSpacing.sm) {
            // Three faces, side by side and ringed. Overlapping them buried the middle
            // one and read as a pile rather than as a team.
            HStack(spacing: SWSpacing.xs) {
                ForEach(Array(topFaces(roster).enumerated()), id: \.offset) { _, player in
                    Headshot(player: player, size: faceSize, strokeWidth: 2.5)
                }
            }
            .frame(height: faceSize)

            Text(name)
                .font(SWType.caption)
                .foregroundStyle(isMine ? SWColor.primary : SWColor.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let projection {
                HStack(spacing: 3) {
                    Text("proj").font(SWType.micro).foregroundStyle(SWColor.tertiary)
                    Text(projection, format: .number.precision(.fractionLength(1)))
                        .font(isExpanded ? SWType.score : SWType.scoreCaption)
                        .foregroundStyle(SWColor.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The three highest-scoring (or highest-projected) starters — the faces that
    /// actually decide the week.
    private func topFaces(_ roster: Roster?) -> [PlayerRef] {
        guard let roster else { return [] }
        return roster.starters
            .filter { !$0.player.isEmptyLineupSlot }
            .sorted { lhs, rhs in
                let l = lhs.points ?? snapshot.projections.projection(for: lhs.player) ?? 0
                let r = rhs.points ?? snapshot.projections.projection(for: rhs.player) ?? 0
                return l > r
            }
            .prefix(3)
            .map(\.player)
    }

}

/// How far through the week each side is, above the matchup it qualifies.
///
/// This sits first because it changes the meaning of everything under it: a twenty
/// point lead with four players left is a different situation from the same lead with
/// none, and you should know which before you read the score.
struct ProgressRow: View {
    let mine: LineupProgress
    let theirs: LineupProgress
    var isCompact: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: SWSpacing.sm) {
            side(mine, alignment: .leading)
            Rectangle()
                .fill(SWColor.hairline)
                .frame(width: 1, height: isCompact ? 18 : 22)
            side(theirs, alignment: .trailing)
        }
        .padding(.vertical, isCompact ? SWSpacing.xs : SWSpacing.sm)
        .padding(.horizontal, SWSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: SWRadius.sm, style: .continuous)
                .fill(SWColor.primary.opacity(0.07))
        )
    }

    @ViewBuilder
    private func side(_ progress: LineupProgress, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            // The points are the headline here; the counts qualify them.
            Text(progress.pointsScored, format: .number.precision(.fractionLength(1)))
                .font(isCompact ? SWType.score : SWType.scoreLarge)
                .foregroundStyle(SWColor.primary)
                .contentTransition(.numericText())

            if progress.isKnown {
                HStack(spacing: SWSpacing.xs) {
                    if progress.finished > 0 { count(progress.finished, "played", SWColor.secondary) }
                    if progress.inProgress > 0 { count(progress.inProgress, "playing", SWColor.live) }
                    if progress.yetToPlay > 0 { count(progress.yetToPlay, "to play", SWColor.accent) }
                }
                if progress.notPlaying > 0 {
                    Text("\(progress.notPlaying) on bye")
                        .font(SWType.micro)
                        .foregroundStyle(SWColor.warning)
                }
            } else {
                Text("Not started yet")
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(
            "\(progress.pointsScored.formatted(.number.precision(.fractionLength(1)))) points, \(progress.summary)"
        ))
    }

    private func count(_ value: Int, _ label: String, _ tone: Color) -> some View {
        HStack(spacing: 2) {
            Text("\(value)")
                .font(SWType.scoreMicro)
                .foregroundStyle(tone)
            Text(label)
                .font(SWType.micro)
                .foregroundStyle(SWColor.tertiary)
        }
    }
}

/// One bar, split at the odds. Your share is warm; theirs is quiet. Shared by the
/// league card and the detail screen's collapsed bar so the same fact looks the same
/// wherever it appears.
struct WinBar: View {
    let probability: Double
    var height: CGFloat = 8
    var showsLabel: Bool = true
    var isLive: Bool = false

    var body: some View {
        VStack(spacing: SWSpacing.xs) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(SWColor.onSky.opacity(0.16))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: probability >= 0.5
                                    ? [SWColor.accent, SWColor.warning]
                                    : [SWColor.negative.opacity(0.75), SWColor.negative],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geometry.size.width * probability))
                }
            }
            .frame(height: height)
            .animation(SWMotion.standard, value: probability)

            if showsLabel {
                HStack {
                    Text(WinProbability.label(probability) + " to win")
                        .font(SWType.scoreCaption)
                        .foregroundStyle(probability >= 0.5 ? SWColor.accent : SWColor.negative)
                    Spacer()
                    if isLive {
                        Text("Live").font(SWType.micro).foregroundStyle(SWColor.live)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(WinProbability.label(probability)) chance to win"))
    }
}
