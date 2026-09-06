import SwiftUI
import FantasyCore

/// Reorder and hide leagues.
///
/// A `List` in edit mode rather than drag-and-drop on the weekly view itself. The cards
/// there are translucent, sit over an animated shader, and are the source of a zoom
/// transition — dragging one would fight all three, and a half-working drag on the main
/// screen is worse than a reliable one here. The order set here is what the weekly view
/// shows.
struct LeagueEditor: View {
    let model: WeeklyModel
    @Environment(\.dismiss) private var dismiss
    @State private var visibilityToggles = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.visibleLeagues) { league in
                        row(league, hidden: false)
                    }
                    .onMove { source, destination in
                        model.moveVisibleLeagues(from: source, to: destination)
                    }
                } header: {
                    Text("Showing")
                } footer: {
                    Text("Drag to reorder. This is the order on your week.")
                }

                // Hidden leagues are a separate list, not a tail on this one. They are
                // not on screen, so they have no position — and letting them be dragged
                // implied an order that changed nothing, which is confusing at best.
                if !model.hiddenLeagues.isEmpty {
                    Section {
                        ForEach(model.hiddenLeagues) { league in
                            row(league, hidden: true)
                                .moveDisabled(true)
                        }
                    } header: {
                        Text("Hidden")
                    } footer: {
                        Text("Hidden leagues drop out of the week entirely, players included.")
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .feedback(.leagueVisibilityChanged, trigger: visibilityToggles)
            .navigationTitle("Your leagues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if model.allLeagues.isEmpty {
                    ContentUnavailableView(
                        "No leagues yet",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text("Add an account and they'll show up here.")
                    )
                }
            }
        }
        .tint(SWColor.accent)
    }

    private func row(_ league: League, hidden: Bool) -> some View {
        HStack(spacing: SWSpacing.md) {
            PlatformMark(platform: league.platform, size: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(league.name)
                    .font(SWType.bodyMedium)
                    .foregroundStyle(hidden ? SWColor.tertiary : SWColor.primary)
                    // The whole point of this screen is names that do not fit elsewhere,
                    // so this is the last place to clip one.
                    .lineLimit(2)
                Text(league.platform.displayName)
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
            }

            Spacer(minLength: SWSpacing.sm)

            Button {
                model.setHidden(!hidden, for: league.id)
                visibilityToggles += 1
            } label: {
                Image(systemName: hidden ? "eye.slash" : "eye")
                    .font(SWType.icon)
                    .foregroundStyle(hidden ? SWColor.tertiary : SWColor.accent)
            }
            // Without this the row's drag handle swallows the tap.
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}
