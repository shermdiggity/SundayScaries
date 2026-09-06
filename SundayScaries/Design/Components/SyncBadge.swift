import SwiftUI
import FantasyCore

/// Freshness, per league. Falls straight out of the resilience design and keeps
/// provider failures honest instead of invisible.
///
/// Fresh data says nothing at all — a badge that reads "up to date" on every card is
/// noise. Only stale and failed are worth a person's attention.
struct SyncBadge: View {
    let state: SyncState
    var reference: Date = .init()

    var body: some View {
        switch state {
        case .fresh:
            EmptyView()
        case let .stale(date):
            label(text: "Updated \(Self.relative(date, to: reference))", color: SWColor.tertiary)
        case .failed:
            label(text: "Couldn't refresh", color: SWColor.negative)
        }
    }

    private func label(text: String, color: Color) -> some View {
        Text(text)
            .font(SWType.caption)
            .foregroundStyle(color)
            .accessibilityLabel(Text(text))
    }

    static func relative(_ date: Date, to reference: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: reference)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: SWSpacing.md) {
        SyncBadge(state: .fresh(Date()))
        SyncBadge(state: .stale(Date().addingTimeInterval(-3600 * 26)))
        SyncBadge(state: .failed(ProviderError.transport(underlying: "offline")))
    }
    .padding(SWSpacing.xl)
    .background(SWColor.canvas)
}
