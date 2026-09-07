import SwiftUI

/// One week for the whole screen, and the reader can move it: back for last week's
/// finals, forward again to where the platforms are, "Now" to follow them. When one
/// platform has flipped and another has not, this is what keeps every card describing
/// the same seven days.
///
/// The row is laid out at caption height; each control's 44pt target overflows it above
/// and below, which SwiftUI allows and hit-tests.
struct WeekControl: View {
    let week: Int
    let canStepBack: Bool
    let canStepForward: Bool
    let isOnLiveWeek: Bool
    /// A week to show, or nil to follow the platforms again.
    let onShow: (Int?) -> Void

    var body: some View {
        HStack(spacing: 0) {
            step(systemImage: "chevron.left", label: "Previous week", enabled: canStepBack) { onShow(week - 1) }
            Text("Week \(week)")
                .font(SWType.caption)
                .foregroundStyle(SWColor.onSkySecondary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .padding(.horizontal, SWSpacing.xs)
            step(systemImage: "chevron.right", label: "Next week", enabled: canStepForward) { onShow(week + 1) }
            if !isOnLiveWeek {
                Button("Now") { onShow(nil) }
                    .accessibilityLabel("Back to the current week")
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.onSky)
                    .frame(minWidth: SWSize.hitTarget, minHeight: SWSize.hitTarget)
                    .contentShape(.rect)
                    .buttonStyle(.plain)
            }
        }
        .frame(height: SWSpacing.xl)
        .padding(.leading, -SWSpacing.md)
    }

    private func step(
        systemImage: String, label: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(SWType.glyph)
                .foregroundStyle(enabled ? SWColor.onSky : SWColor.onSkySecondary.opacity(0.35))
                .frame(width: SWSize.hitTarget, height: SWSize.hitTarget)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
