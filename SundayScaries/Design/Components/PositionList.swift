import SwiftUI
import FantasyCore

/// Players you own, or players you face — as cards, with faces.
///
/// A vertical list of names was the weakest thing on the screen: it read as a settings
/// table for the most distinctive idea in the app. These are cards you scroll sideways,
/// each led by the player's face, because concentration is about *people*, and the
/// meter says how many of your leagues they touch without a number.
struct PositionCarousel: View {
    let title: String
    let positions: [PlayerPosition]
    let kind: ExposureMeter.Kind
    /// What a player is worth this week, and whether that number is a projection.
    var points: (PlayerRef) -> (value: Double?, isProjected: Bool) = { _ in (nil, true) }
    /// "Sun 1:00 PM" for this player's game.
    var kickoff: (PlayerRef) -> String? = { _ in nil }

    var body: some View {
        VStack(alignment: .leading, spacing: SWSpacing.md) {
            Text(title)
                .swVoice(SWType.sectionHeaderFace)
                // On the sky, like the hero — not the card text colour.
                .foregroundStyle(SWColor.onSky)
                .padding(.horizontal, SWSpacing.xl)

            ScrollView(.horizontal) {
                HStack(spacing: SWSpacing.md) {
                    ForEach(positions.prefix(8)) { position in
                        PlayerFoilCard(
                            position: position,
                            kind: kind,
                            points: points(position.player).value,
                            isProjected: points(position.player).isProjected,
                            kickoff: kickoff(position.player)
                        )
                        .playerTappable(position.player)
                    }
                }
                .padding(.horizontal, SWSpacing.xl)
                .padding(.vertical, SWSpacing.xs)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

/// One league's season, reduced to the two players who explain it.
struct SeasonOutlookRow: View {
    let snapshot: LeagueSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: SWSpacing.md) {
            HStack {
                Text(snapshot.league.name)
                    .font(SWType.section)
                    .foregroundStyle(SWColor.primary)
                    .lineLimit(1)
                Spacer(minLength: SWSpacing.sm)
                if let mood { Text(mood.0).font(SWType.caption).foregroundStyle(mood.1) }
            }

            HStack(spacing: SWSpacing.md) {
                if let mvp = snapshot.outlook.mvp {
                    contribution(mvp, label: "Carrying you", tone: SWColor.positive)
                }
                if let lvp = snapshot.outlook.lvp, lvp.id != snapshot.outlook.mvp?.id {
                    contribution(lvp, label: "Costing you", tone: SWColor.negative)
                }
            }
        }
        .padding(SWSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        // NOT glass. Glass re-resolves its backdrop every frame, and behind this sits a
        // full-screen animated Metal shader — the two together are most of what made
        // scrolling stutter. Plain alpha blending has nothing to re-resolve. The league
        // card learned this already; this one was missed.
        .background {
            RoundedRectangle(cornerRadius: SWRadius.lg)
                .fill(SWColor.surface.opacity(0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: SWRadius.lg)
                        .strokeBorder(SWColor.hairline, lineWidth: 1)
                }
        }
    }

    private var mood: (LocalizedStringKey, Color)? {
        guard let analytics = snapshot.analytics, let team = snapshot.myTeam,
              let luck = analytics.team(team.id)?.luckIndex else { return nil }
        if luck > 0.05 { return ("Running hot", SWColor.warning) }
        if luck < -0.05 { return ("Getting robbed", SWColor.negative) }
        return ("About right", SWColor.secondary)
    }

    private func contribution(_ value: PlayerContribution, label: LocalizedStringKey, tone: Color) -> some View {
        HStack(spacing: SWSpacing.sm) {
            Headshot(player: value.player, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(SWType.micro)
                    .foregroundStyle(tone)
                Text(value.player.name)
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.primary)
                    .lineLimit(1)
                Text(value.pointsPerStart, format: SWFormat.score)
                    .font(SWType.scoreMicro)
                    .foregroundStyle(SWColor.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
