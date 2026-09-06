import SwiftUI
import FantasyCore

/// Makes any view that stands for a player open that player's season.
///
/// One modifier, so every place a player appears — a row, a card, a face on the podium —
/// behaves the same way and picks up the league from the screen it is on rather than
/// being told at each call site.
private struct PlayerTap: ViewModifier {
    let player: PlayerRef
    @Environment(\.playerInspector) private var inspector
    @Environment(\.contextLeagueID) private var leagueID

    func body(content: Content) -> some View {
        if let inspector, !player.isEmptyLineupSlot {
            Button {
                inspector.open(player, in: leagueID)
            } label: {
                content.contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows this player's season")
        } else {
            content
        }
    }
}

extension View {
    func playerTappable(_ player: PlayerRef) -> some View {
        modifier(PlayerTap(player: player))
    }
}

/// Every screen that shows players owns a `PlayerInspector` and presents `PlayerSheet`
/// from it. The sheet is attached FIRST so the environment values below enclose it: a
/// sheet attached outside `.environment(...)` presents content that never sees the value.
private struct PlayerSheetHost: ViewModifier {
    let inspector: PlayerInspector
    let model: WeeklyModel
    let leagueID: String?

    func body(content: Content) -> some View {
        content
            .sheet(item: inspector.binding) { selection in
                PlayerSheet(selection: selection, model: model)
                    .onAppear { diagLog("SHEET ON SCREEN for \(selection.player.name), presented by inspector \(inspector.owner)") }
                    .onDisappear { diagLog("sheet for \(selection.player.name) gone (owner \(inspector.owner))") }
            }
            .environment(\.playerInspector, inspector)
            .environment(\.contextLeagueID, leagueID)
    }
}

extension View {
    func playerSheetHost(_ inspector: PlayerInspector, model: WeeklyModel, leagueID: String?) -> some View {
        modifier(PlayerSheetHost(inspector: inspector, model: model, leagueID: leagueID))
    }
}
