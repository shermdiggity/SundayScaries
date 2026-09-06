import SwiftUI
import FantasyCore

/// A platform's mark when its logo cannot be shown: its initial on its own colour. The
/// app falls back to it while a logo loads; the widgets, which cannot fetch, use nothing else.
struct PlatformMonogram: View {
    let platform: Platform
    var size: CGFloat = 18

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(SWColor.platform(platform))
            .overlay {
                Text(platform.displayName.prefix(1))
                    // Scales with the mark, so the size is geometry rather than a
                    // step on the type scale.
                    .font(SWType.mark(size * 0.6))
                    .foregroundStyle(SWColor.onPlatform(platform))
            }
    }
}
