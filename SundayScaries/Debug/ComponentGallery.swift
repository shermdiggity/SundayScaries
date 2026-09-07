#if DEBUG
import SwiftUI
import FantasyCore
import FantasyProviders

/// Every component, in every state, on one screen. Debug-only.
///
/// This is the discipline: if a component is not in here, it does not exist. It is how
/// drift gets caught before it spreads across screens.
struct ComponentGallery: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SWSpacing.xxl) {
                    // The legibility check that matters: hero type and a glass card
                    // over EVERY sky state. Midday is the one that breaks naive white.
                    section("Sky and legibility, through the day") {
                        VStack(spacing: SWSpacing.md) {
                            ForEach([3, 7, 10, 13, 17, 20], id: \.self) { hour in
                                ZStack(alignment: .topLeading) {
                                    StaticSky(palette: Sky.palette(at: GallerySamples.date(hour: hour)))
                                    VStack(alignment: .leading, spacing: SWSpacing.sm) {
                                        Text("\(hour):00")
                                            .font(SWType.caption)
                                            .foregroundStyle(SWColor.onSkySecondary)
                                        Text("Gibbs starts against you.")
                                            .font(SWType.title)
                                            .foregroundStyle(SWColor.onSky)
                                        Text("SAE Keeper FFL")
                                            .font(SWType.headline)
                                            .foregroundStyle(SWColor.primary)
                                            .padding(SWSpacing.md)
                                            .glassEffect(
                                                .regular.tint(SWColor.surface.opacity(0.62)),
                                                in: .rect(cornerRadius: SWRadius.md)
                                            )
                                    }
                                    .padding(SWSpacing.md)
                                }
                                .frame(height: 168)
                                .clipShape(RoundedRectangle(cornerRadius: SWRadius.md))
                            }
                        }
                    }

