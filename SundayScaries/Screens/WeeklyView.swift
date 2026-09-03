import SwiftUI
import FantasyCore

/// The app's only screen, and its front door.
///
/// Ordered by what decays: the sky and the one fact that defines your Sunday, then the
/// leagues you can still do something about, then the portfolio, then the retrospective.
struct WeeklyView: View {
    @State private var model = WeeklyModel()
    @State private var showingAccount = false
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedLeagueID: String?
    @Namespace private var cardTransition

    private var palette: SkyPalette { Sky.palette() }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // The navigation bar is hidden outright: its inset, not the safe area,
                // is what kept the sky off the top of the screen, and the single control
                // up here does not need a bar to live in.
                // A plain colour reliably reaches the very top edge where the shader
                // view stops a few points short. Painting the sky's own colour under it
                // means the last sliver reads as open sky at every hour, rather than as
                // a black band at midday.
                palette.sky
                    .ignoresSafeArea()

                SkyView(palette: palette, parallax: max(0, scrollOffset) * 0.30)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: SWSpacing.xxl) {
                        hero
                        if model.hasAccount {
                            leagues
                            exposure
                            outlook
                            colophon
                        }
                    }
                    .padding(.top, 56)
                    .padding(.bottom, SWSpacing.xxl)
                }
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
                // Without this the view can come up already scrolled, hiding the hero.
                .defaultScrollAnchor(.top)
                // Quantised to 8 points. Feeding the raw offset invalidated the sky —
                // a full-screen Metal view — on every scroll frame, which is most of
                // what made scrolling feel heavy. Eight points of parallax granularity
                // is imperceptible.
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    (geometry.contentOffset.y / 8).rounded() * 8
                } action: { _, offset in
                    scrollOffset = -offset
                }

                accountButton
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedLeagueID) { id in
                if let snapshot = model.snapshots.first(where: { $0.id == id }) {
                    LeagueDetailView(
                        snapshot: snapshot,
                        onBack: { selectedLeagueID = nil },
                        onRefresh: { await model.load() }
                    )
                    // The card's border grows to fill the screen. It only reads that way
                    // because the destination header is bare content, not another card.
                    .navigationTransition(.zoom(sourceID: id, in: cardTransition))
                }
            }
            .sheet(isPresented: $showingAccount) {
                AccountSheet(model: model)
            }
            .refreshable { await model.load() }
            .task { if model.snapshots.isEmpty { await model.load() } }
        }
        .tint(SWColor.accent)
    }

    private var accountButton: some View {
        HStack {
            Spacer()
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
        .padding(.horizontal, SWSpacing.lg)
        .padding(.top, SWSpacing.xs)
    }

    // MARK: - Hero

    /// The sky owns the fold, carrying one fact. Not a headline stack — the whole point
    /// is that the atmosphere and a single sentence do the work.
    private var hero: some View {
        VStack(alignment: .leading, spacing: SWSpacing.lg) {
            if model.isLoading && model.snapshots.isEmpty {
                HeroSkeleton()
            }

            if let week = model.week {
                Text("Week \(week)")
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.onSkySecondary)
            }

            if model.hasAccount {
                // One line, always. It shrinks rather than wrapping.
                Text(quietHeadline)
                    .font(SWType.display)
                    .foregroundStyle(SWColor.onSky)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                VStack(alignment: .leading, spacing: SWSpacing.md) {
                    Text("Every league, one screen.")
                        .font(SWType.display)
                        .foregroundStyle(SWColor.onSky)
                    Button("Add your Sleeper account") { showingAccount = true }
                        .buttonStyle(.glassProminent)
                        .tint(SWColor.accent)
                }
            }

            if let error = model.loadError {
                Text(error)
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.onSky.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SWSpacing.xl)
    }

    /// The header answers one question and one only: are my lineups set?
    private var quietHeadline: String {
        if model.snapshots.isEmpty { return model.isLoading ? "" : "Nothing to show yet." }
        let leagues = model.leaguesNeedingAttention
        guard leagues > 0 else { return "Every lineup is set." }
        return leagues == 1
            ? "One lineup needs you."
            : "\(Self.spelled(leagues).capitalized) lineups need you."
    }

    // MARK: - Sections

    @ViewBuilder
    private var leagues: some View {
        if model.knownLeagues.isEmpty && model.isLoading {
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
                ForEach(model.knownLeagues) { league in
                    if let snapshot = model.snapshot(for: league.id) {
                        Button {
                            selectedLeagueID = snapshot.id
                        } label: {
                            LeagueCard(snapshot: snapshot)
                                .matchedTransitionSource(id: snapshot.id, in: cardTransition)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    } else {
                        SWShimmer { LeagueCardSkeleton(league: league) }
                            .transition(.opacity)
                    }
                }
            }
            .padding(.horizontal, SWSpacing.lg)
        }
    }

    @ViewBuilder
    private var exposure: some View {
        // Starters only. A bench player you own five times changes nothing about your
        // Sunday, and neither does one sitting on an opponent's bench.
        let relied = model.reliedUpon
        let faced = model.upAgainst()

        if !relied.isEmpty || !faced.isEmpty {
            VStack(alignment: .leading, spacing: SWSpacing.xl) {
                if !relied.isEmpty {
                    PositionCarousel(title: "Riding on", positions: relied, kind: .started,
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
                    .font(SWType.headline)
                    .foregroundStyle(SWColor.primary)

                ForEach(withOutlook) { snapshot in
                    SeasonOutlookRow(snapshot: snapshot)
                }
            }
            .padding(.horizontal, SWSpacing.xl)
        }
    }

    @ViewBuilder
    private var colophon: some View {
        if !model.attribution.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(model.attribution, id: \.self) { line in
                    Text(line)
                }
            }
            .font(SWType.micro)
            .foregroundStyle(SWColor.tertiary)
            .padding(.horizontal, SWSpacing.xl)
            .padding(.top, SWSpacing.lg)
        }
    }

    // MARK: - Copy

    /// The sentence that leads the app. Written, not templated from fragments.
    static func sentence(for position: PlayerPosition) -> String {
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
