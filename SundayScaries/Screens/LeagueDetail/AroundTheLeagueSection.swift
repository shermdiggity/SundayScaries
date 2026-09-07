import SwiftUI
import FantasyCore
import FantasyProviders

/// Every other game this week, each in the same block your own scoreboard uses, so
/// the whole league reads in one visual language. Tapping one opens both lineups.
struct AroundTheLeagueSection: View {
    let snapshot: LeagueSnapshot
    let onSelect: (LeagueSnapshot.MatchupPair) -> Void

    var body: some View {
        let others = snapshot.otherMatchups
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: SWSpacing.md) {
                Text("Around the league")
                    .font(SWType.headline)
                    .foregroundStyle(SWColor.primary)
                    .accessibilityAddTraits(.isHeader)

                ForEach(others) { pair in
                    Button {
                        onSelect(pair)
                    } label: {
                        // Same two blocks as your own scoreboard, in the same order:
                        // the banked points and how much is left come FIRST, because
                        // they change what the projection underneath means.
                        VStack(spacing: SWSpacing.sm) {
                            let left = snapshot.progress(for: pair.leftRoster)
                            let right = snapshot.progress(for: pair.rightRoster)
                            if left.total > 0 || right.total > 0 {
                                ProgressRow(mine: left, theirs: right, isCompact: true)
                            }
                            MatchupHeader(snapshot: snapshot, pair: pair)
                        }
                        .padding(SWSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: SWRadius.md, style: .continuous)
                                .fill(SWColor.primary.opacity(0.07))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: SWRadius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows both starting lineups")
                }
            }
            .padding(SWSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(SWColor.leagueTint(snapshot.league.platform)),
                         in: .rect(cornerRadius: SWRadius.lg))
        }
    }
}
