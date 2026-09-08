import SwiftUI
import FantasyCore
import FantasyProviders

/// One league: a matchup preview, then the power ranking.
///
/// It opens on the same `MatchupHeader` the card showed, so the zoom lands on what it
/// left. Below that, both lineups side by side — a preview is only useful if you can
/// see what you are up against — and then the ranking.
struct LeagueDetailView: View {
    let snapshot: LeagueSnapshot
    /// For the player sheet. Explicit, because the environment did not carry it here.
    let model: WeeklyModel
    /// The weekly view's selection, so this screen knows the moment it stops being the
    /// league on show. After the zoom transition's swipe-to-close, the popped screen
    /// keeps receiving touches for a beat after it has visibly gone — a quick tap on
    /// the weekly view landed on this screen's lineup and opened a player sheet from a
    /// league that was already closed. Once the selection is no longer this league,
    /// nothing here is hit-testable and nothing here may present.
    @Binding var selectedLeagueID: String?
    var onBack: () -> Void = {}
    var onRefresh: () async -> Bool = { true }
    @State private var refreshFailed = false

    @State private var inspectedTeam: TeamSelection?
    @State private var inspectedMatchup: LeagueSnapshot.MatchupPair?
    @State private var isRefreshing = false
    @State private var inspector = PlayerInspector(owner: "detail")
    /// UIKit's answer to "is this screen still pushed", read at tap time. See
    /// `NavigationStackProbe`.
    @State private var stack = StackProbe()
    /// Only the decision is stored, not the offset. Keeping the raw scroll position in
    /// state re-rendered the whole screen on every frame of every scroll.
    @State private var isCollapsed = false
    /// This week's box-score lines for everyone in the two lineups. Loaded after the
    /// screen is up and again whenever the scores move.
    @State private var statLines: [String: [String: Double]] = [:]

    private var palette: SkyPalette { Sky.palette() }
    private var week: Int { snapshot.week }

    /// The top bar's glyph box.
    private static let iconBox: CGFloat = 20
    /// True only while this league is the one the weekly view has open.
    private var isActive: Bool { selectedLeagueID == snapshot.id }

