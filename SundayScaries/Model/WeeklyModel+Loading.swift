import Foundation
import SwiftUI
import FantasyCore
import FantasyProviders

/// The load: resolve the season, discover leagues, decide the week, then fetch every
/// league in parallel (`+Fetch`). A pull, the live poll, a week step, foregrounding and a
/// sign-in all come through here.
extension WeeklyModel {
    /// The stores one load talks to.
    struct Backing {
        let store: any SnapshotStore
        let http: any HTTPClient
        let crosswalk: PlayerCrosswalk
    }

    /// Everything decided before the leagues are fetched.
    struct LoadPlan {
        let context: LoadContext
        let sourceOfLeague: [String: any PlatformProvider]
        let leagues: [League]
        let week: Int
        let mode: FetchMode
    }

    /// `force` is a user's pull or the live poll: week-scoped data is re-fetched even when
    /// its cache is fresh. Without it a pull inside the TTL showed skeletons and returned
    /// the same numbers.
    ///
    /// A load that already has snapshots is QUIET: cards stay on screen and each is
    /// replaced in place as it resolves, so a poll during a game rolls the numbers rather
    /// than flashing the whole screen to skeletons every minute.
    func load(season: String? = nil, force: Bool = false) async {
        guard hasAccount else {
            clearForNoAccount()
            return
        }
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        loadProblem = nil
        defer { if generation == loadGeneration { isLoading = false } }
        #if DEBUG
        let loadStarted = Date()
        print("[load] begin forced=\(force) quiet=\(!allSnapshots.isEmpty)")
        defer {
            print(String(format: "[load] end forced=%@ cancelled=%@ after %.2fs",
                         String(force), String(Task.isCancelled), Date().timeIntervalSince(loadStarted)))
        }
        #endif

        let (store, http) = Self.infrastructure()
        let crosswalkStore = CrosswalkStore(http: http, store: store)
        guard let crosswalk = try? await crosswalkStore.crosswalk() else {
            loadProblem = .playerIndexUnavailable
            return
        }
        if season == nil, !force {
            // A fresh top-level load: forget the last one's fallbacks.
            triedPreviousSeason = false
            refreshedForWeekFlip = false
            seasonFallback = nil
        }
        let backing = Backing(store: store, http: http, crosswalk: crosswalk)
        guard let plan = await prepare(season: season, force: force, backing: backing) else { return }

        var portfolioInput = await fetchLeagues(plan, generation: generation)
        guard generation == loadGeneration else { return }

        // Hidden leagues' rosters were not refetched; keep what they had so un-hiding
        // does not blank the portfolio until the next load. A league that is gone from
        // the platform is gone from here too, rosters included: a disconnected account's
        // starters used to keep feeding Your Guys until the next cold start.
        let current = Set(allLeagues.map(\.id))
        let loadedIDs = Set(plan.leagues.map(\.id))
        portfolioInput += allWeekRosters.filter { !loadedIDs.contains($0.league.id) && current.contains($0.league.id) }
        allSnapshots.removeAll { !current.contains($0.id) }
        allWeekRosters = portfolioInput
        applyPreferences()
        logRankingDiagnostics()
        attribution = [
            await crosswalkStore.attribution,
            ScheduleSource.nflverse.attribution,
            await plan.context.scoreboard.attribution,
        ]
        lastLoaded = Date()
        // The widget shows the live week. Stepping back to look at last week's finals
        // must not put last week on the home screen.
        if isOnLiveWeek { await WidgetBridge.publish(from: self) }
    }

