import SwiftUI
import FantasyCore
import FantasyProviders

/// The detail screen's top bar once the scoreboard has scrolled away.
///
/// A full-width bar, not a floating pill: once the scoreboard is gone this is the
/// scoreboard, so it carries both live totals and both projections.
struct CollapsedScoreboard: View {
    let snapshot: LeagueSnapshot

    var body: some View {
        VStack(spacing: SWSpacing.xxs) {
            HStack(spacing: SWSpacing.sm) {
                Text(snapshot.league.name)
                    .font(SWType.bodyMedium)
                    .foregroundStyle(SWColor.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            HStack(spacing: SWSpacing.sm) {
                side(
                    name: snapshot.myTeam?.displayName ?? "You",
                    scored: snapshot.progress.pointsScored,
                    projected: snapshot.projectedTotal(for: snapshot.myRoster),
                    alignment: .leading
                )
                Text("vs.").font(SWType.micro).foregroundStyle(SWColor.tertiary)
                side(
                    name: snapshot.opponent?.displayName ?? "—",
                    scored: snapshot.opponentProgress.pointsScored,
                    projected: snapshot.projectedTotal(for: snapshot.opponentRoster),
                    alignment: .trailing
                )
            }

            if let probability = snapshot.winProbability {
                WinBar(probability: probability, height: SWSize.dot, showsLabel: true, isLive: snapshot.hasKickedOff)
                    .padding(.top, SWSpacing.xxs)
            }
        }
        .padding(.horizontal, SWSpacing.md)
        .padding(.vertical, SWSpacing.sm)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.tint(SWColor.leagueTint(snapshot.league.platform)), in: .rect(cornerRadius: SWRadius.md))
        .accessibilityElement(children: .combine)
    }

    private func side(name: String, scored: Double, projected: Double?, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(name)
                .font(SWType.micro)
                .foregroundStyle(SWColor.tertiary)
                .lineLimit(1)
            HStack(spacing: SWSpacing.xs) {
                Text(scored, format: SWFormat.score)
                    .contentTransition(.numericText())
                    .font(SWType.scoreCaption)
                    .foregroundStyle(SWColor.primary)
                if let projected {
                    Text("proj \(projected.formatted(SWFormat.score))")
                        .font(SWType.micro)
                        .foregroundStyle(SWColor.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}