    var body: some View {
        ZStack(alignment: .top) {
            // Same two layers as the weekly view, for the same reason.
            palette.sky
                .ignoresSafeArea()

            StaticSky(palette: palette)
                .ignoresSafeArea()

            // The card that opened this screen is a pane of glass tinted to its
            // platform. Washing the screen in the same colour means the card expands
            // into the same material rather than cutting to a different one.
            LinearGradient(
                colors: [
                    SWColor.platform(snapshot.league.platform).opacity(0.34),
                    SWColor.platform(snapshot.league.platform).opacity(0.10),
                    .clear,
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: SWSpacing.xl) {
                    LeagueScoreboard(snapshot: snapshot)
                    if refreshFailed {
                        StateView(
                            kind: .error, title: "Couldn't refresh",
                            detail: Text("Showing the last numbers that loaded. Check the connection and try again.")
                        )
                    }
                    lineups
                    AroundTheLeagueSection(snapshot: snapshot) { pair in
                        present { inspectedMatchup = pair }
                    }
                    PowerRankingSection(snapshot: snapshot) { teamID in
                        present { inspectedTeam = TeamSelection(teamID: teamID) }
                    }
                    LeagueScheduleSection(snapshot: snapshot) { pair in
                        present { inspectedMatchup = pair }
                    }
                }
                .padding(.horizontal, SWSpacing.lg)
                .padding(.top, SWSize.topInset)
                .padding(.bottom, SWSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            // Hysteresis: collapse at 160, expand again at 120, so a scroll that
            // hovers near the threshold cannot flicker the bar in and out.
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y > (isCollapsed ? 120 : 160)
            } action: { _, collapsed in
                guard collapsed != isCollapsed else { return }
                withAnimation(SWMotion.quick) { isCollapsed = collapsed }
            }

            topBar
        }
        // A closed league takes no touches. The pop does not reliably remove this
        // screen from hit-testing in the same frame it disappears; the selection does.
        .allowsHitTesting(isActive)
        // …and it SWALLOWS them rather than passing them through. With hit-testing off
        // alone, a tap during the pop animation fell straight through the shrinking
        // screen onto the league card underneath, whose button re-opened the league
        // six milliseconds after it had closed.
        .overlay {
            if !isActive {
                Color.clear.contentShape(.rect)
            }
        }
        .background {
            NavigationStackProbe { canPresent, describe in
                stack.canPresent = canPresent
                stack.describe = describe
                inspector.canPresent = canPresent
                inspector.describe = describe
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $inspectedTeam) { team in
            TeamSheet(snapshot: snapshot, teamID: team.teamID, model: model)
        }
        .sheet(item: $inspectedMatchup) { pair in
            MatchupSheet(snapshot: snapshot, pair: pair, model: model)
        }
        .playerSheetHost(inspector, model: model, leagueID: snapshot.league.id)
        .onChange(of: isActive, initial: true) { _, active in
            diagLog("detail \(snapshot.league.name) isActive -> \(active) (selected=\(selectedLeagueID ?? "nil"))")
            inspector.isEnabled = active
            guard !active else { return }
            // Nothing presents from a screen that has been closed.
            inspectedTeam = nil
            inspectedMatchup = nil
            inspector.selection = nil
            diagLog("detail \(snapshot.league.name) closed: touches off, sheets cleared")
        }
        .onAppear { diagLog("detail \(snapshot.league.name) onAppear") }
        .onDisappear { diagLog("detail \(snapshot.league.name) onDisappear") }
    }

    /// Presents only while this screen is on the stack and no transition is in flight:
    /// a tap during the swipe that closes it, or a swipe too short to close it that is
    /// handed back as a tap, must not open a sheet from a screen on its way out.
    private func present(_ action: () -> Void) {
        let allowed = stack.canPresent()
        diagLog(
            "detail \(snapshot.league.name) tap (team/matchup) selected=\(selectedLeagueID ?? "nil") "
                + "isActive=\(isActive) decision=\(allowed ? "PRESENT" : "REFUSE")\n   \(stack.describe())"
        )
        guard allowed else { return }
        action()
    }

    private var topBar: some View {
        // Leading-aligned always: with only the button in it, an HStack centres itself
        // and the back arrow drifted into the middle of the screen.
        HStack(alignment: .top, spacing: SWSpacing.md) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(SWType.icon)
                    .foregroundStyle(SWColor.onSky)
                    .padding(SWSpacing.md)
                    .glassEffect(.regular, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            if isCollapsed {
                CollapsedScoreboard(snapshot: snapshot)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Spacer(minLength: 0)
            }

            // A button, because pull-to-refresh cannot live here. This screen is a zoom
            // destination, and the zoom's interactive dismissal is ALSO a downward drag
            // from the top — so pulling to refresh kept closing the league instead. One
            // gesture, one meaning: dragging down dismisses; this refreshes.
            Button {
                guard !isRefreshing else { return }
                isRefreshing = true
                Task {
                    refreshFailed = await !onRefresh()
                    isRefreshing = false
                }
            } label: {
                Group {
                    if isRefreshing {
                        // A real spinner while it works. The pulsing arrow was too quiet
                        // to tell that anything had happened.
                        ProgressView()
                            .tint(SWColor.onSky)
                            .frame(width: Self.iconBox, height: Self.iconBox)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(SWType.icon)
                            .foregroundStyle(SWColor.onSky)
                            .frame(width: Self.iconBox, height: Self.iconBox)
                    }
                }
                .padding(SWSpacing.md)
                .glassEffect(.regular, in: .circle)
                .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
            .accessibilityLabel(isRefreshing ? "Refreshing" : "Refresh")
            .feedback(.refreshCompleted, trigger: isRefreshing) { old, new in old && !new }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SWSpacing.lg)
        .padding(.top, SWSpacing.xs)
    }

    // MARK: - Lineups

    @ViewBuilder
    private var lineups: some View {
        if let mine = snapshot.myRoster, !mine.starters.isEmpty {
            VStack(alignment: .leading, spacing: SWSpacing.md) {
                HStack {
                    Text(snapshot.myTeam?.displayName ?? "You")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Starters")
                        .frame(minWidth: SWSize.slotColumn)
                    Text(snapshot.opponent?.displayName ?? "—")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(SWType.micro)
                .foregroundStyle(SWColor.tertiary)
                .lineLimit(1)
                .accessibilityElement(children: .combine)

                LineupFaceoff(snapshot: snapshot, mine: mine, theirs: snapshot.opponentRoster, statLines: statLines)

                if !mine.bench.isEmpty {
                    Text("Your bench")
                        .font(SWType.section)
                        .foregroundStyle(SWColor.secondary)
                        .padding(.top, SWSpacing.md)
                    ForEach(Array(mine.bench.enumerated()), id: \.offset) { _, slot in
                        PlayerRow(slot: slot, in: snapshot, week: mine.week, statLines: statLines)
                            .opacity(0.72)
                    }
                }
            }
            .padding(SWSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(SWColor.leagueTint(snapshot.league.platform)), in: .rect(cornerRadius: SWRadius.lg))
            // Keyed on the scores, so a poll that moves a number refetches the lines
            // behind it; a poll that moves nothing costs nothing.
            .task(id: "\(snapshot.myScore)|\(snapshot.opponentScore)") {
                let players = (mine.slots + (snapshot.opponentRoster?.starters ?? [])).map(\.player)
                statLines = await model.statLines(for: players, in: snapshot)
            }
        }
    }
}

/// The team whose sheet is up. A wrapper rather than a retroactive `Identifiable` on
/// `String`, which would have made every string in the module a sheet item.
private struct TeamSelection: Identifiable {
    let teamID: String
    var id: String { teamID }
}

/// Holds the probe's answer without observation: it is written during a view update
/// and read only inside a tap.
private final class StackProbe {
    var canPresent: @MainActor () -> Bool = { true }
    var describe: @MainActor () -> String = { "no probe" }
}
