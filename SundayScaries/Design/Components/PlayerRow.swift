import SwiftUI
import FantasyCore
import FantasyProviders

/// The atom. Appears in lineups everywhere.
///
/// Led by the player's face, because a lineup is people. No chips and no tiles: the
/// position is bare letters in its own colour. A healthy player carries no status
/// marking at all, so the only rows wearing one are the rows that need attention.
struct PlayerRow: View {
    let slot: RosterSlot
    /// Shown when the player's game has not started, so an unplayed lineup still says
    /// what it is worth rather than a column of dashes.
    var projection: Double?
    /// "@ KC" / "vs. DEN" — who this player's NFL team is up against this week.
    var nflMatchup: String?
    /// Where THIS player's game stands. Sleeper reports 0 for every player before
    /// kickoff, which is indistinguishable from actually scoring nothing — so until his
    /// game starts a 0 is not a score, and the projection is the honest number.
    var gameState: ByeWeeks.GameState = .final
    /// "Sun 1:00 PM" for this player's game.
    var kickoff: String?
    /// What he has done so far, once his game is on: "84 yds · 1 TD · 6 rec".
    var statLine: String?
    var showsHeadshot: Bool = true

    private var hasStarted: Bool { gameState == .inProgress || gameState == .final }

    private var player: PlayerRef { slot.player }
    private var isEmpty: Bool { player.isEmptyLineupSlot }

    /// The column the slot label sits in, so names start on one line down a lineup.
    private static let slotLabelColumn: CGFloat = 38

    var body: some View {
        HStack(spacing: SWSpacing.md) {
            Text(slot.slot.label)
                .font(SWType.micro)
                .foregroundStyle(isEmpty ? SWColor.tertiary : SWColor.position(player.position))
                .frame(minWidth: Self.slotLabelColumn, alignment: .leading)

            if showsHeadshot { Headshot(player: player, size: SWSize.faceRow) }

            VStack(alignment: .leading, spacing: SWSpacing.xxs) {
                Text(isEmpty ? "Empty" : player.name)
                    .font(SWType.bodyMedium)
                    .foregroundStyle(isEmpty ? SWColor.tertiary : SWColor.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if let meta {
                    Text(meta)
                        .font(SWType.caption)
                        .foregroundStyle(metaColor)
                        .lineLimit(1)
                }
                if !isEmpty, !slot.isOnBye {
                    stateLine
                }
            }

            Spacer(minLength: SWSpacing.sm)

            if let mark = statusMark {
                Circle().fill(mark).frame(width: SWSize.dot, height: SWSize.dot).accessibilityHidden(true)
            }

            trailing
        }
        .padding(.vertical, SWSpacing.sm)
        .contentShape(.rect)
        .playerTappable(player)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    /// The third line: the kickoff before the game, then what he has done in it, led
    /// by where it stands. "Live" is the one word that wears the live colour. Wraps at
    /// a separator rather than truncating; see `LineupFaceoff.state`.
    private var stateLine: some View {
        let lead: Text
        switch gameState {
        case .final:
            lead = Text("Final")
        case .inProgress:
            lead = Text("Live").foregroundStyle(SWColor.live)
        case .notStarted:
            lead = Text(verbatim: LineupFaceoff.unbreakable(kickoff ?? ""))
        case .none:
            lead = Text(verbatim: "")
        }
        let line = hasStarted ? statLine : nil
        let text = line.map {
            Text("\(lead) · \(Text(verbatim: LineupFaceoff.unbreakable($0)).foregroundStyle(SWColor.secondary))")
        } ?? lead
        return text
            .font(SWType.micro)
            .foregroundStyle(SWColor.tertiary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Real points once they exist; the projection before that, visibly quieter so the
    /// two are never confused.
    @ViewBuilder
    private var trailing: some View {
        if let points = slot.points, hasStarted || points != 0 {
            Text(points, format: SWFormat.score)
                .font(SWType.score)
                .foregroundStyle(SWColor.primary)
                // Digits roll to the new value instead of blinking.
                .contentTransition(.numericText())
                .frame(minWidth: SWSize.scoreColumn, alignment: .trailing)
        } else if let projection {
            HStack(spacing: SWSpacing.xxs) {
                Text("proj")
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
                Text(projection, format: SWFormat.score)
                    .font(SWType.scoreCaption)
                    .foregroundStyle(SWColor.secondary)
                    .contentTransition(.numericText())
            }
            .frame(minWidth: 56, alignment: .trailing)
        } else {
            // No score and no projection is genuinely unknown, and a dash says so
            // where a 0 would be a claim.
            Text("—")
                .font(SWType.scoreCaption)
                .foregroundStyle(SWColor.tertiary)
                .frame(minWidth: SWSize.scoreColumn, alignment: .trailing)
        }
    }

    /// The line under the name carries the most important thing first: a problem beats
    /// the fixture, and the fixture beats the bare team name.
    private var meta: String? {
        if isEmpty { return String(localized: "No player set") }
        if slot.isOnBye { return String(localized: "Bye") }
        if player.injuryStatus != .healthy {
            return [player.injuryStatus.displayName, nflMatchup].compactMap { $0 }.joined(separator: " · ")
        }
        if let nflMatchup { return "\(player.nflTeam ?? "") \(nflMatchup)".trimmingCharacters(in: .whitespaces) }
        return player.nflTeam
    }

    private var metaColor: Color {
        if isEmpty || slot.isOnBye { return SWColor.warning }
        if player.injuryStatus.isStartingRisk { return SWColor.negative }
        if player.injuryStatus == .questionable { return SWColor.warning }
        return SWColor.tertiary
    }

    private var statusMark: Color? {
        guard slot.isStarter else { return nil }
        if isEmpty || slot.isOnBye { return SWColor.warning }
        if player.injuryStatus.isStartingRisk { return SWColor.negative }
        if player.injuryStatus == .questionable { return SWColor.warning }
        return nil
    }

    private var accessibilityText: Text {
        var parts = [slot.slot.label, isEmpty ? String(localized: "empty") : player.name]
        if let meta, !isEmpty { parts.append(meta) }
        if let points = slot.points, hasStarted {
            parts.append(String(localized: "\(points.formatted(SWFormat.score)) points"))
        } else if let projection {
            parts.append(String(localized: "projected \(projection.formatted(SWFormat.score))"))
        }
        return Text(parts.joined(separator: ", "))
    }
}

extension PlayerRow {
    /// A slot from a league's rosters, with everything the row shows looked up from that
    /// league's projections and schedule.
    init(
        slot: RosterSlot, in snapshot: LeagueSnapshot, week: Int, statLines: [String: [String: Double]] = [:]
    ) {
        let line = slot.player.canonicalID.flatMap { statLines[$0] }
            .map { StatLine.summary($0, position: slot.player.position, compact: true) }
        self.init(
            slot: slot,
            projection: snapshot.projections.projection(for: slot.player),
            nflMatchup: snapshot.schedule.opponentLabel(nflTeam: slot.player.nflTeam, week: week),
            gameState: snapshot.schedule.gameState(nflTeam: slot.player.nflTeam, week: week),
            kickoff: snapshot.schedule.kickoffLabel(nflTeam: slot.player.nflTeam, week: week),
            statLine: line.flatMap { $0.isEmpty ? nil : $0 }
        )
    }
}
