import SwiftUI
import FantasyCore

/// The signature component: exposure as a physical quantity.
///
/// One bar per league, stacked. A league you own him in is solid; one you don't is a
/// hairline. Five solid bars read as a *block*; one reads as a *line*. That is weight
/// you feel without counting, which is the whole point — no number, no label.
///
/// Facing a player inverts it: filled bars become outlines, so the same shape reads as
/// absence rather than mass, and being faced everywhere feels hollow.
struct ExposureMeter: View {
    enum Kind {
        /// In your starting lineup — what your week actually rides on.
        case started
        /// In an opponent's starting lineup.
        case faced
    }

    let filled: Int
    let total: Int
    var kind: Kind = .started
    var barHeight: CGFloat = SWSpacing.sm
    var barWidth: CGFloat = SWSize.hitTarget

    /// An unfilled bar is a hairline at this height; every bar's corners and the faced
    /// outline share one stroke.
    private static let emptyHeight: CGFloat = 2
    private static let stroke: CGFloat = 1.5

    private var tint: Color {
        switch kind {
        case .started: SWColor.positive
        case .faced:   SWColor.negative
        }
    }

    var body: some View {
        VStack(spacing: SWSpacing.xxs) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                bar(isFilled: index < filled)
            }
        }
        .animation(SWMotion.reveal, value: filled)
        .accessibilityElement()
        .accessibilityLabel(
            {
                switch kind {
                case .started: Text("Starting for you in \(filled) of \(total) leagues")
                case .faced:   Text("Starting against you in \(filled) of \(total) leagues")
                }
            }()
        )
    }

    @ViewBuilder
    private func bar(isFilled: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.stroke, style: .continuous)
        switch (isFilled, kind) {
        case (false, _):
            shape.fill(SWColor.onSky.opacity(0.22))
                .frame(width: barWidth, height: Self.emptyHeight)
        case (true, .started):
            shape.fill(tint)
                .frame(width: barWidth, height: barHeight)
        case (true, .faced):
            shape.strokeBorder(tint, lineWidth: Self.stroke)
                .background(shape.fill(tint.opacity(0.14)))
                .frame(width: barWidth, height: barHeight)
        }
    }
}

#Preview("Concentration reads as shape") {
    HStack(alignment: .bottom, spacing: SWSpacing.xl) {
        ForEach([5, 4, 3, 2, 1], id: \.self) { count in
            ExposureMeter(filled: count, total: 5)
        }
        ExposureMeter(filled: 4, total: 5, kind: .faced)
    }
    .padding(SWSpacing.xl)
    .background(SWColor.canvas)
}
