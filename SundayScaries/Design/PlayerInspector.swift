import SwiftUI
import FantasyCore

/// Who was tapped, and which league's rules to open them under.
///
/// Every screen that can show a player owns one of these and presents `PlayerSheet` from
/// it. Each screen has its OWN, not a shared one: a sheet presented from a sheet has to
/// come from the topmost view, and one object bound to several `.sheet` modifiers would
/// have them all trying to present at once.
@MainActor
@Observable
final class PlayerInspector {
    struct Selection: Identifiable {
        let player: PlayerRef
        /// The league whose scoring the sheet opens with. The one being looked at, or
        /// the first on the weekly view when there is no single league in view.
        let leagueID: String?
        var id: String { (player.canonicalID ?? player.name) + "|" + (leagueID ?? "") }
    }

    /// Which screen owns this inspector, for the console: "weekly", "detail:<league>",
    /// "team", "matchup". A sheet that appears after a swipe-close is either the dead
    /// detail's or the weekly view's, and only the owner tells them apart.
    let owner: String

    init(owner: String) { self.owner = owner }

    var selection: Selection? {
        didSet {
            diagLog("inspector \(owner) selection -> \(selection.map { $0.player.name } ?? "nil")")
        }
    }
    /// False once the screen that owns this inspector has been closed. A league detail
    /// popped by the zoom transition's swipe stays hit-testable for a beat after it has
    /// visibly gone, so a quick tap on the weekly view landed on the dead detail and
    /// opened a player from it. Its owner turns this off the moment it stops being the
    /// selected league; `open` is then a no-op.
    var isEnabled = true {
        didSet { diagLog("inspector \(owner) isEnabled -> \(isEnabled)") }
    }
    /// Asked at tap time. A pushed screen sets this from a `NavigationStackProbe`, so a
    /// tap that lands while the screen is being swiped away, before SwiftUI has cleared
    /// its selection, presents nothing.
    @ObservationIgnored var isOnStack: @MainActor () -> Bool = { true }
    @ObservationIgnored var describe: @MainActor () -> String = { "no probe" }

    func open(_ player: PlayerRef, in leagueID: String?) {
        guard !player.isEmptyLineupSlot else { return }
        guard isEnabled else {
            diagLog("inspector \(owner) REFUSED \(player.name): disabled (its screen is closed)\n   \(describe())")
            return
        }
        let allowed = isOnStack()
        diagLog("inspector \(owner) tap on \(player.name) enabled=\(isEnabled) decision=\(allowed ? "PRESENT" : "REFUSE (not on stack)")\n   \(describe())")
        guard allowed else { return }
        selection = Selection(player: player, leagueID: leagueID)
    }

    var binding: Binding<Selection?> {
        Binding(get: { self.selection }, set: { self.selection = $0 })
    }
}

extension EnvironmentValues {
    @Entry var playerInspector: PlayerInspector?
    /// The league a screen is "in", so a tap on a player knows whose rules to open with.
    @Entry var contextLeagueID: String?
}
