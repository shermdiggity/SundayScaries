import SwiftUI

/// One figure with its caption, the way the detail screen, the team sheet and the player
/// sheet all show a stat: the number in the score face, what it is called underneath.
struct StatCell: View {
    let value: String
    let caption: String
    var tone: Color = SWColor.primary
    /// A quieter qualifier beside the number, such as "of 24".
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SWSpacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: SWSpacing.xxs) {
                Text(value)
                    .font(SWType.score)
                    .foregroundStyle(tone)
                    .contentTransition(.numericText())
                if let detail {
                    Text(detail).font(SWType.micro).foregroundStyle(SWColor.tertiary)
                }
            }
            Text(caption)
                .font(SWType.micro)
                .foregroundStyle(SWColor.tertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack(spacing: SWSpacing.xl) {
        StatCell(value: "118.4", caption: "Points")
        StatCell(value: "WR12", caption: "Rank", detail: "of 84")
        StatCell(value: "+2.1", caption: "vs. projection", tone: SWColor.positive, detail: "per game")
    }
    .padding(SWSpacing.xl)
    .background(SWColor.canvas)
}
