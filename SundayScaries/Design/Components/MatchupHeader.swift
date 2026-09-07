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

    /// Whose game this is. Yours puts you on the left with your name emphasised and the
    /// bar reading as YOUR odds; a neutral one is home on the left, both names equal, and
    /// the bar names the side it is describing.
    private enum Perspective { case mine, neutral }
    private let perspective: Perspective

    private let leftName: String
    private let rightName: String
    private let leftScore: Double
    private let rightScore: Double
    private let leftRoster: Roster?
    private let rightRoster: Roster?
    private let probability: Double?
    private let hasKickedOff: Bool

    /// Your matchup. Unchanged for every existing call site: the weekly card and the
    /// detail scoreboard render exactly what they did before pairs existed.
    init(snapshot: LeagueSnapshot, isExpanded: Bool = false) {
        self.snapshot = snapshot
        self.isExpanded = isExpanded
        perspective = .mine
        leftName = snapshot.myTeam?.displayName ?? "You"
        rightName = snapshot.opponent?.displayName ?? "—"
        leftScore = snapshot.myScore
        rightScore = snapshot.opponentScore
        leftRoster = snapshot.myRoster
        rightRoster = snapshot.opponentRoster
        probability = snapshot.winProbability
        hasKickedOff = snapshot.hasKickedOff
    }

    /// Anyone's matchup.
    init(snapshot: LeagueSnapshot, pair: LeagueSnapshot.MatchupPair, isExpanded: Bool = false) {
        self.snapshot = snapshot
        self.isExpanded = isExpanded
        perspective = .neutral
        leftName = pair.left?.displayName ?? "—"
        rightName = pair.right?.displayName ?? "—"
        leftScore = pair.leftScore
        rightScore = pair.rightScore
        leftRoster = pair.leftRoster
        rightRoster = pair.rightRoster
        // A finished game has a result, not odds.
        probability = pair.isFinal ? nil : snapshot.winProbability(for: pair)
        hasKickedOff = pair.hasKickedOff
    }

    private var faceSize: CGFloat { isExpanded ? SWSize.faceHero : SWSize.faceMatchup }
    /// The column the "vs." sits in. Every row keeps a gap this wide so faces, names and
    /// numbers line up down the middle.
    private var gutter: CGFloat { 30 }

    var body: some View {
        VStack(spacing: isExpanded ? SWSpacing.lg : SWSpacing.md) {
            // Laid out as ROWS spanning both sides, not as two independent columns.
            //
            // Each side used to be its own stack, and to keep the two projections level
            // when one team name wrapped, the name reserved two lines on both sides.
            // That reservation is what put a dead band between every one-line name and
            // its projection. A row shares its height across both sides by construction,
            // so a wrapped name pushes BOTH projections down together and a short one
            // reserves nothing.
            VStack(spacing: SWSpacing.sm) {
                HStack(spacing: SWSpacing.sm) {
                    faces(leftRoster)
                    Text("vs.")
                        .font(SWType.section)
                        .foregroundStyle(SWColor.tertiary)
                        .frame(width: gutter)
                    faces(rightRoster)
                }
                .frame(height: faceSize)

                HStack(alignment: .top, spacing: SWSpacing.sm) {
                    nameLabel(leftName, isLeft: true)
                    Color.clear.frame(width: gutter, height: 1)
                    nameLabel(rightName, isLeft: false)
                }

                HStack(alignment: .firstTextBaseline, spacing: SWSpacing.sm) {
                    projectionLabel(snapshot.projectedTotal(for: leftRoster))
                    Color.clear.frame(width: gutter, height: 1)
                    projectionLabel(snapshot.projectedTotal(for: rightRoster))
                }
            }

            if let probability {
                WinBar(probability: probability,
                       height: isExpanded ? 10 : 8,
                       isLive: hasKickedOff,
                       // A neutral bar has no "you", so it says whose odds these are.
                       subject: perspective == .neutral ? leftName : nil)
            }
        }
    }

    /// Three faces, side by side and ringed. Overlapping them buried the middle one and
    /// read as a pile rather than as a team.
    private func faces(_ roster: Roster?) -> some View {
        HStack(spacing: SWSpacing.xs) {
            ForEach(Array(topFaces(roster).enumerated()), id: \.offset) { _, player in
                Headshot(player: player, size: faceSize, strokeWidth: Headshot.ring)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func nameLabel(_ name: String, isLeft: Bool) -> some View {
        // Your name is the emphasised one in your own matchup. In someone else's there
        // is nobody to emphasise, so both read the same.
        let isMine = perspective == .neutral || isLeft
        return Text(name)
            .font(SWType.caption)
            .foregroundStyle(isMine ? SWColor.primary : SWColor.secondary)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func projectionLabel(_ projection: Double?) -> some View {
        if let projection {
            HStack(spacing: SWSpacing.xxs) {
                Text("proj").font(SWType.micro).foregroundStyle(SWColor.tertiary)
                Text(projection, format: SWFormat.score)
                    .font(isExpanded ? SWType.score : SWType.scoreCaption)
                    .foregroundStyle(SWColor.secondary)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
        } else {
            Color.clear.frame(height: 1).frame(maxWidth: .infinity)
        }
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
    @Environment(\.dynamicTypeSize) private var typeSize
    private var isAccessibilitySize: Bool { typeSize.isAccessibilitySize }
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

    private func side(_ progress: LineupProgress, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: SWSpacing.xxs) {
            // The points are the headline here; the counts qualify them.
            Text(progress.pointsScored, format: SWFormat.score)
                .font(isCompact ? SWType.score : SWType.scoreLarge)
                .foregroundStyle(SWColor.primary)
                .contentTransition(.numericText())

            if progress.isKnown {
                let counts = isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: alignment, spacing: SWSpacing.xs))
                    : AnyLayout(HStackLayout(spacing: SWSpacing.xs))
                counts {
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
            "\(progress.pointsScored.formatted(SWFormat.score)) points, \(progress.summary)"
        ))
    }

    private func count(_ value: Int, _ label: LocalizedStringKey, _ tone: Color) -> some View {
        HStack(spacing: SWSpacing.xxs) {
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
    /// Whose odds these are, when it is not obvious — "Shou Me The Money 62% to win".
    /// Nil in your own matchup, where "to win" already means you.
    var subject: String?

    var body: some View {
        VStack(spacing: SWSpacing.xs) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(SWColor.onSky.opacity(0.16))
                    Capsule()
                        .fill(
                            // Winning is green, losing is red. The old warm-to-orange
                            // ramp made a favourite look like a warning.
                            LinearGradient(
                                colors: probability >= 0.5
                                    ? [SWColor.positive.opacity(0.8), SWColor.positive]
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
                    Text((subject.map { "\($0) " } ?? "") + WinProbability.label(probability) + " to win")
                        .font(SWType.scoreCaption)
                        .foregroundStyle(probability >= 0.5 ? SWColor.positive : SWColor.negative)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
