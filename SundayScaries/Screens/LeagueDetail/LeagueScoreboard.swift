import SwiftUI
import FantasyCore
import FantasyProviders

/// The top of the detail screen: the league's name, the same matchup block the card
/// showed (so the zoom lands on what it left), your record and place, and the way to
/// the league on its own platform.
struct LeagueScoreboard: View {
    let snapshot: LeagueSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: SWSpacing.lg) {
            HStack(spacing: SWSpacing.sm) {
                PlatformMark(platform: snapshot.league.platform)
                Text(snapshot.league.name)
                    .font(SWType.title)
                    .foregroundStyle(SWColor.primary)
                    .accessibilityAddTraits(.isHeader)
                    .lineLimit(2)
                Spacer(minLength: SWSpacing.sm)
                if snapshot.league.status.hasDrafted, snapshot.myTeam != nil {
                    LineupCheck(isSet: snapshot.isLineupSet, issueCount: snapshot.issues.count)
                }
            }

            if snapshot.opponent != nil {
                if snapshot.progress.total > 0 {
                    ProgressRow(mine: snapshot.progress, theirs: snapshot.opponentProgress)
                }
                MatchupHeader(snapshot: snapshot, isExpanded: true)
            }

            HStack(spacing: SWSpacing.xl) {
                if let team = snapshot.myTeam {
                    StatCell(value: team.record.summary, caption: "Record")
                    StatCell(value: team.pointsFor.formatted(.number.precision(.fractionLength(0))),
                             caption: "Points for")
                }
                if let standing = snapshot.standing {
                    StatCell(value: LeagueCard.ordinal(standing), caption: "Place")
                }
                if let luck = luckIndex {
                    StatCell(value: luck.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always())),
                             caption: "Luck")
                }
            }

            // Straight to the league on its own platform — the app if it is installed,
            // the site if not — for the things this app deliberately does not do, like
            // setting a lineup. One quiet row, the platform's own mark, an outward arrow.
            if let destination = PlatformLinks.league(snapshot.league, teamID: snapshot.myTeam?.id) {
                Link(destination: destination) {
                    HStack(spacing: SWSpacing.sm) {
                        PlatformMark(platform: snapshot.league.platform, size: SWSize.mark)
                        Text("Open in \(snapshot.league.platform.displayName)")
                            .font(SWType.bodyMedium)
                            .foregroundStyle(SWColor.primary)
                        Spacer(minLength: SWSpacing.sm)
                        Image(systemName: "arrow.up.right")
                            .font(SWType.glyph)
                            .foregroundStyle(SWColor.secondary)
                    }
                    .padding(.horizontal, SWSpacing.md)
                    .padding(.vertical, SWSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: SWRadius.sm, style: .continuous)
                            .fill(SWColor.primary.opacity(0.07))
                    )
                    .contentShape(.rect(cornerRadius: SWRadius.sm))
                }
                .accessibilityLabel("Open this league in \(snapshot.league.platform.displayName)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var luckIndex: Double? {
        guard let team = snapshot.myTeam else { return nil }
        return snapshot.analytics?.team(team.id)?.luckIndex
    }
}
