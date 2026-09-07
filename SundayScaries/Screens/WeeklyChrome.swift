import SwiftUI

/// The one control at the top of the weekly view: the way to the You sheet.
struct AccountButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Deliberately not glass: anything that samples its backdrop has to
            // re-resolve when this screen comes back from a push, and that frame
            // is visible.
            Image(systemName: "person.crop.circle")
                .font(SWType.icon)
                .foregroundStyle(SWColor.onSky)
                .padding(SWSpacing.md)
                .background {
                    Circle()
                        .fill(SWColor.surface.opacity(0.72))
                        .overlay { Circle().strokeBorder(SWColor.hairline, lineWidth: 1) }
                }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Accounts")
    }
}

/// The way into reordering and hiding — visible, not a long press nobody finds.
/// Doubles as the way back to anything hidden, because hiding something on this
/// screen removes it from this screen, so the way back has to be here too.
struct EditLeaguesRow: View {
    let hiddenCount: Int
    let isShown: Bool
    let action: () -> Void

    var body: some View {
        if isShown {
            Button(action: action) {
                HStack(spacing: SWSpacing.xs) {
                    Image(systemName: "slider.horizontal.3").font(SWType.micro).accessibilityHidden(true)
                    Text("Edit leagues")
                    if hiddenCount > 0 {
                        Text("·").foregroundStyle(SWColor.onSkySecondary.opacity(0.6))
                        Text("\(hiddenCount) hidden")
                    }
                }
                .font(SWType.caption)
                .foregroundStyle(SWColor.onSkySecondary)
                .frame(maxWidth: .infinity, minHeight: SWSize.hitTarget)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }
}