    /// Season, leagues, scoring options and the week, in that order. Nil means this
    /// load is finished: nothing was found, or it handed off to a second load (the
    /// previous season, or a refresh after a week flip).
    private func prepare(season: String?, force: Bool, backing: Backing) async -> LoadPlan? {
        let mode: FetchMode = force ? .refresh : .cacheFirst
        let resolvedSeason = await resolveSeason(requested: season, http: backing.http)
        disabledPlatforms = await RemoteConfig.disabledPlatforms()
        let ctx = makeContext(
            http: backing.http, store: backing.store, crosswalk: backing.crosswalk, season: resolvedSeason, mode: mode
        )
        let discovery = await discoverLeagues(from: ctx.sources, season: resolvedSeason)

        // A new season with no leagues in it yet is not "you have no leagues": it is
        // March. Show the last season that had some, and say so.
        if discovery.isEmptyWithoutFailure, season == nil, Self.seasonOverride == nil, !triedPreviousSeason,
           let year = Int(resolvedSeason) {
            triedPreviousSeason = true
            let previous = String(year - 1)
            seasonFallback = SeasonFallback(shown: previous, requested: resolvedSeason)
            await load(season: previous, force: force)
            return nil
        }
        guard !discovery.leagues.isEmpty else {
            // "None found" and "we could not ask" are different problems with different
            // fixes, and the empty case used to read as the first no matter which it was.
            loadProblem = discovery.failures.first ?? (hasESPN && !hasSleeper
                ? .espnReturnedNothing(season: resolvedSeason)
                : .noLeagues(season: resolvedSeason))
            snapshots = []
            knownLeagues = []
            positions = []
            return nil
        }
        // A platform that failed while another worked is worth saying, but must not
        // replace the leagues that did load.
        loadProblem = discovery.failures.first

        // Names and platforms are known now, so placeholders can carry them and only
        // the matchup needs to be skeletal. Hidden leagues are known but not fetched.
        allLeagues = discovery.leagues
        applyPreferences()
        scoringOptions = await collectScoringOptions(sources: discovery.sourceOfLeague)

        // The leading week: the furthest any platform has got. Sleeper's `/state` is read
        // live; a league's own week may lag it by a morning — which is exactly the case
        // showing every league on ONE week is for.
        let platformWeek = await ctx.sources.first?.provider.currentWeek()
        liveWeek = [platformWeek, discovery.leagues.compactMap(\.currentWeek).max()].compactMap { $0 }.max()
        let shownWeek = max(1, min(viewedWeek ?? liveWeek ?? 1, liveWeek ?? Int.max))
        week = shownWeek

        // The week-flip trigger. The league list is cached for six hours and carries each
        // league's week; Sleeper's `/state` is read live. On a Tuesday morning the hero
        // could say "Week 3" over cards still on Week 2 for the rest of the morning. If
        // the platform is ahead of any cached league, re-read everything in refresh mode
        // — once, so a league that is genuinely behind (a two-week playoff round) cannot
        // loop it.
        if !force, !refreshedForWeekFlip, discovery.lagsBehind(liveWeek) {
            refreshedForWeekFlip = true
            await load(season: season, force: true)
            return nil
        }

        // Hidden leagues are not fetched. Loading them "so un-hiding is instant" doubled
        // the work of every pull for cards nobody was looking at; un-hiding now fetches
        // that one league (`setHidden`). Any snapshot a hidden league already has is kept.
        let toLoad = allLeagues.filter { !hiddenLeagueIDs.contains($0.id) }
        return LoadPlan(
            context: ctx, sourceOfLeague: discovery.sourceOfLeague, leagues: toLoad, week: shownWeek, mode: mode
        )
    }

    /// Disconnecting the last platform must clear the screen, not freeze it on whatever
    /// was loaded before.
    private func clearForNoAccount() {
        allLeagues = []
        allSnapshots = []
        allWeekRosters = []
        knownLeagues = []
        snapshots = []
        positions = []
        scoringOptions = []
        week = nil
        liveWeek = nil
        viewedWeek = nil
        lastLoaded = nil
        seasonFallback = nil
        loadProblem = nil
        // The widget holds the last thing the app knew, in a container the reader
        // never sees. An account they removed must not keep living there.
        WidgetBridge.clear()
    }

    /// A season override, for looking at a finished season during development. Set with
    /// a launch argument: `-seasonOverride 2025`. Never compiled into Release.
    private static var seasonOverride: String? {
        #if DEBUG
        let value = UserDefaults.standard.string(forKey: "seasonOverride") ?? ""
        return value.isEmpty ? nil : value
        #else
        return nil
        #endif
    }

    /// The platform's own idea of the season first. A calendar rule cannot know when
    /// Sleeper opens the new year; `league_season` can, and until it flips the leagues
    /// people actually have are last season's.
    private func resolveSeason(requested: String?, http: any HTTPClient) async -> String {
        if let requested { return requested }
        if let override = Self.seasonOverride { return override }
        if hasSleeper, let platformSeason = try? await SleeperProvider.leagueSeason(http: http) {
            return platformSeason
        }
        return Self.currentSeason()
    }

    /// What every connected platform lists, and which failed to answer.
    private struct Discovery {
        var leagues: [League] = []
        var sourceOfLeague: [String: any PlatformProvider] = [:]
        var failures: [LoadProblem] = []