                    // The card in every state the weekly view can put it in, over the
                    // sky it actually sits on. This is most of what a person sees.
                    section("League card, every state") {
                        ZStack {
                            StaticSky(palette: Sky.palette())
                            VStack(spacing: SWSpacing.lg) {
                                LeagueCard(snapshot: GallerySamples.snapshot(.live))
                                LeagueCard(snapshot: GallerySamples.snapshot(.upcoming))
                                LeagueCard(snapshot: GallerySamples.snapshot(.failed))
                                LeagueCard(snapshot: GallerySamples.snapshot(.undrafted))
                                LeagueCard(snapshot: GallerySamples.snapshot(.carryover))
                                LeagueCard(snapshot: GallerySamples.snapshot(.noTeam))
                                LeagueCard(snapshot: GallerySamples.snapshot(.noMatchup))
                                LeagueCard(snapshot: GallerySamples.snapshot(.complete))
                                LeagueCardSkeleton(league: GallerySamples.league)
                            }
                            .padding(SWSpacing.lg)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: SWRadius.md))
                    }

                    section("Matchup header: yours, expanded, someone else's") {
                        VStack(spacing: SWSpacing.xl) {
                            MatchupHeader(snapshot: GallerySamples.snapshot(.live))
                            MatchupHeader(snapshot: GallerySamples.snapshot(.upcoming), isExpanded: true)
                            if let pair = GallerySamples.snapshot(.live).otherMatchups.first {
                                MatchupHeader(snapshot: GallerySamples.snapshot(.live), pair: pair)
                            }
                        }
                        .padding(SWSpacing.lg)
                        .background(RoundedRectangle(cornerRadius: SWRadius.md).fill(SWColor.surface))
                    }

                    section("Progress row") {
                        let progress = GallerySamples.sampleProgress
                        VStack(alignment: .leading, spacing: SWSpacing.md) {
                            ProgressRow(mine: progress[1], theirs: progress[2])
                            ProgressRow(mine: progress[0], theirs: progress[0], isCompact: true)
                            ProgressRow(mine: progress[3], theirs: progress[1])
                        }
                    }

                    section("Win bar") {
                        VStack(alignment: .leading, spacing: SWSpacing.lg) {
                            ForEach([28.0, 7.0, 0.0, -7.0, -28.0], id: \.self) { margin in
                                WinBar(probability: WinProbability.value(margin: margin),
                                       isLive: margin == 7.0)
                            }
                            WinBar(probability: 0.62, subject: "Mahomies")
                        }
                    }

                    // Deliberately mismatched: an empty slot on one side, a flex the
                    // other side lacks, a player on a bye. Pairing is by slot, never
                    // by index, and this is where that shows.
                    section("Lineup faceoff") {
                        let live = GallerySamples.snapshot(.live)
                        if let mine = live.myRoster {
                            LineupFaceoff(snapshot: live, mine: mine, theirs: live.opponentRoster)
                                .padding(SWSpacing.lg)
                                .background(RoundedRectangle(cornerRadius: SWRadius.md).fill(SWColor.surface))
                        }
                    }

                    section("Player rows") {
                        VStack(spacing: 0) {
                            playerRow(.wr, GallerySamples.player("Justin Jefferson", .wr, "MIN"), points: 24.3)
                            playerRow(.qb, GallerySamples.player("Josh Allen", .qb, "BUF"))
                            playerRow(.te, GallerySamples.player("Travis Kelce", .te, "KC", .questionable), points: 8.1)
                            playerRow(.rb, GallerySamples.player("Christian McCaffrey", .rb, "SF", .out), points: 0)
                            playerRow(.flex, GallerySamples.player("Rome Odunze", .wr, "CHI"), bye: true)
                            playerRow(.def, GallerySamples.player("Pittsburgh Steelers", .def, "PIT"), points: 11)
                            playerRow(.wr, .emptyLineupSlot(platform: .sleeper))
                            playerRow(.bench, GallerySamples.player("Tank Dell", .wr, "HOU"), points: 3.2)
                            PlayerRow(
                                slot: .init(slot: .qb, isStarter: true,
                                            player: GallerySamples.player("Jordan Love", .qb, "GB")),
                                projection: 19.4, nflMatchup: "@ CHI", hasStarted: false, kickoff: "Sun 1:00 PM"
                            )
                        }
                    }

                    section("Player cards") {
                        VStack(alignment: .leading, spacing: SWSpacing.xl) {
                            PositionCarousel(title: "Your Guys", positions: GallerySamples.samplePositions,
                                             kind: .started, points: { _ in (17.4, true) },
                                             kickoff: { _ in "Sun 4:25 PM" })
                            PositionCarousel(title: "Up against", positions: GallerySamples.sampleFaced,
                                             kind: .faced, points: { _ in (14.1, false) })
                        }
                        .padding(.horizontal, -SWSpacing.xl)
                    }

                    section("Exposure, started and faced") {
                        HStack(alignment: .bottom, spacing: SWSpacing.xl) {
                            ForEach([5, 3, 1, 0], id: \.self) {
                                ExposureMeter(filled: $0, total: 5)
                            }
                            ForEach([5, 3, 1], id: \.self) {
                                ExposureMeter(filled: $0, total: 5, kind: .faced)
                            }
                        }
                    }

                    section("Season outlook") {
                        ZStack {
                            StaticSky(palette: Sky.palette())
                            SeasonOutlookRow(snapshot: GallerySamples.snapshot(.live))
                                .padding(SWSpacing.lg)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: SWRadius.md))
                    }

                    section("Podium") {
                        Podium(entries: [
                            .init(rank: 1, teamName: "MyLeekNeighbor", powerPoints: "84.2", unit: "power pts", allPlay: "121-33 all-play",
                                  face: GallerySamples.faced("Josh Allen", .qb, "BUF", "4984"), isMine: false),
                            .init(rank: 2, teamName: "Globo Gym Purple Cobras", powerPoints: "71.6", unit: "power pts", allPlay: "97-57 all-play",
                                  face: GallerySamples.faced("Justin Jefferson", .wr, "MIN", "6794"), isMine: true),
                            .init(rank: 3, teamName: "dirtz", powerPoints: "66.9", unit: "power pts", allPlay: "92-62 all-play",
                                  face: GallerySamples.faced("Travis Kelce", .te, "KC", "1466"), isMine: false),
                        ])
                    }

                    section("Stat cells") {
                        HStack(alignment: .top, spacing: SWSpacing.xl) {
                            StatCell(value: "118.4", caption: "Points")
                            StatCell(value: "WR12", caption: "Rank", detail: "of 84")
                            StatCell(value: "+2.1", caption: "vs. projection", tone: SWColor.positive, detail: "per game")
                            StatCell(value: "-4.0", caption: "vs. projection", tone: SWColor.negative, detail: "per game")
                        }
                    }

                    section("States") {
                        VStack(spacing: SWSpacing.md) {
                            StateView(kind: .empty, title: "No roster to show for this team.")
                            StateView(
                                kind: .error, title: "Couldn't refresh",
                                detail: Text("Showing the last numbers that loaded."), retry: {}
                            )
                            StateView(kind: .error, title: "Not everything loaded", detail: Text("Couldn't find leagues for \"you\" in 2026."), retry: {}, onSky: true)
                        }
                    }

                    section("Lineup check and platform marks") {
                        HStack(spacing: SWSpacing.xl) {
                            LineupCheck(isSet: true, issueCount: 0)
                            LineupCheck(isSet: false, issueCount: 1)
                            LineupCheck(isSet: false, issueCount: 3)
                            ForEach(Platform.allCases, id: \.self) { PlatformMark(platform: $0, size: 22) }
                        }
                    }

                    section("Headshots") {
                        HStack(spacing: SWSpacing.lg) {
                            Headshot(player: GallerySamples.faced("Justin Jefferson", .wr, "MIN", "6794"), size: 48)
                            Headshot(player: GallerySamples.player("Rookie Nobody", .rb, "BUF"), size: 48)
                            Headshot(player: GallerySamples.defense, size: 48)
                            Headshot(player: .emptyLineupSlot(platform: .sleeper), size: 48)
                        }
                    }

                    section("Skeletons") {
                        VStack(alignment: .leading, spacing: SWSpacing.lg) {
                            HeroSkeleton()
                            LeagueCardSkeleton(league: GallerySamples.league)
                        }
                    }

                    section("Feedback") {
                        FeedbackDemo()
                    }

                    section("Positions") {
                        HStack(spacing: SWSpacing.lg) {
                            ForEach(Position.allCases, id: \.self) { position in
                                Text(position.rawValue)
                                    .font(SWType.micro)
                                    .foregroundStyle(SWColor.position(position))
                            }
                        }
                    }

                    section("Type") {
                        VStack(alignment: .leading, spacing: SWSpacing.sm) {
                            Text("Display 46").swVoice(SWType.displayFace).foregroundStyle(SWColor.primary)
                            Text("Section header 30").swVoice(SWType.sectionHeaderFace).foregroundStyle(SWColor.primary)
                            Text("Title 26").font(SWType.title).foregroundStyle(SWColor.primary)
                            Text("Headline 19").font(SWType.headline).foregroundStyle(SWColor.primary)
                            Text("Card title 19").font(SWType.cardTitle).foregroundStyle(SWColor.primary)
                            Text("Body 15").font(SWType.body).foregroundStyle(SWColor.primary)
                            Text("Body medium 15").font(SWType.bodyMedium).foregroundStyle(SWColor.primary)
                            Text("Caption 13").font(SWType.caption).foregroundStyle(SWColor.secondary)
                            Text("MICRO 11").font(SWType.micro).foregroundStyle(SWColor.tertiary)
                            Text("118.4").font(SWType.scoreLarge).foregroundStyle(SWColor.primary)
                            Text("118.4  ·  99.0  ·  102.1").font(SWType.score).foregroundStyle(SWColor.primary)
                            Text("118.4  ·  99.0").font(SWType.scoreCaption).foregroundStyle(SWColor.secondary)
                        }
                    }
                }
                .padding(SWSpacing.xl)
            }
            .background(SWColor.canvas)
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func playerRow(
        _ slot: SlotKind, _ player: PlayerRef, points: Double? = nil, bye: Bool = false
    ) -> some View {
        PlayerRow(slot: .init(slot: slot, isStarter: slot != .bench, player: player, points: points, isOnBye: bye))
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: SWSpacing.md) {
            Text(title)
                .font(SWType.headline)
                .foregroundStyle(SWColor.primary)
            content()
        }
    }
}

#Preview { ComponentGallery() }

/// Every haptic the app plays, on a button each, so a moment can be felt on a device
/// without finding the screen that fires it.
private struct FeedbackDemo: View {
    @State private var refreshes = 0
    @State private var failures = 0
    @State private var successes = 0
    @State private var toggles = 0

    var body: some View {
        HStack(spacing: SWSpacing.md) {
            Button("Refreshed") { refreshes += 1 }
                .feedback(.refreshCompleted, trigger: refreshes)
            Button("Failed") { failures += 1 }
                .feedback(.signInFailed, trigger: failures)
            Button("Signed in") { successes += 1 }
                .feedback(.signInSucceeded, trigger: successes)
            Button("Toggled") { toggles += 1 }
                .feedback(.leagueVisibilityChanged, trigger: toggles)
        }
        .font(SWType.caption)
        .buttonStyle(.bordered)
    }
}
#endif
