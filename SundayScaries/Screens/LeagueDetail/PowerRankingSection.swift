import SwiftUI
import FantasyCore
import FantasyProviders

/// The power ranking: a podium for the top three, a list for everyone else, and the
/// weights that made it, because a ranking you can inspect is the product.
struct PowerRankingSection: View {
    let snapshot: LeagueSnapshot
    let onSelectTeam: (String) -> Void

    private var week: Int { snapshot.week }
    /// The column a rank sits in, so team names start on one line.
    private static let rankColumn: CGFloat = 22

    /// One row of the ranking, from whichever source currently has something to say.
    private struct RankRow: Identifiable {
        let teamID: String
        let rank: Int
        /// The headline number.
        let value: String
        /// What that number is called.
        let unit: LocalizedStringKey
        /// The quieter line under the team name.
        let detail: LocalizedStringKey
        let isMine: Bool
        var id: String { teamID }
    }

    /// True before any game has been scored, when an all-play blend is all zeroes and
    /// the only real signal is what the week projects.
    private var isProjectedOnly: Bool {
        snapshot.analytics?.weeksAnalyzed.isEmpty ?? true
    }

    private var rankRows: [RankRow] {
        guard let analytics = snapshot.analytics, !analytics.teams.isEmpty else { return [] }

        guard isProjectedOnly else {
            return analytics.teams.map { entry in
                RankRow(
                    teamID: entry.teamID,
                    rank: entry.powerRank,
                    value: Self.powerPoints(entry.powerScore),
                    unit: "power pts",
                    detail: "\(entry.allPlay.summary) all-play",
                    isMine: entry.teamID == snapshot.myTeam?.id
                )
            }
        }

        // Nothing has been played. Rank by what the week projects instead of showing
        // twelve identical zeroes — and say plainly that is what this is.
        return snapshot.rosters
            .map { ($0.teamID, snapshot.projectedTotal(for: $0) ?? 0) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
            .enumerated()
            .map { index, pair in
                RankRow(
                    teamID: pair.0,
                    rank: index + 1,
                    value: pair.1.formatted(SWFormat.score),
                    unit: "projected",
                    detail: "Week \(week) projection",
                    isMine: pair.0 == snapshot.myTeam?.id
                )
            }
    }

    var body: some View {
        let rows = rankRows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: SWSpacing.sm) {
                Text(isProjectedOnly ? "Projected ranking" : "Power ranking")
                    .font(SWType.headline)
                    .foregroundStyle(SWColor.primary)
                    .accessibilityAddTraits(.isHeader)
                Text(isProjectedOnly
                    ? "Nobody has scored yet, so this is week \(week) projections. "
                    + "Power points take over once games are played."
                    : "Power points blend all-play win rate, points for and recent form.")
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, SWSpacing.sm)

                Podium(
                    entries: rows.prefix(3).map { row in
                        Podium.Entry(
                            rank: row.rank,
                            teamName: teamName(row.teamID),
                            powerPoints: row.value,
                            unit: row.unit,
                            allPlay: row.detail,
                            face: bestPlayer(forTeam: row.teamID),
                            isMine: row.isMine
                        )
                    },
                    onSelect: onSelectTeam,
                    idForRank: { rank in rows.first { $0.rank == rank }?.teamID }
                )
                .padding(.bottom, SWSpacing.md)

                ForEach(rows.dropFirst(3)) { row in
                    Button { onSelectTeam(row.teamID) } label: {
                        rankRow(row)
                    }
                    .buttonStyle(.plain)
                }

                if !isProjectedOnly, let analytics = snapshot.analytics {
                    Text(analytics.weights.disclosure
                        .map { "\($0.label) \(Int($0.weight * 100))%" }
                        .joined(separator: " · "))
                        .font(SWType.micro)
                        .foregroundStyle(SWColor.tertiary)
                        .padding(.top, SWSpacing.sm)
                }
            }
            .padding(SWSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(SWColor.leagueTint(snapshot.league.platform)),
                         in: .rect(cornerRadius: SWRadius.lg))
        }
    }

    private func rankRow(_ row: RankRow) -> some View {
        HStack(spacing: SWSpacing.md) {
            Text("\(row.rank)")
                .font(SWType.scoreCaption)
                .foregroundStyle(row.isMine ? SWColor.accent : SWColor.tertiary)
                .frame(minWidth: Self.rankColumn, alignment: .trailing)

            if let face = bestPlayer(forTeam: row.teamID) {
                Headshot(player: face, size: SWSize.faceInline)
                    .playerTappable(face)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(teamName(row.teamID))
                    .font(row.isMine ? SWType.bodyMedium : SWType.body)
                    .foregroundStyle(row.isMine ? SWColor.accent : SWColor.primary)
                    .lineLimit(1)
                Text(row.detail)
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
            }

            Spacer(minLength: SWSpacing.sm)

            VStack(alignment: .trailing, spacing: 0) {
                Text(row.value)
                    .font(SWType.scoreCaption)
                    .foregroundStyle(SWColor.secondary)
                Text(row.unit)
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(SWType.glyph)
                .foregroundStyle(SWColor.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, SWSpacing.sm)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    /// The blend is 0...1; showing it out of 100 makes it a score people can argue about.
    static func powerPoints(_ score: Double) -> String {
        (score * 100).formatted(SWFormat.score)
    }

    private func teamName(_ id: String) -> String {
        snapshot.teams.first { $0.id == id }?.displayName ?? id
    }

    /// A face per team: the highest-scoring or highest-projected starter.
    private func bestPlayer(forTeam id: String) -> PlayerRef? {
        guard let roster = snapshot.rosters.first(where: { $0.teamID == id }) else { return nil }
        return roster.starters
            .filter { !$0.player.isEmptyLineupSlot }
            .max { lhs, rhs in
                let l = lhs.points ?? snapshot.projections.projection(for: lhs.player) ?? 0
                let r = rhs.points ?? snapshot.projections.projection(for: rhs.player) ?? 0
                return l < r
            }?.player
    }
}