        var isEmptyWithoutFailure: Bool { leagues.isEmpty && failures.isEmpty }

        /// A cached Sleeper league still on last week while the platform has flipped.
        func lagsBehind(_ liveWeek: Int?) -> Bool {
            guard let live = liveWeek else { return false }
            return leagues.contains { $0.platform == .sleeper && ($0.currentWeek ?? live) < live }
        }
    }

    /// A platform that fails must never cost you the other one, so each is gathered
    /// separately and its error is remembered rather than thrown.
    private func discoverLeagues(from sources: [PlatformSource], season: String) async -> Discovery {
        var discovery = Discovery()
        discovery.failures = disabledPlatforms.map { .platformDisabled($0.key, reason: $0.value) }
        for source in sources {
            do {
                let found = try await source.provider.leagues(for: source.account)
                #if DEBUG
                print("[load] \(source.provider.platform.rawValue): \(found.count) leagues — \(found.map(\.name))")
                #endif
                for league in found { discovery.sourceOfLeague[league.id] = source.provider }
                discovery.leagues += found
            } catch {
                #if DEBUG
                print("[load] \(source.provider.platform.rawValue) FAILED: \(error)")
                #endif
                discovery.failures.append(.platformFailed(
                    source.provider.platform, PlatformFailure(error),
                    season: season, handle: handle(for: source.provider.platform)
                ))
            }
        }
        return discovery
    }

    /// The rules every league scores by, for reading a player under any of them.
    private func collectScoringOptions(sources: [String: any PlatformProvider]) async -> [ScoringOption] {
        var options: [ScoringOption] = []
        for league in allLeagues {
            guard let source = sources[league.id] else { continue }
            options.append(ScoringOption(
                leagueID: league.id, name: league.name, platform: league.platform,
                rules: await source.scoringRules(for: league), kind: league.scoringKind
            ))
        }
        return options
    }

    /// The pull on the weekly view. The work runs in a task the MODEL owns, not the one
    /// SwiftUI hands `.refreshable`: that task is cancelled when the control decides the
    /// gesture is over, a cancelled URLSession call throws, and every provider's
    /// cache-first fallback then quietly returns the OLD value — so a pull looked like a
    /// refresh and changed nothing. An unstructured task is not cancelled with its
    /// parent, so this one finishes; the pull only waits for it.
    func refreshAll() async {
        let task = Task { await load(force: true) }
        await task.value
    }

    /// One league, refetched in refresh mode, replaced in place. Everything else on the
    /// screen is left alone — the detail's refresh button used to reload every league,
    /// which took as long as a cold start for a screen showing one of them.
    /// Returns false when the snapshot on screen could not be replaced; the last good one
    /// stays up either way.
    @discardableResult
    func refresh(leagueID: String) async -> Bool {
        guard let league = allLeagues.first(where: { $0.id == leagueID }),
              let shownWeek = week ?? liveWeek else { return false }
        let season = loadedSeason
        let task = Task<Bool, Never> { [self] in
            let (store, http) = Self.infrastructure()
            // Cached after the first load; this is a disk read.
            guard let crosswalk = try? await CrosswalkStore(http: http, store: store).crosswalk() else { return false }
            let ctx = makeContext(http: http, store: store, crosswalk: crosswalk, season: season, mode: .refresh)
            guard let source = ctx.sources.first(where: { $0.provider.platform == league.platform })?.provider else {
                return false
            }
            do {
                let load = try await LeagueSnapshotBuilder(
                    source: source, scheduleStore: ctx.scheduleStore, scoreboard: ctx.scoreboard, mode: .refresh
                ).build(league: league, week: shownWeek)
                // The reader stepped to another week while this ran. The card for that
                // week is someone else's to fill.
                guard week == shownWeek else { return false }
                if let index = allSnapshots.firstIndex(where: { $0.id == leagueID }) {
                    allSnapshots[index] = load.snapshot
                } else {
                    allSnapshots.append(load.snapshot)
                }
                allWeekRosters.removeAll { $0.league.id == leagueID }
                if let rosters = load.weekRosters { allWeekRosters.append(rosters) }
                logLineup(load.snapshot, note: "single-refresh")
                applyPreferences()
                if isOnLiveWeek { await WidgetBridge.publish(from: self) }
                return true
            } catch {
                // A failed refresh keeps the last good snapshot, same as the full load.
                #if DEBUG
                print("[refresh] \(league.name) failed: \(error)")
                #endif
                return false
            }
        }
        return await task.value
    }
}
