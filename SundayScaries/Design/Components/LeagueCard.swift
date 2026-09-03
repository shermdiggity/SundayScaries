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

    /// Derived from the league's id, so every league keeps a stable identity colour
    /// without anyone choosing one by hand.
    private var accent: Color {
        let hues: [Color] = [
            SWColor.accent, SWColor.positive, SWColor.position(.wr),
            SWColor.position(.te), SWColor.position(.k), SWColor.position(.rb),
        ]
        return hues[abs(snapshot.league.id.hashValue) % hues.count]
    }

    private var header: some View {
        HStack(alignment: .center, spacing: SWSpacing.sm) {
            PlatformMark(platform: snapshot.league.platform)

            // Your team first, then the league it plays in — the order you think about
            // them in.
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(SWType.cardTitle)
                    .foregroundStyle(SWColor.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let team = snapshot.myTeam {
                    HStack(spacing: SWSpacing.xs) {
                        Text(team.record.summary)
                        if let standing = snapshot.standing {
                            Text(Self.ordinal(standing)).foregroundStyle(accent)
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

    private var title: String {
        guard let team = snapshot.myTeam?.displayName else { return snapshot.league.name }
        return "\(team) · \(snapshot.league.name)"
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

/// A tinted pane, without a backdrop blur.
///
/// This was `.glassEffect`, and that is what caused the flicker when returning from a
/// league. Glass samples and blurs whatever is behind it, and the zoom transition
/// snapshots the source card's raster: at the moment the system hands the snapshot back
/// to the live view, the glass has to re-resolve its backdrop, and that one frame is
/// visible. Plain alpha blending has nothing to re-resolve.
///
/// It keeps the look — a translucent tinted surface with a lit top lip and a hairline —
/// without the sampling.
struct LeagueSurface: ViewModifier {
    let platform: Platform

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: SWRadius.lg, style: .continuous)
                    .fill(SWColor.surface.opacity(0.72))
                    .overlay {
                        RoundedRectangle(cornerRadius: SWRadius.lg, style: .continuous)
                            .fill(SWColor.platform(platform).opacity(0.24))
                    }
                    .overlay {
                        // The lit lip along the top edge, which is most of what reads
                        // as glass in the first place.
                        RoundedRectangle(cornerRadius: SWRadius.lg, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.14), .clear],
                                    startPoint: .top, endPoint: .center
                                )
                            )
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: SWRadius.lg, style: .continuous)
                    .strokeBorder(SWColor.platform(platform).opacity(0.45), lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: SWRadius.lg, style: .continuous))
    }
}

extension View {
    func leagueSurface(_ platform: Platform) -> some View {
        modifier(LeagueSurface(platform: platform))
    }
}

/// Where this league lives — the platform's real mark, falling back to its colour as a
/// monogram when there is no logo to load.
struct PlatformMark: View {
    let platform: Platform
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let url = SWColor.platformLogo(platform) {
                AsyncImage(url: url) { phase in
                    if case let .success(image) = phase {
                        image.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        monogram
                    }
                }
            } else {
                monogram
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(platform.displayName))
    }

    private var monogram: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(SWColor.platform(platform))
            .overlay {
                Text(platform.displayName.prefix(1))
                    // Scales with the mark, so this one is geometry rather than a token.
                    .font(.system(size: size * 0.6, weight: .black, design: .rounded))
                    .foregroundStyle(SWColor.canvas)
            }
    }
}

/// Is the lineup set? The one question worth answering on every card.
struct LineupCheck: View {
    let isSet: Bool
    let issueCount: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isSet ? "checkmark" : "exclamationmark")
                .font(SWType.glyph)
            if !isSet, issueCount > 1 {
                Text("\(issueCount)").font(SWType.scoreMicro)
            }
        }
        .foregroundStyle(isSet ? SWColor.canvas : SWColor.canvas)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Capsule().fill(isSet ? SWColor.positive : SWColor.warning))
        .accessibilityLabel(Text(isSet ? "Lineup set" : "\(issueCount) lineup problems"))
    }
}
