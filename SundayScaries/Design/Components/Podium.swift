import SwiftUI
import FantasyCore

/// The top three, on a podium. The screenshot people actually send to the group chat.
///
/// Second, first, third — left to right, heights stepped — because that is what a
/// podium looks like and nobody needs it explained. Everyone below fourth is a list,
/// since the drama is only ever at the top.
struct Podium: View {
    struct Entry: Identifiable {
        let rank: Int
        let teamName: String
        /// The headline number on the plinth.
        let powerPoints: String
        /// What that number is called — "power pts" once games are played, "projected"
        /// before that.
        let unit: LocalizedStringKey
        let allPlay: LocalizedStringKey
        let face: PlayerRef?
        let isMine: Bool
        var id: Int { rank }
    }

    let entries: [Entry]
    /// Tapping a plinth opens that team.
    var onSelect: (String) -> Void = { _ in }
    var idForRank: (Int) -> String? = { _ in nil }

    /// Podium order: 2nd, 1st, 3rd.
    private var ordered: [Entry] {
        let byRank = Dictionary(uniqueKeysWithValues: entries.prefix(3).map { ($0.rank, $0) })
        return [byRank[2], byRank[1], byRank[3]].compactMap { $0 }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: SWSpacing.sm) {
            ForEach(ordered) { entry in
                Button {
                    if let id = idForRank(entry.rank) { onSelect(id) }
                } label: {
                    column(entry)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func column(_ entry: Entry) -> some View {
        VStack(spacing: SWSpacing.sm) {
            if let face = entry.face {
                Headshot(player: face, size: entry.rank == 1 ? 60 : 46)
                    .playerTappable(face)
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(medal(entry.rank))
                            .frame(width: 22, height: 22)
                            .overlay {
                                Text("\(entry.rank)")
                                    .font(SWType.scoreMicro)
                                    .foregroundStyle(SWColor.canvas)
                            }
                            .offset(x: 2, y: 2)
                    }
            }

            // A fixed two-line box: without it a long team name pushes its plinth down
            // and the row stops being a podium.
            Text(entry.teamName)
                .font(SWType.caption)
                .foregroundStyle(entry.isMine ? SWColor.accent : SWColor.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(height: 34, alignment: .top)

            // The plinth. Its height is the ranking, so the shape carries the result.
            RoundedRectangle(cornerRadius: SWRadius.sm, style: .continuous)
                .fill(medal(entry.rank).opacity(entry.isMine ? 0.85 : 0.55))
                .frame(height: plinthHeight(entry.rank))
                .overlay(alignment: .top) {
                    VStack(spacing: 0) {
                        Text(entry.powerPoints)
                            .font(SWType.score)
                            .foregroundStyle(SWColor.canvas)
                        Text(entry.unit)
                            .font(SWType.micro)
                            .foregroundStyle(SWColor.canvas.opacity(0.75))
                        Text(entry.allPlay)
                            .font(SWType.scoreMicro)
                            .foregroundStyle(SWColor.canvas.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.top, 2)
                    }
                    .padding(.top, SWSpacing.sm)
                }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(entry.rank). \(entry.teamName), \(entry.powerPoints) \(Text(entry.unit))"))
    }

    private func plinthHeight(_ rank: Int) -> CGFloat {
        switch rank {
        case 1:  100
        case 2:  82
        default: 68
        }
    }

    private func medal(_ rank: Int) -> Color {
        switch rank {
        case 1:  SWColor.accent
        case 2:  Color(red: 0.85, green: 0.87, blue: 0.92)
        default: Color(red: 0.93, green: 0.66, blue: 0.44)
        }
    }
}
