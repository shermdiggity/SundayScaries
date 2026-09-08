import SwiftUI
import FantasyCore

/// One league on the weekly view.
///
/// Built from the same `MatchupHeader` that opens the detail screen, so tapping a card
/// grows it into the thing it already looked like. The chrome around it answers the
/// two questions you have at a glance: is my lineup set, and where does this league
/// live.
struct LeagueCard: View {
    let snapshot: LeagueSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: SWSpacing.md) {
            header

            switch state {
            case .failed:
                note("Couldn't refresh this league.", tone: SWColor.negative)
            case .undrafted:
                note(snapshot.isPreDraftCarryover
                    ? "Not drafted yet — last season's keepers"
                    : "Not drafted yet", tone: SWColor.secondary)
            case .noTeam:
                note("No team of yours in this league", tone: SWColor.tertiary)
            case .noMatchup:
                note(snapshot.league.status == .complete ? "Season complete" : "No matchup this week",
                     tone: SWColor.secondary)
            case .live, .upcoming:
                progressLine
                MatchupHeader(snapshot: snapshot)
            }
        }
        .padding(SWSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .leagueSurface(snapshot.league.platform)
        .contentShape(.rect(cornerRadius: SWRadius.lg))
    }

    private enum State { case failed, undrafted, noTeam, noMatchup, upcoming, live }

    private var state: State {
        if case .failed = snapshot.syncState { return .failed }
        if !snapshot.league.status.hasDrafted { return .undrafted }
        guard snapshot.myTeam != nil else { return .noTeam }
        guard snapshot.opponent != nil else { return .noMatchup }
        return snapshot.hasKickedOff ? .live : .upcoming
    }

    /// First place is the one standing worth colouring, and it gets the app's one
    /// accent. Every league used to pick its own hue from six by hashing its id, which
    /// put a pink 4th beside a teal 7th beside an orange 2nd: colour that meant nothing
    /// and fought the platform tint under it.
    private var standingTone: Color {
        snapshot.standing == 1 ? SWColor.accent : SWColor.secondary
    }

    private var header: some View {
        // Top-aligned, so the mark and the lineup check sit on the title line rather
        // than floating in the middle of a three-line block.
        HStack(alignment: .top, spacing: SWSpacing.sm) {
            PlatformMark(platform: snapshot.league.platform)
                .padding(.top, SWSpacing.xxs)

            // Title, subtitle, record. Your team is the title; the league it plays in
            // is the line under it, smaller and quieter. They used to share one line
            // ("Kupp of Ambition · Sigma Alpha Epsilon Keeper Dynasty") with a second
            // line reserved for the wrap, which left a dead band under every pair short
            // enough to fit on one. Each line is real now, so there is nothing to
            // reserve and nothing to gap.
            VStack(alignment: .leading, spacing: SWSpacing.xxs) {
                Text(title)
                    .font(SWType.cardTitle)
                    .foregroundStyle(SWColor.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)

                if let subtitle {
                    Text(subtitle)
                        .font(SWType.caption)
                        .foregroundStyle(SWColor.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if let team = snapshot.myTeam {
                    HStack(spacing: SWSpacing.xs) {
                        Text(team.record.summary)
                            .accessibilityLabel(Text("Record \(team.record.summary)"))
                        if let standing = snapshot.standing {
                            Text(Self.ordinal(standing)).foregroundStyle(standingTone)
                                .accessibilityLabel(Text("\(Self.ordinal(standing)) place"))
                        }
                    }
                    .font(SWType.scoreCaption)
                    .foregroundStyle(SWColor.secondary)
                }
            }

            Spacer(minLength: SWSpacing.xs)

            if snapshot.league.status.hasDrafted, snapshot.myTeam != nil {
                LineupCheck(isSet: snapshot.isLineupSet, issueCount: snapshot.issues.count)
            }
        }
    }

    /// Your team, or the league itself when you have no team in it.
    private var title: String {
        snapshot.myTeam?.displayName ?? snapshot.league.name
    }

    /// The league, under your team. Nil when the league is already the title.
    private var subtitle: String? {
        snapshot.myTeam == nil ? nil : snapshot.league.name
    }

    @ViewBuilder
    private var progressLine: some View {
        let mine = snapshot.progress
        if mine.total > 0 {
            ProgressRow(mine: mine, theirs: snapshot.opponentProgress, isCompact: true)
        }
    }

    private func note(_ text: String, tone: Color) -> some View {
        Text(text)
            .font(SWType.body)
            .foregroundStyle(tone)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, SWSpacing.sm)
    }

    static func ordinal(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

/// A pane of tinted glass, lit from one side, without a backdrop blur.
///
/// This was `.glassEffect`, and that is what caused the flicker when returning from a
/// league. Glass samples and blurs whatever is behind it, and the zoom transition
/// snapshots the source card's raster: at the moment the system hands the snapshot back
/// to the live view, the glass has to re-resolve its backdrop, and that one frame is
/// visible. Plain alpha blending has nothing to re-resolve — and it costs nothing on
/// scroll over the animated sky, where a material would re-blur every frame.
///
/// What makes a sheet of glass read as glass is not the blur, it is the light: a sheen
/// raked across it from one direction, a cut edge that catches that light along the top
/// and goes dark at the foot, the tint gathering where the pane is thickest. All of that
/// is gradients on the pane's own shape. The first version had a symmetric top-to-centre
/// highlight and a flat platform-coloured outline, which read as a tinted rectangle
/// rather than as a material.
struct LeagueSurface: ViewModifier {
    let platform: Platform

    private var pane: RoundedRectangle {
        RoundedRectangle(cornerRadius: SWRadius.lg, style: .continuous)
    }

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // The body. Dark enough that near-white content still clears a
                    // midday cloud behind it — the gallery's legibility strip is the
                    // check.
                    pane.fill(SWColor.surface.opacity(0.72))

                    // The league's colour, gathering toward the foot the way a tinted
                    // sheet reads deeper where it meets the ground.
                    pane.fill(
                        LinearGradient(
                            colors: [
                                SWColor.platform(platform).opacity(0.18),
                                SWColor.platform(platform).opacity(0.30),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                    // One light, top-left. A sheen raked across the upper corner and
                    // gone before the middle — never a symmetric bloom.
                    pane.fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.16), location: 0),
                                .init(color: .white.opacity(0.06), location: 0.32),
                                .init(color: .clear, location: 0.58),
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )

                    // The pane's thickness at the foot, away from the light. Tight,
                    // directional, inside the shape — not a shadow cast around it.
                    pane.fill(
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.18), location: 0),
                                .init(color: .clear, location: 0.16),
                            ],
                            startPoint: .bottom, endPoint: .top
                        )
                    )
                }
            }
            .overlay {
                // The cut edge: lit along the top lip, a trace down the sides, almost
                // nothing at the foot. An edge you feel rather than a drawn outline.
                pane.strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.38), location: 0),
                            .init(color: .white.opacity(0.10), location: 0.45),
                            .init(color: .white.opacity(0.04), location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
            .clipShape(pane)
    }
}

