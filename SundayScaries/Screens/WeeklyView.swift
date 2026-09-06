import SwiftUI
import FantasyCore

/// The app's only screen, and its front door.
///
/// Ordered by what decays: the sky and the one fact that defines your Sunday, then the
/// leagues you can still do something about, then the portfolio, then the retrospective.
struct WeeklyView: View {
    @State private var model = WeeklyModel()
    @State private var inspector = PlayerInspector()
    /// False for the first frame only. The launch screen is the flat `SWColor.launch`;
    /// the sky fades in over it, so launch and first frame are one continuous motion.
    /// The TYPE is never part of this — it is on screen from frame one.
    @State private var skyIsUp = false
    @State private var sleeperDraft = ""
    @State private var isEnteringSleeper = false
    @State private var showingESPNLogin = false
    @State private var showingMFLConnect = false
    @State private var showingYahooLogin = false
    /// Outcomes of the welcome cards' connects, counted so a load the reader started can
    /// be felt and one the poll started cannot.
    @State private var connectSuccesses = 0
    @State private var connectFailures = 0
    @State private var isEnteringFleaflicker = false
    @State private var fleaflickerDraft = ""
    @FocusState private var fleaflickerFieldFocused: Bool
    @FocusState private var sleeperFieldFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    private var isAccessibilitySize: Bool { typeSize.isAccessibilitySize }
    @State private var showingAccount = false
    @State private var showingLeagueEditor = false
    @State private var selectedLeagueID: String?
    /// Which card is the zoom transition's source RIGHT NOW. Set on tap, kept through
    /// the push and the whole pop animation, then retired.
    ///
    /// A card's `matchedTransitionSource` id used to be its league id, permanently. The
    /// transition system keeps a snapshot bound to that id, and after a pop that snapshot
    /// sometimes outlived the animation — a card frozen at its screen position while the
    /// real list scrolled underneath, sliding behind the card below. Retiring the id
    /// once the pop has finished leaves nothing for a stale snapshot to be bound to.
    @State private var transitionSourceID: String?
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
                        hero
                        if model.hasAccount {
                            leagues
                            exposure
                            outlook
                        }
                    }
                    .padding(.top, 56)
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
                if let snapshot = model.snapshots.first(where: { $0.id == id }) {
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
            .task { if model.snapshots.isEmpty { await model.load() } }
            .onAppear {
                // One beat after launch: the launch colour becomes the live sky and the
                // clouds arrive. Background only; nothing readable is gated on it.
                withAnimation(.easeOut(duration: 0.9)) { skyIsUp = true }
            }
            .modifier(SignInSheets(
                model: model, espn: $showingESPNLogin, mfl: $showingMFLConnect, yahoo: $showingYahooLogin
            ))
            .modifier(LivePoll(model: model))
            .onOpenURL { url in
                guard url.scheme == WidgetStore.urlScheme else { return }
                if url.host == "league", let id = url.pathComponents.last, id != "/" {
                    selectedLeagueID = id
                }
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
                print("[zoom-diag] closed \(closing) — scroll now; watching it and the card below")
                #endif
                // Long enough for the pop animation to have finished, whatever its
                // curve; short enough that a tap on another card is not affected. If the
                // user has already tapped another card by then, leave that one alone.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.7))
                    if transitionSourceID == closing { transitionSourceID = nil }
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
            accountButton
        }
        .padding(.horizontal, SWSpacing.lg)
        .padding(.top, SWSpacing.xs)
    }

    private var accountButton: some View {
        Button { showingAccount = true } label: {
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

    // MARK: - Hero

    /// The sky owns the fold, carrying one fact. Not a headline stack — the whole point
    /// is that the atmosphere and a single sentence do the work.
    private var hero: some View {
        VStack(alignment: .leading, spacing: SWSpacing.lg) {
            if model.isLoading, model.snapshots.isEmpty {
                HeroSkeleton()
            }

            if let week = model.week {
                // One week for the whole screen, and the reader can move it. Back for
                // last week's finals; forward again to where the platforms are. When one
                // platform has flipped and another has not, this is what keeps every
                // card describing the same seven days.
                HStack(spacing: SWSpacing.sm) {
                    weekStep(systemImage: "chevron.left", label: "Previous week", enabled: model.canStepBack) {
                        Task { await model.show(week: week - 1) }
                    }
                    Text("Week \(week)")
                        .font(SWType.caption)
                        .foregroundStyle(SWColor.onSkySecondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    weekStep(systemImage: "chevron.right", label: "Next week", enabled: model.canStepForward) {
                        Task { await model.show(week: week + 1) }
                    }
                    if !model.isOnLiveWeek {
                        Button("Now") { Task { await model.show(week: nil) } }
                            .accessibilityLabel("Back to the current week")
                            .font(SWType.caption)
                            .foregroundStyle(SWColor.onSky)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                            .padding(.vertical, -11)
                            .buttonStyle(.plain)
                            .padding(.leading, SWSpacing.xs)
                    }
                }
            }

            if model.hasAccount {
                // One line, always. It shrinks rather than wrapping.
                Text(quietHeadline)
                    .swVoice(SWType.displayFace)
                    .foregroundStyle(SWColor.onSky)
                    .accessibilityAddTraits(.isHeader)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                    .lineLimit(isAccessibilitySize ? 3 : 1)
                    .minimumScaleFactor(0.5)
            } else {
                welcome
            }

            if let problem = model.loadProblem {
                StateView(
                    kind: .error, title: "Not everything loaded", detail: problem.message,
                    retry: { Task { await model.load() } }, onSky: true
                )
            }
            if let fallback = model.seasonFallback {
                fallback.note
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.onSkySecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SWSpacing.xl)
    }

    // MARK: - First run

    /// The weekly view with nothing in it yet. Not a separate flow: the same sky, the same
    /// voice, and two ways in. The moment either connects, this turns into the real
    /// screen in place — skeletons where the cards will be — and that is the onboarding.
    private var welcome: some View {
        VStack(alignment: .leading, spacing: SWSpacing.xl) {
            VStack(alignment: .leading, spacing: SWSpacing.sm) {
                Text("Your whole Sunday, one screen.")
                    .swVoice(SWType.displayFace)
                    .foregroundStyle(SWColor.onSky)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text("Every league you're in. Live scores, who you're relying on, who's coming for you.")
                    .font(SWType.body)
                    .foregroundStyle(SWColor.onSkySecondary)
                    // Same legibility shadow as the headline: midday white cloud is the
                    // case that breaks bare light type over the sky.
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: SWSpacing.md) {
                connectCard(.sleeper, detail: "Just your username. No password.") {
                    withAnimation(SWMotion.standard) { isEnteringSleeper.toggle() }
                    sleeperFieldFocused = isEnteringSleeper
                }
                if isEnteringSleeper {
                    HStack(spacing: SWSpacing.sm) {
                        TextField("Sleeper username", text: $sleeperDraft)
                            .font(SWType.body)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .focused($sleeperFieldFocused)
                            .onSubmit(connectSleeper)
                        Button("Connect", action: connectSleeper)
                            .font(SWType.bodyMedium)
                            .disabled(sleeperDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, SWSpacing.lg)
                    .padding(.vertical, SWSpacing.md)
                    .leagueSurface(.sleeper)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                connectCard(.espn, detail: "Sign in on ESPN's page. We keep nothing but your session.") {
                    showingESPNLogin = true
                }
                if FeatureFlags.yahooEnabled {
                    connectCard(.yahoo, detail: "Yahoo's official sign-in. Your password never comes here.") {
                        showingYahooLogin = true
                    }
                }
                connectCard(.myFantasyLeague, detail: "Sign in, or paste a public league's ID.") {
                    showingMFLConnect = true
                }
                connectCard(.fleaflicker, detail: "Just the email on your account. No password.") {
                    withAnimation(SWMotion.standard) { isEnteringFleaflicker.toggle() }
                    fleaflickerFieldFocused = isEnteringFleaflicker
                }
                if isEnteringFleaflicker {
                    HStack(spacing: SWSpacing.sm) {
                        TextField("Email on your Fleaflicker account", text: $fleaflickerDraft)
                            .font(SWType.body)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .submitLabel(.go)
                            .focused($fleaflickerFieldFocused)
                            .onSubmit(connectFleaflicker)
                        Button("Connect", action: connectFleaflicker)
                            .font(SWType.bodyMedium)
                            .disabled(fleaflickerDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, SWSpacing.lg)
                    .padding(.vertical, SWSpacing.md)
                    .leagueSurface(.fleaflicker)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private func connectFleaflicker() {
        let handle = fleaflickerDraft.trimmingCharacters(in: .whitespaces)
        guard !handle.isEmpty else { return }
        fleaflickerFieldFocused = false
        model.fleaflickerHandle = handle
        Task { await connect() }
    }

    /// One way in. The platform's own mark, its name, one honest line about what
    /// connecting involves, and a chevron. The same surface the league cards wear, so
    /// the moment it becomes one nothing about the screen's material changes.
    private func connectCard(_ platform: Platform, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SWSpacing.md) {
                PlatformMark(platform: platform, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(platform.displayName)
                        .font(SWType.cardTitle)
                        .foregroundStyle(SWColor.primary)
                    Text(detail)
                        .font(SWType.caption)
                        .foregroundStyle(SWColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: SWSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(SWType.glyph)
                    .foregroundStyle(SWColor.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(SWSpacing.lg)
            .leagueSurface(platform)
            .contentShape(.rect(cornerRadius: SWRadius.lg))
        }
        .buttonStyle(.plain)
    }

    /// One load for a connect the reader just made, and one haptic for how it went.
    private func connect() async {
        await model.load()
        if model.loadProblem == nil { connectSuccesses += 1 } else { connectFailures += 1 }
    }

    private func connectSleeper() {
        let handle = sleeperDraft.trimmingCharacters(in: .whitespaces)
        guard !handle.isEmpty else { return }
        sleeperFieldFocused = false
        model.handle = handle
        Task { await connect() }
    }

    private func weekStep(systemImage: String, label: LocalizedStringKey, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(SWType.glyph)
                .foregroundStyle(enabled ? SWColor.onSky : SWColor.onSkySecondary.opacity(0.35))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
                .padding(-11)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// The header answers one question and one only: are my lineups set?
    private var quietHeadline: LocalizedStringKey {
        if model.snapshots.isEmpty { return model.isLoading ? "" : "Nothing to show yet." }
        let leagues = model.leaguesNeedingAttention
        guard leagues > 0 else { return "Every lineup is set." }
        return "\(leagues) lineups need you."
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
                    onSelect: { league in
                        // The source must exist BEFORE the push begins.
                        transitionSourceID = league.id
                        selectedLeagueID = league.id
                    }
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

                editLeaguesRow
            }
            .padding(.horizontal, SWSpacing.lg)
        }
    }

    /// The way into reordering and hiding — visible, not a long press nobody finds.
    /// Doubles as the way back to anything hidden, because hiding something on this
    /// screen removes it from this screen, so the way back has to be here too.
    @ViewBuilder
    private var editLeaguesRow: some View {
        let hidden = model.hiddenLeagues.count
        if !model.allLeagues.isEmpty {
            Button {
                showingLeagueEditor = true
            } label: {
                HStack(spacing: SWSpacing.xs) {
                    Image(systemName: "slider.horizontal.3").font(SWType.micro).accessibilityHidden(true)
                    Text("Edit leagues")
                    if hidden > 0 {
                        Text("·").foregroundStyle(SWColor.onSkySecondary.opacity(0.6))
                        Text("\(hidden) hidden")
                    }
                }
                .font(SWType.caption)
                .foregroundStyle(SWColor.onSkySecondary)
                .padding(.vertical, SWSpacing.sm)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var exposure: some View {
        // Starters only. A bench player you own five times changes nothing about your
        // Sunday, and neither does one sitting on an opponent's bench.
        let mine = model.yourGuys()
        let faced = model.upAgainst()

        if !mine.isEmpty || !faced.isEmpty {
            VStack(alignment: .leading, spacing: SWSpacing.xl) {
                if !mine.isEmpty {
                    PositionCarousel(title: "Your Guys", positions: mine, kind: .started,
                                     points: model.points(for:), kickoff: model.kickoff(for:))
                }
                if !faced.isEmpty {
                    PositionCarousel(title: "Up against", positions: faced, kind: .faced,
                                     points: model.points(for:), kickoff: model.kickoff(for:))
                }
            }
        }
    }

    @ViewBuilder
    private var outlook: some View {
        let withOutlook = model.snapshots.filter { $0.outlook.mvp != nil }
        if !withOutlook.isEmpty {
            VStack(alignment: .leading, spacing: SWSpacing.lg) {
                Text("The season so far")
                    .swVoice(SWType.sectionHeaderFace)
                    // On the sky, like the hero — not the card text colour.
                    .foregroundStyle(SWColor.onSky)
                    .accessibilityAddTraits(.isHeader)

                ForEach(withOutlook) { snapshot in
                    SeasonOutlookRow(snapshot: snapshot)
                }
            }
            .padding(.horizontal, SWSpacing.xl)
        }
    }

    // MARK: - Copy

    /// The sentence that leads the app. Written, not templated from fragments.
    static func sentence(for position: PlayerPosition) -> LocalizedStringKey {
        let surname = position.player.name.split(separator: " ").last.map(String.init)
            ?? position.player.name
        if position.facedCount > position.ownedCount {
            return position.facedCount == position.totalLeagues
                ? "\(surname) starts against you everywhere."
                : "\(surname) starts against you in \(spelled(position.facedCount)) of \(spelled(position.totalLeagues)) leagues."
        }
        return position.ownedCount == position.totalLeagues
            ? "You're all-in on \(surname)."
            : "You're \(spelled(position.ownedCount))-for-\(spelled(position.totalLeagues)) on \(surname)."
    }

    static func spelled(_ value: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five",
                     "six", "seven", "eight", "nine", "ten"]
        return value >= 0 && value < words.count ? words[value] : String(value)
    }
}

/// The three platform sign-ins the welcome cards open. Each saves what it was handed
/// and reloads.
private struct SignInSheets: ViewModifier {
    let model: WeeklyModel
    @Binding var espn: Bool
    @Binding var mfl: Bool
    @Binding var yahoo: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $espn) {
                ESPNLoginView { credentials in
                    ESPNCredentialStore.save(credentials)
                    Task { await model.load() }
                }
            }
            .sheet(isPresented: $mfl) {
                MFLConnectView { credentials in
                    MFLCredentialStore.save(credentials)
                    Task { await model.load() }
                } onLeagueIDs: { ids in
                    model.mflLeagueIDs = ids
                    Task { await model.load() }
                }
            }
            .sheet(isPresented: $yahoo) {
                YahooSignInView { credentials in
                    YahooCredentialStore.save(credentials)
                    Task { await model.load() }
                }
            }
    }
}

/// The live poll. Once a minute it asks one cheap question — is any starter in a game
/// right now? — and only if so does it refresh. On a Tuesday this loop does nothing but
/// sleep. On a Sunday it keeps every number within a minute of true, quietly, without a
/// skeleton ever appearing.
private struct LivePoll: ViewModifier {
    let model: WeeklyModel

    func body(content: Content) -> some View {
        content.task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled, model.hasLiveGame else { continue }
                await model.load(force: true)
            }
        }
    }
}

/// The `[zoom-diag]` frame log CLAUDE.md points at if the stuck-card symptom ever returns:
/// a closed card moving with its neighbour on scroll is a system snapshot, one frozen in
/// place is our layout. Logs only the cards under suspicion, and only in DEBUG.
private struct ZoomDiagnostics: ViewModifier {
    let name: String
    let isSubject: Bool

    @State private var lastY: CGFloat = .nan

    func body(content: Content) -> some View {
        #if DEBUG
        content.onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { y in
            guard isSubject, lastY.isNaN || abs(y - lastY) > 4 else { return }
            lastY = y
            print("[zoom-diag] \(name) screenY=\(Int(y))")
        }
        #else
        content
        #endif
    }
}
