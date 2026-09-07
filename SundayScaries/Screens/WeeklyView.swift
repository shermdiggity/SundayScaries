import SwiftUI
import FantasyCore

/// The app's only screen, and its front door.
///
/// Ordered by what decays: the sky and the one fact that defines your Sunday, then the
/// leagues you can still do something about, then the portfolio, then the retrospective.
struct WeeklyView: View {
    @State private var model = WeeklyModel()
    @State private var inspector = PlayerInspector(owner: "weekly")
    /// False for the first frame only. The launch screen is the flat `SWColor.launch`;
    /// the sky fades in over it, so launch and first frame are one continuous motion.
    /// The TYPE is never part of this — it is on screen from frame one.
    @State private var skyIsUp = false
    @State private var showingESPNLogin = false
    @State private var showingMFLConnect = false
    @State private var showingYahooLogin = false
    /// Outcomes of the welcome cards' connects, counted so a load the reader started can
    /// be felt and one the poll started cannot.
    @State private var connectSuccesses = 0
    @State private var connectFailures = 0
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingAccount = false
    @State private var showingLeagueEditor = false
    @State private var selectedLeagueID: String?
    #if DEBUG
    @State private var debugDestinationOpened = false
    #endif
    /// Which card is the zoom transition's source RIGHT NOW. Set on tap, kept through
    /// the push and the whole pop animation, then retired.
    ///
    /// A card's `matchedTransitionSource` id used to be its league id, permanently. The
    /// transition system keeps a snapshot bound to that id, and after a pop that snapshot
    /// sometimes outlived the animation — a card frozen at its screen position while the
    /// real list scrolled underneath, sliding behind the card below. Retiring the id
    /// once the pop has finished leaves nothing for a stale snapshot to be bound to.
    @State private var transitionSourceID: String?
    /// Which retirement of the source is current. A card re-tapped inside the 0.7s hold
    /// used to have its source nulled mid-push by the previous close's timer.
    @State private var sourceRetirement = UUID()
    /// A widget or a link opened a league the screen could not show yet (still loading,
    /// or hidden). Opened the moment its snapshot exists.
    @State private var pendingLeagueID: String?
    #if DEBUG
    /// The last card that was closed, so its frame can be logged against its neighbour.
    @State private var diagnoseID: String?
    #endif
    /// Scroll position, as an object rather than `@State`, so that a scroll tick
    /// re-renders the sky and NOT this whole screen. See `ScrollTracker`.
    @State private var scroll = ScrollTracker()

    @Namespace private var cardTransition

    private var palette: SkyPalette { Sky.palette() }

    /// The card that was just closed and the one directly below it. If both frames move
    /// together on scroll, the REAL card is fine and what is seen is a system snapshot;
    /// if the closed card's frame stays put while its neighbour moves, the layout is
    /// pinning it. Those are the only two possibilities.
    private var diagnoseSubjects: Set<String> {
        #if DEBUG
        guard let diagnoseID,
              let index = model.knownLeagues.firstIndex(where: { $0.id == diagnoseID }) else { return [] }
        var ids: Set<String> = [diagnoseID]
        if index + 1 < model.knownLeagues.count { ids.insert(model.knownLeagues[index + 1].id) }
        return ids
        #else
        return []
        #endif
    }

    #if DEBUG
    /// Observed only so the weekly view redraws when the debug font browser picks a
    /// different display family. Read in `body`; carries no meaning in release.
    @AppStorage(SWType.debugFaceKey) private var debugFace: String = ""
    #endif

