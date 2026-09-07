import SwiftUI
import FantasyCore
import FantasyProviders

/// Both lineups, opposed slot by slot — the way a matchup preview should read.
///
/// Each row is one position with your player on the left and theirs on the right, and
/// the row leans toward whoever is ahead on that slot. You can see where you win and
/// where you lose without doing any arithmetic.
struct LineupFaceoff: View {
    let snapshot: LeagueSnapshot
    let mine: Roster
    let theirs: Roster?

    private var week: Int { mine.week }

    /// Pairing is domain logic, not presentation, so it lives in `Roster` where it can
    /// be tested against deliberately mismatched lineups.
    private var pairs: [Roster.LineupPairing] { mine.faceoff(against: theirs) }

    var body: some View {
        VStack(spacing: SWSpacing.sm) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                row(pair)
            }
        }
    }

    private func row(_ pair: Roster.LineupPairing) -> some View {
        let mineValue = value(pair.mine)
        let theirsValue = value(pair.theirs)
        let slotName = pair.slot.label

        return HStack(spacing: SWSpacing.sm) {
            side(pair.mine, isWinning: mineValue > theirsValue, alignment: .leading)

            VStack(spacing: SWSpacing.xxs) {
                Text(slotName)
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
            }
            .frame(minWidth: SWSize.slotColumn)

            side(pair.theirs, isWinning: theirsValue > mineValue, alignment: .trailing)
        }
        .padding(.vertical, SWSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: accessibilityLine(
            slotName: slotName, pair: pair, mineValue: mineValue, theirsValue: theirsValue
        )))
    }

    @ViewBuilder
    private func side(_ slot: RosterSlot?, isWinning: Bool, alignment: HorizontalAlignment) -> some View {
        if let slot {
            let content = VStack(alignment: alignment, spacing: SWSpacing.xxs) {
                Text(slot.player.isEmptyLineupSlot ? "Empty" : slot.player.name)
                    .font(SWType.caption)
                    .foregroundStyle(slot.issue == nil ? SWColor.primary : SWColor.warning)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                // Who they play and when, then the number — labelled "proj" whenever
                // it is one, so a projection is never mistaken for a score.
                HStack(spacing: SWSpacing.xxs) {
                    if let matchup = snapshot.schedule.opponentLabel(nflTeam: slot.player.nflTeam, week: week) {
                        Text(matchup)
                    }
                    if isProjected(slot) { Text("proj") }
                    Text(number(slot))
                        .foregroundStyle(isWinning ? SWColor.accent : SWColor.tertiary)
                        .contentTransition(.numericText())
                }
                .font(SWType.scoreMicro)
                .foregroundStyle(SWColor.tertiary)

                if let kickoff = snapshot.schedule.kickoffLabel(nflTeam: slot.player.nflTeam, week: week) {
                    Text(kickoff)
                        .font(SWType.micro)
                        .foregroundStyle(SWColor.tertiary.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)

            if alignment == .leading {
                HStack(spacing: SWSpacing.sm) {
                    Headshot(player: slot.player, size: SWSize.faceInline)
                    content
                }
                .playerTappable(slot.player)
            } else {
                HStack(spacing: SWSpacing.sm) {
                    content
                    Headshot(player: slot.player, size: SWSize.faceInline)
                }
                .playerTappable(slot.player)
            }
        } else {
            Color.clear.frame(maxWidth: .infinity, minHeight: SWSize.faceInline)
        }
    }

    private func accessibilityLine(
        slotName: String,
        pair: Roster.LineupPairing,
        mineValue: Double,
        theirsValue: Double
    ) -> String {
        let format = SWFormat.score
        let me = pair.mine?.player.name ?? String(localized: "empty")
        let them = pair.theirs?.player.name ?? String(localized: "empty")
        return String(localized: "\(slotName): \(me) \(mineValue.formatted(format)), against \(them) \(theirsValue.formatted(format))")
    }

    /// Actual points once THIS player's game has begun — not merely once some game in
    /// the league has. Before that, the projection is the honest number.
    private func value(_ slot: RosterSlot?) -> Double {
        guard let slot else { return 0 }
        if !isProjected(slot), let points = slot.points { return points }
        return snapshot.projections.projection(for: slot.player) ?? 0
    }

    private func isProjected(_ slot: RosterSlot) -> Bool {
        switch snapshot.schedule.gameState(nflTeam: slot.player.nflTeam, week: week) {
        case .inProgress, .final:   false
        case .notStarted, .none:    true
        }
    }

    private func number(_ slot: RosterSlot) -> String {
        let raw = value(slot)
        return raw.formatted(SWFormat.score)
    }
}
