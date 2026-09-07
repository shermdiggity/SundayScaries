import Foundation
import Observation
import SwiftUI
import FantasyCore
import FantasyProviders

/// The weekly view's model: what is loaded, what is shown, and the reader's preferences
/// over it. The loading pipeline lives in `WeeklyModel+Loading` and `+Fetch`; what the
/// screen reads off the loaded state in `+Readout`; the account in `+Account`. The
/// state is plain `var` because those files write it; nothing outside the model does.
@MainActor
@Observable
final class WeeklyModel {
    var snapshots: [LeagueSnapshot] = []
    /// The leagues we know exist, in display order, as soon as the league list returns.
    ///
    /// The list is built from this rather than from `snapshots`, so it is the right
    /// length from the first moment and each card fills in where its placeholder was —
    /// instead of three generic skeletons being replaced wholesale by five real cards.
    var knownLeagues: [League] = []
    var positions: [PlayerPosition] = []
    var isLoading = false
    /// Which load is the newest. Loads overlap freely (the pull, the poll, a week step,
    /// foregrounding, a sign-in) and each streams its leagues into `allSnapshots` as
    /// they resolve, so without this two of them could leave the screen on two weeks and
    /// the first to finish switched the skeletons off for the second. A load that has
    /// been superseded stops publishing; the newest one owns the screen.
    var loadGeneration = 0
    var loadProblem: LoadProblem?
    /// The week the whole screen shows.
    var week: Int?
    /// The leading platform's week — Sleeper's `/state`, else the furthest any league
    /// has got. What `week` is unless the reader has stepped away from it.
    var liveWeek: Int?
    /// Set by the week control; nil means "follow the platforms".
    var viewedWeek: Int?
    var attribution: [String] = []
    /// Set when the requested season had no leagues and the one before it is shown instead.
    var seasonFallback: SeasonFallback?
    /// When the last load finished, so a return to the foreground can decide whether
    /// what is on screen is old enough to re-read.
    var lastLoaded: Date?
    var triedPreviousSeason = false
    var refreshedForWeekFlip = false

    /// Kept from the last load so the player sheet can read a season without rebuilding
    /// the stack. Both cache to disk, so a season opened twice costs nothing the second
    /// time. Written by `makeContext`.
    var playerSeasons: PlayerSeasonService?
    /// Platforms the kill switch has paused, from the last load that could read it.
    var disabledPlatforms: [Platform: String] = [:]
    var loadedSeason: String = ""
    var scoringOptions: [ScoringOption] = []

    /// Every league we loaded, hidden ones included, in the user's order. This is what
    /// the editor lists — you cannot unhide a league you cannot see.
    var allLeagues: [League] = []

    /// Rosters for every league we loaded, kept so hiding or unhiding one recomputes
    /// cross-league exposure instantly instead of forcing a refetch.
    var allWeekRosters: [LeagueWeekRosters] = []

    /// Every loaded snapshot, hidden leagues included. `snapshots` is derived from this.
    ///
    /// Hiding used to FILTER `snapshots` in place, which deleted the hidden league's data
    /// — so un-hiding brought back a league with nothing behind it, and the weekly view
    /// showed a loading skeleton for it until the next refresh refetched. Hidden means
    /// not shown, not not loaded.
    var allSnapshots: [LeagueSnapshot] = []

    func isHidden(_ league: League) -> Bool { hiddenLeagueIDs.contains(league.id) }

    /// The leagues on screen, in the user's order. The only ones that HAVE an order.
    var visibleLeagues: [League] { allLeagues.filter { !isHidden($0) } }

    /// Put away, alphabetical. Order is meaningless for something that is not shown, so
    /// none is kept: a hidden league has no position to lose or to fight over.
    var hiddenLeagues: [League] {
        allLeagues.filter { isHidden($0) }.sorted { $0.name < $1.name }
    }

    /// Reorders the visible leagues only, from the editor's own indices.
    func moveVisibleLeagues(from source: IndexSet, to destination: Int) {
        var visible = visibleLeagues
        visible.move(fromOffsets: source, toOffset: destination)
        setVisibleOrder(visible)
    }

    func setHidden(_ hidden: Bool, for leagueID: String) {
        var ids = hiddenLeagueIDs
        if hidden { ids.insert(leagueID) } else { ids.remove(leagueID) }
        hiddenLeagueIDs = ids
        applyPreferences()
        // Hidden leagues are not fetched, so one coming back may have nothing behind it
        // yet. Its card shows a skeleton until this lands — never a blank.
        if !hidden, !allSnapshots.contains(where: { $0.id == leagueID }) {
            Task { await refresh(leagueID: leagueID) }
        }
    }

    /// Sets the order outright. Only visible leagues have one: a hidden league is simply
    /// absent from the list, and when it comes back it joins the end — predictable, and
    /// far simpler than the interleaving this used to do to preserve a position for
    /// something that was not on screen.
    func setVisibleOrder(_ visible: [League]) {
        leagueOrder = visible.map(\.id)
        applyPreferences()
    }

    /// Re-derives what the weekly view shows from what was loaded plus the user's
    /// preferences. Called after an edit so hiding or reordering takes effect
    /// immediately, with no refetch.
    func applyPreferences() {
        let order = leagueOrder
        let rank: (League) -> Int = { order.firstIndex(of: $0.id) ?? Int.max }
        allLeagues = allLeagues.sorted {
            rank($0) != rank($1) ? rank($0) < rank($1) : $0.name < $1.name
        }
        let visible = allLeagues.filter { !hiddenLeagueIDs.contains($0.id) }
        withAnimation(SWMotion.standard) {
            knownLeagues = visible
            // Derived, never filtered in place: the hidden league's snapshot stays in
            // `allSnapshots`, so un-hiding is instant and needs no refetch.
            snapshots = allSnapshots
                .filter { !hiddenLeagueIDs.contains($0.league.id) }
                .sorted {
                    rank($0.league) != rank($1.league)
                        ? rank($0.league) < rank($1.league)
                        : $0.league.name < $1.league.name
                }
            // Hidden means hidden. A league you have put away should not be quietly
            // deciding that a player is "in three of your leagues" — the counts, the
            // ranking and the whole cross-league story are about the leagues you are
            // actually looking at.
            positions = Portfolio.positions(
                across: allWeekRosters.filter { !hiddenLeagueIDs.contains($0.league.id) }
            )
        }
    }

    // MARK: Stepping through weeks

    var canStepBack: Bool { (week ?? 1) > 1 }
    var canStepForward: Bool { (week ?? 0) < (liveWeek ?? 0) }
    var isOnLiveWeek: Bool { viewedWeek == nil || week == liveWeek }

    /// Shows a different week on every league at once. Nil follows the platforms again.
    /// Past weeks come from cache and appear at once; the leading week refetches live.
    func show(week target: Int?) async {
        if let target {
            viewedWeek = max(1, min(target, liveWeek ?? target))
        } else {
            viewedWeek = nil
        }
        await load()
    }
}
