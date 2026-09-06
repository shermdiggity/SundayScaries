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
        .overlay(alignment: .bottomLeading) {
            // The meter shows the shape of the concentration; this says the number out
            // loud. On its own the meter never answered "of how many?".
            Text(countLabel)
                .font(SWType.micro)
                .foregroundStyle(SWColor.canvas)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(tint))
                .padding(SWSpacing.sm)
        }
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
                        Text(points, format: SWFormat.score)
                            .font(SWType.scoreMicro)
                            .foregroundStyle(SWColor.primary)
                            .contentTransition(.numericText())
                    }
                }
            }
            .font(SWType.micro)

            // Every line below is RESERVED whether or not it has content. A player in
            // four leagues used to make a taller card than one in a single league, so a
            // row of these stepped up and down like a bar chart. The card is a fixed
            // object; what varies is what is written on it.
            Text(kickoff ?? " ")
                .font(SWType.micro)
                .foregroundStyle(SWColor.tertiary)
                .lineLimit(1)
                .opacity(kickoff == nil ? 0 : 1)

            Rectangle().fill(SWColor.hairline).frame(height: 1).padding(.vertical, 2)

            ForEach(Array(leagueLines.enumerated()), id: \.offset) { _, line in
                Text(line.isEmpty ? " " : line)
                    .font(SWType.micro)
                    .foregroundStyle(line.hasPrefix("+") ? SWColor.tertiary : SWColor.secondary)
                    .lineLimit(1)
                    .opacity(line.isEmpty ? 0 : 1)
            }
        }
        .padding(SWSpacing.md)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 116)
        .clipped()
    }

    /// Always exactly two lines. Three or more leagues collapse to one name plus a
    /// count, so the card never grows to fit them.
    private var leagueLines: [String] {
        func label(_ involvement: LeagueInvolvement) -> String {
            isAgainst ? String(localized: "vs. \(involvement.opponentName ?? involvement.leagueName)")
                : involvement.leagueName
        }
        switch involvements.count {
        case 0:    return ["", ""]
        case 1:    return [label(involvements[0]), ""]
        case 2:    return [label(involvements[0]), label(involvements[1])]
        default:   return [label(involvements[0]), String(localized: "+\(involvements.count - 1) more")]
        }
    }

    /// "In 2 of 3 leagues" / "Starting in all 3" — plain words, no decoding required.
    private var countLabel: LocalizedStringKey {
        if count == position.totalLeagues, count > 1 {
            return isAgainst ? "Against you in all \(count)" : "Starting in all \(count)"
        }
        return isAgainst
            ? "Against you in \(count) of \(position.totalLeagues)"
            : "Starting in \(count) of \(position.totalLeagues)"
    }

    private var accessibilityText: Text {
        let leagues = involvements.map(\.leagueName).joined(separator: ", ")
        return isAgainst
            ? Text("\(position.player.name), \(position.player.position.rawValue), facing in \(count) of \(position.totalLeagues) leagues: \(leagues)")
            : Text("\(position.player.name), \(position.player.position.rawValue), starting in \(count) of \(position.totalLeagues) leagues: \(leagues)")
    }
}