    var body: some View {
        #if DEBUG
        let _ = debugFace   // touches the key so a font change forces a redraw
        #endif
        NavigationStack {
            ZStack(alignment: .top) {
                // The navigation bar is hidden outright: its inset, not the safe area,
                // is what kept the sky off the top of the screen, and the single control
                // up here does not need a bar to live in.
                //
                // The safe area is NOT ignored on the ZStack itself: doing that strips
                // it from the environment, so the content and the top bar ride up under
                // the status bar. Each sky layer ignores it individually instead.
                (skyIsUp ? palette.sky : SWColor.launch)
                    .ignoresSafeArea()

                ParallaxSky(palette: palette, scroll: scroll)
                    .opacity(skyIsUp ? 1 : 0)

                ScrollView {
                    VStack(spacing: SWSpacing.xxl) {
                        WeeklyHero(model: model) {
                            WelcomeView(
                                model: model, showingESPNLogin: $showingESPNLogin,
                                showingMFLConnect: $showingMFLConnect, showingYahooLogin: $showingYahooLogin,
                                connect: connect
                            )
                        }
                        if model.hasAccount {
                            leagues
                            PortfolioSection(model: model)
                            OutlookSection(snapshots: model.snapshots)
                        }
                    }
                    .padding(.top, SWSize.topInset)
                    .padding(.bottom, SWSpacing.xxl)
                }
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
                // Without this the view can come up already scrolled, hiding the hero.
                .defaultScrollAnchor(.top)
                // `contentOffset.y` is NEGATIVE at rest — it sits at minus the top
                // inset — so reading it raw reported ~56pt of scroll before the user
                // touched anything, and the sky started life pushed 17pt down the
                // screen. Adding the inset back makes this a true distance from rest:
                // zero at rest, negative while rubber-banding past the top.
                //
                // Quantised to 8 points. Feeding the raw offset invalidated the sky —
                // a full-screen Metal view — on every scroll frame, which is most of
                // what made scrolling feel heavy. Eight points of parallax granularity
                // is imperceptible.
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    let fromRest = geometry.contentOffset.y + geometry.contentInsets.top
                    return (fromRest / 8).rounded() * 8
                } action: { _, fromRest in
                    scroll.fromRest = fromRest
                }

                topBar
            }
            .toolbar(.hidden, for: .navigationBar)
            // A tap on any player anywhere opens their season. On this screen there is
            // no single league in view, so the first one in the list sets the rules.
            // The sheet comes FIRST so the environment modifiers below enclose it. A
            // modifier wraps the ones before it, and a sheet attached outside an
            // `.environment(...)` presents content that never sees that value — which
            // is a player sheet with no model and a skeleton that never resolves.
            .playerSheetHost(inspector, model: model, leagueID: model.knownLeagues.first?.id)
            .navigationDestination(item: $selectedLeagueID) { id in
                if let snapshot = model.snapshot(for: id) {
                    LeagueDetailView(
                        snapshot: snapshot,
                        model: model,
                        selectedLeagueID: $selectedLeagueID,
                        onBack: { selectedLeagueID = nil },
                        onRefresh: { await model.refresh(leagueID: id) }
                    )
                    // The card's border grows to fill the screen. It only reads that way
                    // because the destination header is bare content, not another card.
                    .navigationTransition(.zoom(sourceID: id, in: cardTransition))
                } else {
                    // The league left the screen between the tap and the push (hidden, or
                    // gone from the platform). Sky, no bar, and straight back.
                    ZStack {
                        palette.sky.ignoresSafeArea()
                        StaticSky(palette: palette).ignoresSafeArea()
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .onAppear { selectedLeagueID = nil }
                }
            }
            .sheet(isPresented: $showingLeagueEditor) {
                // The platform's own reorderable list, over this screen. Medium by
                // default so the cards it is rearranging stay visible behind it.
                LeagueEditor(model: model)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingAccount) {
                AccountSheet(model: model)
            }
            .refreshable { await model.refreshAll() }
            .feedback(.signInSucceeded, trigger: connectSuccesses)
            .feedback(.signInFailed, trigger: connectFailures)
            .task {
                if model.snapshots.isEmpty { await model.load() }
                #if DEBUG
                openDebugDestination()
                #endif
            }
            .onAppear {
                // One beat after launch: the launch colour becomes the live sky and the
                // clouds arrive. Background only; nothing readable is gated on it.
                withAnimation(SWMotion.launch) { skyIsUp = true }
            }
            .modifier(SignInSheets(
                model: model, espn: $showingESPNLogin, mfl: $showingMFLConnect, yahoo: $showingYahooLogin
            ))
            .modifier(LivePoll(model: model))
            .onOpenURL { url in
                guard url.scheme == WidgetStore.urlScheme else { return }
                if url.host == "league", let id = url.pathComponents.last, id != "/" {
                    open(leagueID: id)
                }
            }
            .onChange(of: model.isLoading) { _, loading in
                // A link that arrived before the load landed opens now, or never: a
                // league the widget knew and the reader has since hidden stays closed.
                guard !loading, let pending = pendingLeagueID else { return }
                pendingLeagueID = nil
                open(leagueID: pending)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    // Keep the widgets moving while the app is closed.
                    BackgroundRefresh.schedule(liveSoon: model.hasLiveGame)
                }
                guard phase == .active else { return }
                if model.hasLiveGame {
                    // Mid-game: refresh now, not whatever was true when you left.
                    Task { await model.load(force: true) }
                } else if let last = model.lastLoaded, Date().timeIntervalSince(last) > 6 * 3_600 {
                    // Quiet day, but the screen is old — a Tuesday morning after the
                    // week has flipped. A normal load: the caches decide what is stale.
                    Task { await model.load() }
                }
            }
            .onChange(of: selectedLeagueID) { _, selected in
                guard selected == nil, let closing = transitionSourceID else { return }
                #if DEBUG
                diagnoseID = closing
                diagLog("weekly: selectedLeagueID -> nil (was \(closing)); the zoom source is held for 0.7s")
                #endif
                // Long enough for the pop animation to have finished, whatever its
                // curve; short enough that a tap on another card is not affected. A tap
                // on ANY card in the meantime issues a new retirement, so this one is
                // stale and does nothing.
                let retirement = UUID()
                sourceRetirement = retirement
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.7))
                    if sourceRetirement == retirement, transitionSourceID == closing { transitionSourceID = nil }
                }
            }
        }
        .tint(SWColor.accent)
    }

    /// Account, or Done while arranging. One control, one place — the way out of a mode
    /// belongs where the mode's other chrome is, not stacked above the content.
    private var topBar: some View {
        HStack {
            Spacer()
            AccountButton { showingAccount = true }
        }
        .padding(.horizontal, SWSpacing.lg)
        .padding(.top, SWSpacing.xs)
    }

    #if DEBUG
    /// Drives screenshots on a simulator, nothing else. Launch with
    /// `-sw.debugOpen league/<id>`, `player/<leagueID>/<canonicalID>`, `account` or
    /// `editor`; the argument lands in UserDefaults' argument domain.
    private func openDebugDestination() {
        // Once per launch: this runs from the root's `.task`, which fires again every
        // time a pushed screen pops back to it — and re-opening the league then would
        // put a fresh detail on screen the instant the closed one left.
        guard !debugDestinationOpened else { return }
        debugDestinationOpened = true
        guard let path = UserDefaults.standard.string(forKey: "sw.debugOpen") else { return }
        let parts = path.split(separator: "/").map(String.init)
        switch parts.first {
        case "league" where parts.count == 2: selectedLeagueID = parts[1]
        case "account": showingAccount = true
        case "editor": showingLeagueEditor = true
        case "player" where parts.count == 3:
            let player = model.snapshots.first { $0.id == parts[1] }?.rosters
                .flatMap(\.slots).first { $0.player.canonicalID == parts[2] }?.player
            if let player { inspector.open(player, in: parts[1]) }
        default: break
        }
    }
    #endif

    /// Opens a league, if there is a league to open. A skeleton card is a `Button` like
    /// any other, and tapping it used to push a destination with nothing in it.
    private func open(leagueID id: String) {
        guard model.snapshot(for: id) != nil else {
            // Not loaded yet: remember it, and let the load's end decide.
            if model.isLoading { pendingLeagueID = id }
            return
        }
        // The source must exist BEFORE the push begins, and a retirement still pending
        // from the last close must not fire on it.
        sourceRetirement = UUID()
        transitionSourceID = id
        selectedLeagueID = id
    }

    /// One load for a connect the reader just made, and one haptic for how it went.
    private func connect() async {
        await model.load()
        if model.loadProblem == nil { connectSuccesses += 1 } else { connectFailures += 1 }
    }

    // MARK: - Sections

    @ViewBuilder
    private var leagues: some View {
        if model.knownLeagues.isEmpty, model.isLoading {
            // Nothing is known yet, not even how many leagues there are.
            SWShimmer {
                VStack(spacing: SWSpacing.lg) {
                    ForEach(0..<2, id: \.self) { _ in
                        SkeletonBlock(height: 188, radius: SWRadius.lg)
                    }
                }
            }
            .padding(.horizontal, SWSpacing.lg)
        } else {
            VStack(spacing: SWSpacing.lg) {
                LeagueStack(
                    items: model.knownLeagues,
                    onSelect: { league in open(leagueID: league.id) }
                ) { league in
                    if let snapshot = model.snapshot(for: league.id) {
                        LeagueCard(snapshot: snapshot)
                            // Always the same modifier, so the card's identity never
                            // changes — only WHAT it matches. While this card is the
                            // live source it matches the destination; otherwise it
                            // points at an id nothing will ever look up.
                            .matchedTransitionSource(
                                id: transitionSourceID == snapshot.id ? snapshot.id : "idle-\(snapshot.id)",
                                in: cardTransition
                            )
                            .modifier(ZoomDiagnostics(
                                name: snapshot.league.name,
                                isSubject: diagnoseSubjects.contains(snapshot.id)
                            ))
                    } else {
                        // The transition lives on the SKELETON, which is the thing that
                        // leaves. The card that replaces it gets none: it is the zoom
                        // transition's source and must not be wrapped in anything.
                        SWShimmer { LeagueCardSkeleton(league: league) }
                            .transition(.opacity)
                    }
                }

                EditLeaguesRow(hiddenCount: model.hiddenLeagues.count, isShown: !model.allLeagues.isEmpty) {
                    showingLeagueEditor = true
                }
            }
            .padding(.horizontal, SWSpacing.lg)
        }
    }
}
