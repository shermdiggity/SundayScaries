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
                                    StaticSky(palette: Sky.palette(at: Self.date(hour: hour)))
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

                    section("Exposure, owned") {
                        HStack(alignment: .bottom, spacing: SWSpacing.xl) {
                            ForEach([5, 4, 3, 2, 1, 0], id: \.self) {
                                ExposureMeter(filled: $0, total: 5)
                            }
                        }
                    }

                    section("Exposure, faced") {
                        HStack(alignment: .bottom, spacing: SWSpacing.xl) {
                            ForEach([5, 3, 1], id: \.self) {
                                ExposureMeter(filled: $0, total: 5, kind: .faced)
                            }
                        }
                    }

                    section("Matchup") {
                        VStack(spacing: SWSpacing.xl) {
                            MatchupBar(myName: "You", myScore: 118.4, opponentName: "Mahomies", opponentScore: 102.1)
                            MatchupBar(myName: "You", myScore: 74.2, opponentName: "Arctic9", opponentScore: 131.8)
                            MatchupBar(myName: "You", myScore: 0, opponentName: "Not started", opponentScore: 0)
                        }
                    }

                    section("Player rows") {
                        VStack(spacing: 0) {
                            PlayerRow(slot: .init(slot: .wr, isStarter: true, player: Self.player("Justin Jefferson", .wr, "MIN"), points: 24.3))
                            PlayerRow(slot: .init(slot: .qb, isStarter: true, player: Self.player("Josh Allen", .qb, "BUF")))
                            PlayerRow(slot: .init(slot: .te, isStarter: true, player: Self.player("Travis Kelce", .te, "KC", .questionable), points: 8.1))
                            PlayerRow(slot: .init(slot: .rb, isStarter: true, player: Self.player("Christian McCaffrey", .rb, "SF", .out), points: 0))
                            PlayerRow(slot: .init(slot: .flex, isStarter: true, player: Self.player("Rome Odunze", .wr, "CHI"), isOnBye: true))
                            PlayerRow(slot: .init(slot: .def, isStarter: true, player: Self.player("Pittsburgh Steelers", .def, "PIT"), points: 11))
                            PlayerRow(slot: .init(slot: .wr, isStarter: true, player: .emptyLineupSlot(platform: .sleeper)))
                            PlayerRow(slot: .init(slot: .bench, isStarter: false, player: Self.player("Tank Dell", .wr, "HOU"), points: 3.2))
                        }
                    }

                    section("Lineup strip") {
                        VStack(alignment: .leading, spacing: SWSpacing.xl) {
                            LineupStrip(roster: Self.cleanRoster, league: Self.draftedLeague)
                            LineupStrip(roster: Self.brokenRoster, league: Self.draftedLeague)
                        }
                    }

                    section("Player cards") {
                        VStack(alignment: .leading, spacing: SWSpacing.xl) {
                            PositionCarousel(title: "Riding on", positions: Self.samplePositions,
                                             kind: .started, points: { _ in (17.4, true) })
                            PositionCarousel(title: "Up against", positions: Self.sampleFaced,
                                             kind: .faced, points: { _ in (14.1, false) })
                        }
                        .padding(.horizontal, -SWSpacing.xl)
                    }

                    section("Podium") {
                        Podium(entries: [
                            .init(rank: 1, teamName: "MyLeekNeighbor", powerPoints: "84.2", unit: "power pts", allPlay: "121-33 all-play",
                                  face: Self.faced("Josh Allen", .qb, "BUF", "4984"), isMine: false),
                            .init(rank: 2, teamName: "Globo Gym Purple Cobras", powerPoints: "71.6", unit: "power pts", allPlay: "97-57 all-play",
                                  face: Self.faced("Justin Jefferson", .wr, "MIN", "6794"), isMine: true),
                            .init(rank: 3, teamName: "dirtz", powerPoints: "66.9", unit: "power pts", allPlay: "92-62 all-play",
                                  face: Self.faced("Travis Kelce", .te, "KC", "1466"), isMine: false),
                        ])
                    }

                    section("Progress row") {
                        VStack(alignment: .leading, spacing: SWSpacing.md) {
                            ProgressRow(mine: Self.sampleProgress[1], theirs: Self.sampleProgress[2])
                            ProgressRow(mine: Self.sampleProgress[0], theirs: Self.sampleProgress[0],
                                        isCompact: true)
                            ProgressRow(mine: Self.sampleProgress[3], theirs: Self.sampleProgress[1])
                        }
                    }

                    // These two must read as the same colour, or the closing zoom shows
                    // a shade change as the screen shrinks into the card.
                    section("Card tint vs. closing backdrop") {
                        VStack(spacing: 0) {
                            ForEach(Platform.allCases, id: \.self) { platform in
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(SWColor.leagueFlat(platform, over: Sky.palette().sky))
                                        .frame(height: 44)
                                    ZStack {
                                        StaticSky(palette: Sky.palette())
                                        Rectangle().fill(.clear)
                                            .glassEffect(.regular.tint(SWColor.leagueTint(platform)),
                                                         in: .rect(cornerRadius: 0))
                                    }
                                    .frame(height: 44)
                                }
                                .overlay(alignment: .leading) {
                                    Text(platform.displayName)
                                        .font(SWType.micro)
                                        .foregroundStyle(SWColor.primary)
                                        .padding(.leading, SWSpacing.sm)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: SWRadius.sm))
                    }

                    section("Lineup check and platform") {
                        HStack(spacing: SWSpacing.xl) {
                            LineupCheck(isSet: true, issueCount: 0)
                            LineupCheck(isSet: false, issueCount: 1)
                            LineupCheck(isSet: false, issueCount: 3)
                            ForEach(Platform.allCases, id: \.self) { PlatformMark(platform: $0, size: 22) }
                        }
                    }

                    section("Win bar") {
                        VStack(alignment: .leading, spacing: SWSpacing.lg) {
                            ForEach([28.0, 7.0, 0.0, -7.0, -28.0], id: \.self) { margin in
                                WinBar(probability: WinProbability.value(margin: margin),
                                       isLive: margin == 7.0)
                            }
                        }
                    }

                    section("Headshots") {
                        HStack(spacing: SWSpacing.lg) {
                            Headshot(player: Self.faced("Justin Jefferson", .wr, "MIN", "6794"), size: 48)
                            Headshot(player: Self.player("Rookie Nobody", .rb, "BUF"), size: 48)
                            Headshot(player: Self.defense, size: 48)
                            Headshot(player: .emptyLineupSlot(platform: .sleeper), size: 48)
                        }
                    }

                    section("Skeletons") {
                        VStack(alignment: .leading, spacing: SWSpacing.lg) {
                            HeroSkeleton()
                            LeagueCardSkeleton(league: Self.draftedLeague)
                        }
                    }

                    section("Sync") {
                        VStack(alignment: .leading, spacing: SWSpacing.sm) {
                            Text("fresh renders nothing:").font(SWType.caption).foregroundStyle(SWColor.tertiary)
                            SyncBadge(state: .fresh(Date()))
                            SyncBadge(state: .stale(Date().addingTimeInterval(-3600 * 26)))
                            SyncBadge(state: .failed(ProviderError.transport(underlying: "offline")))
                        }
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
                            Text("Display 40").font(SWType.display).foregroundStyle(SWColor.primary)
                            Text("Title 26").font(SWType.title).foregroundStyle(SWColor.primary)
                            Text("Headline 17").font(SWType.headline).foregroundStyle(SWColor.primary)
                            Text("Body 15").font(SWType.body).foregroundStyle(SWColor.primary)
                            Text("Caption 13").font(SWType.caption).foregroundStyle(SWColor.secondary)
                            Text("MICRO 11").font(SWType.micro).foregroundStyle(SWColor.tertiary)
                            Text("118.4  ·  99.0  ·  102.1").font(SWType.score).foregroundStyle(SWColor.primary)
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

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: SWSpacing.md) {
            Text(title)
                .font(SWType.headline)
                .foregroundStyle(SWColor.primary)
            content()
        }
    }

    static var sampleProgress: [LineupProgress] {
        [
            LineupProgress(pointsScored: 0, finished: 0, inProgress: 0, yetToPlay: 9, total: 9),
            LineupProgress(pointsScored: 42.6, finished: 3, inProgress: 2, yetToPlay: 4, total: 9),
            LineupProgress(pointsScored: 128.4, finished: 9, inProgress: 0, yetToPlay: 0, total: 9),
            LineupProgress(pointsScored: 88.2, finished: 6, inProgress: 1, yetToPlay: 1, notPlaying: 1, total: 9),
        ]
    }

    static var draftedLeague: League {
        League(id: "L", platform: .sleeper, name: "L", size: 12, scoringKind: .ppr,
               currentWeek: 3, season: "2026", status: .inSeason)
    }

    static func date(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    static func player(_ name: String, _ position: Position, _ team: String,
                       _ injury: InjuryStatus = .healthy) -> PlayerRef {
        PlayerRef(identity: .canonical(id: name, source: .gsis), name: name,
                  nflTeam: team, position: position, injuryStatus: injury)
    }

    static func faced(_ name: String, _ position: Position, _ team: String, _ sleeperID: String) -> PlayerRef {
        PlayerRef(identity: .canonical(id: name, source: .gsis), name: name, nflTeam: team,
                  position: position,
                  headshotURL: URL(string: "https://sleepercdn.com/content/nfl/players/\(sleeperID).jpg"))
    }

    static var defense: PlayerRef {
        PlayerRef(identity: .canonical(id: "DEF-PIT", source: .teamDefense),
                  name: "Pittsburgh Steelers", nflTeam: "PIT", position: .def,
                  headshotURL: URL(string: "https://sleepercdn.com/images/team_logos/nfl/pit.png"))
    }

    static func involvements(_ names: [String], opponents: [String] = []) -> [LeagueInvolvement] {
        names.enumerated().map { index, name in
            LeagueInvolvement(leagueID: name, leagueName: name,
                              opponentName: index < opponents.count ? opponents[index] : nil)
        }
    }

    static var samplePositions: [PlayerPosition] {
        [
            PlayerPosition(player: player("Travis Kelce", .te, "KC"),
                           ownedIn: Self.involvements(["Alpha", "Beta", "Gamma"]),
                           startedIn: Self.involvements(["Alpha", "Beta", "Gamma"]),
                           facedIn: [], totalLeagues: 3),
            PlayerPosition(player: player("Ashton Jeanty", .rb, "LV"),
                           ownedIn: Self.involvements(["Alpha", "Gamma"]),
                           startedIn: Self.involvements(["Alpha", "Gamma"]),
                           facedIn: [], totalLeagues: 3),
        ]
    }

    static var sampleFaced: [PlayerPosition] {
        [
            PlayerPosition(player: player("Jahmyr Gibbs", .rb, "DET"),
                           ownedIn: [], facedIn: Self.involvements(["Alpha", "Beta", "Gamma"], opponents: ["Mahomies", "Arctic9", "Dirtz"]), totalLeagues: 3),
            PlayerPosition(player: player("Alec Pierce", .wr, "IND"),
                           ownedIn: Self.involvements(["Alpha"]), facedIn: Self.involvements(["Beta"], opponents: ["Arctic9"]), totalLeagues: 3),
        ]
    }

    static var cleanRoster: Roster {
        Roster(teamID: "1", leagueID: "L", week: 3, slots: [
            .init(slot: .qb, isStarter: true, player: player("A", .qb, "BUF")),
            .init(slot: .rb, isStarter: true, player: player("B", .rb, "SF")),
            .init(slot: .wr, isStarter: true, player: player("C", .wr, "MIN")),
            .init(slot: .te, isStarter: true, player: player("D", .te, "KC")),
            .init(slot: .def, isStarter: true, player: player("E", .def, "PIT")),
        ])
    }

    static var brokenRoster: Roster {
        Roster(teamID: "1", leagueID: "L", week: 3, slots: [
            .init(slot: .qb, isStarter: true, player: player("A", .qb, "BUF")),
            .init(slot: .rb, isStarter: true, player: player("Hurt Guy", .rb, "SF", .out)),
            .init(slot: .wr, isStarter: true, player: .emptyLineupSlot(platform: .sleeper)),
            .init(slot: .te, isStarter: true, player: player("Resting", .te, "KC"), isOnBye: true),
            .init(slot: .def, isStarter: true, player: player("E", .def, "PIT")),
        ])
    }
}

#Preview { ComponentGallery() }
