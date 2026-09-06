import SwiftUI

/// The one look for a screen that has nothing to show yet, or could not get it. Empty
/// says so quietly; an error names the problem and, when there is a way back, offers
/// it. Loading is the skeletons in `Skeleton.swift`, never a spinner.
struct StateView: View {
    enum Kind { case empty, error }

    let kind: Kind
    let title: LocalizedStringKey
    var detail: Text?
    /// Present when trying again can change the outcome.
    var retry: (() -> Void)?
    /// On the sky the text is white and there is no panel; everywhere else it sits on
    /// the surface.
    var onSky = false

    var body: some View {
        VStack(alignment: .leading, spacing: SWSpacing.sm) {
            VStack(alignment: .leading, spacing: SWSpacing.xs) {
                Text(title)
                    .font(SWType.headline)
                    .foregroundStyle(titleColor)
                if let detail {
                    detail
                        .font(SWType.caption)
                        .foregroundStyle(onSky ? SWColor.onSkySecondary : SWColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            if let retry {
                Button("Try again", action: retry)
                    .font(SWType.bodyMedium)
                    .foregroundStyle(onSky ? SWColor.onSky : SWColor.accent)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(onSky ? 0 : SWSpacing.lg)
        .background {
            if !onSky {
                RoundedRectangle(cornerRadius: SWRadius.md, style: .continuous)
                    .fill(SWColor.surface)
            }
        }
    }

    private var titleColor: Color {
        switch (kind, onSky) {
        case (.error, _):   SWColor.negative
        case (.empty, true): SWColor.onSky
        case (.empty, false): SWColor.primary
        }
    }
}

#Preview {
    VStack(spacing: SWSpacing.lg) {
        StateView(kind: .empty, title: "No roster to show for this team.")
        StateView(kind: .error, title: "Couldn't refresh", detail: Text("Showing the last numbers that loaded."), retry: {})
    }
    .padding(SWSpacing.xl)
    .background(SWColor.canvas)
}
