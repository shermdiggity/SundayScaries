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
    @Environment(\.dynamicTypeSize) private var typeSize
    private var isAccessibilitySize: Bool { typeSize.isAccessibilitySize }

    /// The rank badge on the winner's face, and the two-line box a team name gets.
    private static let rankBadge: CGFloat = 22
    private static let nameBox: CGFloat = 34

    /// Podium order: 2nd, 1st, 3rd.
    private var ordered: [Entry] {
        let byRank = Dictionary(uniqueKeysWithValues: entries.prefix(3).map { ($0.rank, $0) })
        return [byRank[2], byRank[1], byRank[3]].compactMap { $0 }
    }

    var body: some View {
        let layout = isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: SWSpacing.md))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: SWSpacing.sm))
        return layout {
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
                Headshot(player: face, size: entry.rank == 1 ? SWSize.facePortrait : SWSize.faceHero)
                    .playerTappable(face)
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(SWColor.medal(entry.rank))
                            .frame(width: Self.rankBadge, height: Self.rankBadge)
                            .overlay {
                                Text("\(entry.rank)")
                                    .font(SWType.scoreMicro)
                                    .foregroundStyle(SWColor.canvas)
                            }
                            .offset(x: SWSpacing.xxs, y: SWSpacing.xxs)
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
                .frame(height: isAccessibilitySize ? nil : Self.nameBox, alignment: .top)

            // The plinth. Its height is the ranking, so the shape carries the result.
            RoundedRectangle(cornerRadius: SWRadius.sm, style: .continuous)
                .fill(SWColor.medal(entry.rank).opacity(entry.isMine ? 0.85 : 0.55))
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
                            .padding(.top, SWSpacing.xxs)
                    }
                    .padding(.top, SWSpacing.sm)
                }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(entry.rank). \(entry.teamName), \(entry.powerPoints) \(Text(entry.unit))"))
    }

    /// Stepped so the shape carries the result before the numbers do.
    private func plinthHeight(_ rank: Int) -> CGFloat {
        switch rank {
        case 1:  100
        case 2:  82
        default: 68
        }
    }
}
