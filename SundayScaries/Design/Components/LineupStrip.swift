import SwiftUI
import FantasyCore

/// A whole starting lineup at a glance, as a row of position marks.
///
/// A filled mark is a set slot; a hollow one is a hole. You can see a broken lineup
/// without reading a word, which is what a Sunday-morning glance actually needs. The
/// one sentence underneath appears only when something is wrong — a strip with nothing
/// to say says nothing.
struct LineupStrip: View {
    let roster: Roster
    /// Supplied so problems are only reported when the manager can act on them. An
    /// undrafted league has an empty lineup by definition.
    var league: League?

    private var issues: [LineupIssue] {
        league.map { roster.issues(in: $0) } ?? roster.issues
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SWSpacing.sm) {
            HStack(spacing: SWSpacing.xs) {
                ForEach(Array(roster.starters.enumerated()), id: \.offset) { _, slot in
                    mark(for: slot)
                }
            }

            if let first = issues.first {
                HStack(spacing: SWSpacing.xs) {
                    Text(first.summary)
                    if issues.count > 1 {
                        Text("+\(issues.count - 1) more")
                            .foregroundStyle(SWColor.tertiary)
                    }
                }
                .font(SWType.caption)
                .foregroundStyle(SWColor.warning)
                .transition(.opacity)
            }
        }
        .animation(SWMotion.standard, value: issues.count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private func mark(for slot: RosterSlot) -> some View {
        let shape = RoundedRectangle(cornerRadius: 2, style: .continuous)
        Group {
            if slot.issue == nil || issues.isEmpty {
                shape.fill(SWColor.primary.opacity(0.55))
            } else {
                shape.strokeBorder(SWColor.warning, lineWidth: 1.5)
            }
        }
        .frame(width: 14, height: 4)
    }

    private var accessibilityText: Text {
        guard !issues.isEmpty else {
            return Text("Lineup set, \(roster.starters.count) starters")
        }
        return Text("Lineup needs attention: " + issues.map(\.summary).joined(separator: ", "))
    }
}

#Preview {
    func player(_ name: String, _ position: Position, injury: InjuryStatus = .healthy) -> PlayerRef {
        PlayerRef(identity: .canonical(id: name, source: .gsis), name: name,
                  nflTeam: "KC", position: position, injuryStatus: injury)
    }
    let clean = Roster(teamID: "1", leagueID: "L", week: 3, slots: [
        .init(slot: .qb, isStarter: true, player: player("A", .qb)),
        .init(slot: .rb, isStarter: true, player: player("B", .rb)),
        .init(slot: .wr, isStarter: true, player: player("C", .wr)),
        .init(slot: .te, isStarter: true, player: player("D", .te)),
    ])
    let broken = Roster(teamID: "1", leagueID: "L", week: 3, slots: [
        .init(slot: .qb, isStarter: true, player: player("A", .qb)),
        .init(slot: .rb, isStarter: true, player: player("Hurt Guy", .rb, injury: .out)),
        .init(slot: .wr, isStarter: true, player: .emptyLineupSlot(platform: .sleeper)),
        .init(slot: .te, isStarter: true, player: player("Resting", .te), isOnBye: true),
    ])
    return VStack(alignment: .leading, spacing: SWSpacing.xl) {
        LineupStrip(roster: clean)
        LineupStrip(roster: broken)
    }
    .padding(SWSpacing.xl)
    .background(SWColor.canvas)
}
