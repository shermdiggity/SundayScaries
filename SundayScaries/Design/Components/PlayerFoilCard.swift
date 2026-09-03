import SwiftUI
import FantasyCore

/// A player card. No shader, no finish — the effects fought the content and lost.
///
/// It reads through colour and shape instead: the portrait sits on the player's own
/// position colour, and whether you are riding on him or up against him sets the ring,
/// the meter and the bar down the side. Warm means yours, cold means theirs.
struct PlayerFoilCard: View {
    let position: PlayerPosition
    let kind: ExposureMeter.Kind
    var points: Double?
    var isProjected: Bool = true
    /// "Sun 1:00 PM" — when this player's game starts.
    var kickoff: String?

    private var involvements: [LeagueInvolvement] {
        switch kind {
        case .owned:   position.ownedIn
        case .started: position.startedIn
        case .faced:   position.facedIn
        }
    }

    private var count: Int { involvements.count }
    private var isAgainst: Bool { kind == .faced }
    private var tint: Color { isAgainst ? SWColor.negative : SWColor.accent }
    private var positionColor: Color { SWColor.position(position.player.position) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            portrait
            details
        }
        .frame(width: 168)
        .background(
            RoundedRectangle(cornerRadius: SWRadius.md, style: .continuous)
                .fill(SWColor.surface)
        )
        .overlay(alignment: .leading) {
            // One bar of meaning down the leading edge: warm if he is yours, cold if he
            // is theirs. Readable before you have read a word.
            UnevenRoundedRectangle(
                topLeadingRadius: SWRadius.md, bottomLeadingRadius: SWRadius.md,
                bottomTrailingRadius: 0, topTrailingRadius: 0, style: .continuous
            )
            .fill(tint)
            .frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: SWRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SWRadius.md, style: .continuous)
                .strokeBorder(SWColor.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var portrait: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [positionColor.opacity(0.42), SWColor.surface],
                startPoint: .top, endPoint: .bottom
            )
            Headshot(player: position.player, size: 76, strokeWidth: 2.5)
                .frame(maxWidth: .infinity)
                .padding(.top, SWSpacing.md)

            ExposureMeter(filled: count, total: position.totalLeagues, kind: kind,
                          barHeight: 6, barWidth: 20)
                .padding(SWSpacing.sm)
        }
        .frame(height: 108)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(position.player.name)
                .font(SWType.bodyMedium)
                .foregroundStyle(SWColor.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(spacing: SWSpacing.xs) {
                Text(position.player.position.rawValue)
                    .foregroundStyle(positionColor)
                if let team = position.player.nflTeam {
                    Text(team).foregroundStyle(SWColor.tertiary)
                }
                Spacer(minLength: 0)
                if let points {
                    HStack(spacing: 2) {
                        if isProjected { Text("proj").foregroundStyle(SWColor.tertiary) }
                        Text(points, format: .number.precision(.fractionLength(1)))
                            .font(SWType.scoreMicro)
                            .foregroundStyle(SWColor.primary)
                    }
                }
            }
            .font(SWType.micro)

            if let kickoff {
                Text(kickoff)
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
                    .lineLimit(1)
            }

            Rectangle().fill(SWColor.hairline).frame(height: 1).padding(.vertical, 2)

            ForEach(involvements.prefix(2)) { involvement in
                Text(isAgainst
                     ? "vs. " + (involvement.opponentName ?? involvement.leagueName)
                     : involvement.leagueName)
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.secondary)
                    .lineLimit(1)
            }
            if involvements.count > 2 {
                Text("+\(involvements.count - 2) more")
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
            }
        }
        .padding(SWSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
    }

    private var accessibilityText: Text {
        let verb = isAgainst ? "facing" : "starting"
        let leagues = involvements.map(\.leagueName).joined(separator: ", ")
        return Text("\(position.player.name), \(position.player.position.rawValue), \(verb) in \(count) of \(position.totalLeagues) leagues: \(leagues)")
    }
}
