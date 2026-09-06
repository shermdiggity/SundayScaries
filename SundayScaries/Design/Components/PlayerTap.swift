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