extension View {
    func leagueSurface(_ platform: Platform) -> some View {
        modifier(LeagueSurface(platform: platform))
    }
}

/// Where this league lives: the platform's initial on its own colour. Not its logo,
/// which is the platform's trademark and not ours to fetch and show.
struct PlatformMark: View {
    let platform: Platform
    var size: CGFloat = 18

    var body: some View {
        PlatformMonogram(platform: platform, size: size)
            .frame(width: size, height: size)
            .accessibilityLabel(Text(platform.displayName))
    }
}

/// Is the lineup set? The one question worth answering on every card.
struct LineupCheck: View {
    let isSet: Bool
    let issueCount: Int

    var body: some View {
        HStack(spacing: SWSpacing.xxs) {
            Image(systemName: isSet ? "checkmark" : "exclamationmark")
                .font(SWType.glyph)
            if !isSet, issueCount > 1 {
                Text("\(issueCount)").font(SWType.scoreMicro)
            }
        }
        .foregroundStyle(SWColor.canvas)
        .padding(.horizontal, SWSpacing.sm)
        .padding(.vertical, SWSpacing.xs)
        .background(Capsule().fill(isSet ? SWColor.positive : SWColor.warning))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isSet ? "Lineup set" : "\(issueCount) lineup problems"))
    }
}
