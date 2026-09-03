import SwiftUI
import FantasyCore

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
    /// Whether THIS player's game has begun. Sleeper reports 0 for every player before
    /// kickoff, which is indistinguishable from actually scoring nothing — so until his
    /// game starts a 0 is not a score, and the projection is the honest number.
    var hasStarted: Bool = true
    /// "Sun 1:00 PM" for this player's game.
    var kickoff: String?
    var showsHeadshot: Bool = true

    private var player: PlayerRef { slot.player }
    private var isEmpty: Bool { player.isEmptyLineupSlot }

    var body: some View {
        HStack(spacing: SWSpacing.md) {
            Text(slot.slot.rawValue)
                .font(SWType.micro)
                .foregroundStyle(isEmpty ? SWColor.tertiary : SWColor.position(player.position))
                .frame(width: 38, alignment: .leading)

            if showsHeadshot { Headshot(player: player, size: 38) }

            VStack(alignment: .leading, spacing: 1) {
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
                if let kickoff, !isEmpty {
                    Text(kickoff)
                        .font(SWType.micro)
                        .foregroundStyle(SWColor.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: SWSpacing.sm)

            if let mark = statusMark {
                Circle().fill(mark).frame(width: 6, height: 6).accessibilityHidden(true)
            }

            trailing
        }
        .padding(.vertical, SWSpacing.sm)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    /// Real points once they exist; the projection before that, visibly quieter so the
    /// two are never confused.
    @ViewBuilder
    private var trailing: some View {
        if let points = slot.points, hasStarted || points != 0 {
            Text(points, format: .number.precision(.fractionLength(1)))
                .font(SWType.score)
                .foregroundStyle(SWColor.primary)
                .frame(minWidth: 56, alignment: .trailing)
        } else if let projection {
            HStack(spacing: 2) {
                Text("proj")
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
                Text(projection, format: .number.precision(.fractionLength(1)))
                    .font(SWType.scoreCaption)
                    .foregroundStyle(SWColor.secondary)
            }
            .frame(minWidth: 56, alignment: .trailing)
        } else {
            // No score and no projection is genuinely unknown, and a dash says so
            // where a 0 would be a claim.
            Text("—")
                .font(SWType.scoreCaption)
                .foregroundStyle(SWColor.tertiary)
                .frame(minWidth: 56, alignment: .trailing)
        }
    }

    /// The line under the name carries the most important thing first: a problem beats
    /// the fixture, and the fixture beats the bare team name.
    private var meta: String? {
        if isEmpty { return "No player set" }
        if slot.isOnBye { return "Bye" }
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
        var parts = [slot.slot.rawValue, isEmpty ? "empty" : player.name]
        if let meta, !isEmpty { parts.append(meta) }
        if let points = slot.points, hasStarted {
            parts.append("\(points.formatted(.number.precision(.fractionLength(1)))) points")
        } else if let projection {
            parts.append("projected \(projection.formatted(.number.precision(.fractionLength(1))))")
        }
        return Text(parts.joined(separator: ", "))
    }
}
