import SwiftUI
import FantasyCore
import FantasyProviders

/// Both lineups, opposed slot by slot — the way a matchup preview should read.
///
/// Each row is one position with your player on the left and theirs on the right, and
/// the row leans toward whoever is ahead on that slot. You can see where you win and
/// where you lose without doing any arithmetic.
///
/// A side reads top to bottom in the order a Sunday asks: who, how many, what they did,
/// and where the game stands. The number is the loudest thing on the row once a game is
/// on — it used to share a micro line with the fixture, the same size as the kickoff
/// time under it, which made a live lineup read like a fixture list.
struct LineupFaceoff: View {
    let snapshot: LeagueSnapshot
    let mine: Roster
    let theirs: Roster?
    /// This week's box-score lines by canonical id, from the public stats feed. Empty
    /// until they load; the row shows the state and the score without them.
    var statLines: [String: [String: Double]] = [:]

    private var week: Int { mine.week }

    /// Pairing is domain logic, not presentation, so it lives in `Roster` where it can
    /// be tested against deliberately mismatched lineups.
    private var pairs: [Roster.LineupPairing] { mine.faceoff(against: theirs) }

    var body: some View {
        VStack(spacing: SWSpacing.md) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                row(pair)
            }
        }
    }

    private func row(_ pair: Roster.LineupPairing) -> some View {
        let mineValue = value(pair.mine)
        let theirsValue = value(pair.theirs)
        let slotName = pair.slot.label

        // Top-aligned: a side whose game is on carries a stat line the other may not,
        // and the names should still sit on one line across the row.
        return HStack(alignment: .top, spacing: SWSpacing.sm) {
            side(pair.mine, isWinning: mineValue > theirsValue, alignment: .leading)

            Text(slotName)
                .font(SWType.micro)
                .foregroundStyle(SWColor.tertiary)
                .frame(minWidth: SWSize.slotColumn)
                .padding(.top, SWSpacing.xxs)

            side(pair.theirs, isWinning: theirsValue > mineValue, alignment: .trailing)
        }
        // Contained, not combined: each side is a button that opens a player, and
        // combining the row hid both of them from VoiceOver.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: accessibilityLine(
            slotName: slotName, pair: pair, mineValue: mineValue, theirsValue: theirsValue
        )))
    }

    @ViewBuilder
    private func side(_ slot: RosterSlot?, isWinning: Bool, alignment: HorizontalAlignment) -> some View {
        if let slot {
            let content = VStack(alignment: alignment, spacing: SWSpacing.xxs) {
                Text(slot.player.isEmptyLineupSlot ? "Empty" : slot.player.name)
                    .font(SWType.body)
                    .foregroundStyle(slot.issue == nil ? SWColor.primary : SWColor.warning)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                number(slot, isWinning: isWinning)

                if hasStarted(slot), let line = statLine(slot) {
                    Text(Self.unbreakable(line))
                        .font(SWType.micro)
                        .foregroundStyle(SWColor.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                }

                state(slot, alignment: alignment)
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

    /// The score once the game is on, in the score face, and dimmed on the side that is
    /// behind — a tonal step, not a colour. Before kickoff, the projection, labelled.
    @ViewBuilder
    private func number(_ slot: RosterSlot, isWinning: Bool) -> some View {
        if hasStarted(slot) {
            Text(value(slot), format: SWFormat.score)
                .font(SWType.score)
                .foregroundStyle(isWinning ? SWColor.primary : SWColor.secondary)
                .contentTransition(.numericText())
        } else if slot.player.isEmptyLineupSlot || slot.isOnBye {
            Text(slot.isOnBye ? "Bye" : "No player set")
                .font(SWType.scoreCaption)
                .foregroundStyle(SWColor.warning)
        } else {
            HStack(spacing: SWSpacing.xxs) {
                Text("proj")
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
                Text(value(slot), format: SWFormat.score)
                    .font(SWType.scoreCaption)
                    .foregroundStyle(SWColor.secondary)
                    .contentTransition(.numericText())
            }
        }
    }

    /// Where the game stands, then who it is against. "Live" is the one word on the row
    /// that wears the live colour.
    ///
    /// One text, not a row of them, so it can WRAP: a side on a phone narrower than the
    /// simulator has under a hundred points for this line, and "Sun 1:25 PM · @ SEA"
    /// does not fit in it. Truncating it lost the opponent on every row of a matchup.
    /// Each item is held together with non-breaking spaces, so the only place the line
    /// can break is at the separator — the time on one line, the opponent on the next.
    private func state(_ slot: RosterSlot, alignment: HorizontalAlignment) -> some View {
        let lead: Text
        switch snapshot.schedule.gameState(nflTeam: slot.player.nflTeam, week: week) {
        case .final:
            lead = Text("Final")
        case .inProgress:
            lead = Text("Live").foregroundStyle(SWColor.live)
        case .notStarted:
            let kickoff = snapshot.schedule.kickoffLabel(nflTeam: slot.player.nflTeam, week: week) ?? ""
            lead = Text(verbatim: Self.unbreakable(kickoff))
        case .none:
            lead = Text(verbatim: "")
        }
        let matchup = slot.isOnBye ? nil : snapshot.schedule.opponentLabel(nflTeam: slot.player.nflTeam, week: week)
        let text = matchup.map { Text("\(lead) · \(Self.unbreakable($0))") } ?? lead
        return text
            .font(SWType.micro)
            .foregroundStyle(SWColor.tertiary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
    }

    /// Spaces inside an item become non-breaking, so a line breaks only between items.
    /// "122 yds · 1 TD" may break at the dot; "122" and "yds" stay together.
    static func unbreakable(_ line: String) -> String {
        line.split(separator: " · ")
            .map { $0.replacingOccurrences(of: " ", with: "\u{00A0}") }
            .joined(separator: " · ")
    }

    private func statLine(_ slot: RosterSlot) -> String? {
        guard let id = slot.player.canonicalID, let stats = statLines[id] else { return nil }
        let line = StatLine.summary(stats, position: slot.player.position, compact: true)
        return line.isEmpty ? nil : line
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
        if hasStarted(slot), let points = slot.points { return points }
        return snapshot.projections.projection(for: slot.player) ?? 0
    }

    private func hasStarted(_ slot: RosterSlot) -> Bool {
        switch snapshot.schedule.gameState(nflTeam: slot.player.nflTeam, week: week) {
        case .inProgress, .final:   true
        case .notStarted, .none:    false
        }
    }
}
