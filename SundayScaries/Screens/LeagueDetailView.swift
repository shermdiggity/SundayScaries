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
    var onRefresh: () async -> Void = {}

    @State private var inspectedTeamID: String?
    @State private var inspectedMatchup: LeagueSnapshot.MatchupPair?
    @State private var isRefreshing = false
    @State private var inspector = PlayerInspector()
    /// Only the decision is stored, not the offset. Keeping the raw scroll position in
    /// state re-rendered the whole screen on every frame of every scroll.
    @State private var isCollapsed = false

    private var palette: SkyPalette { Sky.palette() }
    private var week: Int { snapshot.week }
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
                    scoreboard
                    lineups
                    aroundTheLeague
                    standings
                    mySchedule
                }
                .padding(.horizontal, SWSpacing.lg)
                .padding(.top, 56)
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
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $inspectedTeamID) { id in
            TeamSheet(snapshot: snapshot, teamID: id, model: model)
        }
        .sheet(item: $inspectedMatchup) { pair in
            MatchupSheet(snapshot: snapshot, pair: pair, model: model)
        }
        .playerSheetHost(inspector, model: model, leagueID: snapshot.league.id)
        .onChange(of: isActive, initial: true) { _, active in
            inspector.isEnabled = active
            guard !active else { return }
            // Nothing presents from a screen that has been closed.
            inspectedTeamID = nil
            inspectedMatchup = nil
            inspector.selection = nil
            #if DEBUG
            print("[detail] \(snapshot.league.name) closed: touches off, sheets cleared")
            #endif
        }
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
                collapsedSummary
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
                    await onRefresh()
                    isRefreshing = false
                }
            } label: {
                Group {
                    if isRefreshing {
                        // A real spinner while it works. The pulsing arrow was too quiet
                        // to tell that anything had happened.
                        ProgressView()
                            .tint(SWColor.onSky)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(SWType.icon)
                            .foregroundStyle(SWColor.onSky)
                            .frame(width: 20, height: 20)
                    }
                }
                .padding(SWSpacing.md)
                .glassEffect(.regular, in: .circle)
                .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .disabled(isRefreshing)
            .accessibilityLabel(isRefreshing ? "Refreshing" : "Refresh")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SWSpacing.lg)
        .padding(.top, SWSpacing.xs)
    }

    /// A full-width bar, not a floating pill: once the scoreboard is gone this is the
    /// scoreboard, so it carries both live totals and both projections.
    /// The pop is scheduled on its own, not sequenced off an animation completion —
    /// that coupling is what left the navigation stack drawing nothing.
    private var collapsedSummary: some View {
        VStack(spacing: 2) {
            HStack(spacing: SWSpacing.sm) {
                Text(snapshot.league.name)
                    .font(SWType.bodyMedium)
                    .foregroundStyle(SWColor.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            HStack(spacing: SWSpacing.sm) {
                collapsedSide(
                    name: snapshot.myTeam?.displayName ?? "You",
                    scored: snapshot.progress.pointsScored,
                    projected: snapshot.projectedTotal(for: snapshot.myRoster),
                    alignment: .leading
                )
                Text("vs.").font(SWType.micro).foregroundStyle(SWColor.tertiary)
                collapsedSide(
                    name: snapshot.opponent?.displayName ?? "—",
                    scored: snapshot.opponentProgress.pointsScored,
                    projected: snapshot.projectedTotal(for: snapshot.opponentRoster),
                    alignment: .trailing
                )
            }

            if let probability = snapshot.winProbability {
                WinBar(probability: probability, height: 6, showsLabel: true, isLive: snapshot.hasKickedOff)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, SWSpacing.md)
        .padding(.vertical, SWSpacing.sm)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.tint(SWColor.leagueTint(snapshot.league.platform)), in: .rect(cornerRadius: SWRadius.md))
        .accessibilityElement(children: .combine)
    }

    private func collapsedSide(name: String, scored: Double, projected: Double?, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(name)
                .font(SWType.micro)
                .foregroundStyle(SWColor.tertiary)
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(scored, format: SWFormat.score)
                    .contentTransition(.numericText())
                    .font(SWType.scoreCaption)
                    .foregroundStyle(SWColor.primary)
                if let projected {
                    Text("proj " + projected.formatted(SWFormat.score))
                        .font(SWType.micro)
                        .foregroundStyle(SWColor.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    // MARK: - Scoreboard

    private var scoreboard: some View {
        VStack(alignment: .leading, spacing: SWSpacing.lg) {
            HStack(spacing: SWSpacing.sm) {
                PlatformMark(platform: snapshot.league.platform)
                Text(snapshot.league.name)
                    .font(SWType.title)
                    .foregroundStyle(SWColor.primary)
                    .lineLimit(2)
                Spacer(minLength: SWSpacing.sm)
                if snapshot.league.status.hasDrafted, snapshot.myTeam != nil {
                    LineupCheck(isSet: snapshot.isLineupSet, issueCount: snapshot.issues.count)
                }
            }

            if snapshot.opponent != nil {
                if snapshot.progress.total > 0 {
                    ProgressRow(mine: snapshot.progress, theirs: snapshot.opponentProgress)
                }
                MatchupHeader(snapshot: snapshot, isExpanded: true)
            }

            HStack(spacing: SWSpacing.xl) {
                if let team = snapshot.myTeam {
                    StatCell(value: team.record.summary, caption: "Record")
                    StatCell(value: team.pointsFor.formatted(.number.precision(.fractionLength(0))), caption: "Points for")
                }
                if let standing = snapshot.standing {
                    StatCell(value: LeagueCard.ordinal(standing), caption: "Place")
                }
                if let luck = luckIndex {
                    StatCell(value: luck.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always())), caption: "Luck")
                }
            }

            // Straight to the league on its own platform — the app if it is installed,
            // the site if not — for the things this app deliberately does not do, like
            // setting a lineup. One quiet row, the platform's own mark, an outward arrow.
            if let destination = PlatformLinks.league(snapshot.league, teamID: snapshot.myTeam?.id) {
                Link(destination: destination) {
                    HStack(spacing: SWSpacing.sm) {
                        PlatformMark(platform: snapshot.league.platform, size: 18)
                        Text("Open in \(snapshot.league.platform.displayName)")
                            .font(SWType.bodyMedium)
                            .foregroundStyle(SWColor.primary)
                        Spacer(minLength: SWSpacing.sm)
                        Image(systemName: "arrow.up.right")
                            .font(SWType.glyph)
                            .foregroundStyle(SWColor.secondary)
                    }
                    .padding(.horizontal, SWSpacing.md)
                    .padding(.vertical, SWSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: SWRadius.sm, style: .continuous)
                            .fill(SWColor.primary.opacity(0.07))
                    )
                    .contentShape(.rect(cornerRadius: SWRadius.sm))
                }
                .accessibilityLabel("Open this league in \(snapshot.league.platform.displayName)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var luckIndex: Double? {
        guard let team = snapshot.myTeam else { return nil }
        return snapshot.analytics?.team(team.id)?.luckIndex
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
                        .frame(width: 46)
                    Text(snapshot.opponent?.displayName ?? "—")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(SWType.micro)
                .foregroundStyle(SWColor.tertiary)
                .lineLimit(1)

                LineupFaceoff(snapshot: snapshot, mine: mine, theirs: snapshot.opponentRoster)

                if !mine.bench.isEmpty {
                    Text("Your bench")
                        .font(SWType.section)
                        .foregroundStyle(SWColor.secondary)
                        .padding(.top, SWSpacing.md)
                    ForEach(Array(mine.bench.enumerated()), id: \.offset) { _, slot in
                        PlayerRow(slot: slot, in: snapshot, week: mine.week)
                            .opacity(0.72)
                    }
                }
            }
            .padding(SWSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(SWColor.leagueTint(snapshot.league.platform)), in: .rect(cornerRadius: SWRadius.lg))
        }
    }

    // MARK: - Your season

    /// Every week of your schedule: the result where it has been played, the opponent
    /// where it has not. Tap a week to open that matchup — past weeks with the lineups
    /// that actually played, future ones with the two teams.
    @ViewBuilder
    private var mySchedule: some View {
        let schedule = snapshot.mySchedule
        if !schedule.isEmpty {
            VStack(alignment: .leading, spacing: SWSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Your season")
                        .font(SWType.headline)
                        .foregroundStyle(SWColor.primary)
                    Spacer()
                    if let team = snapshot.myTeam {
                        Text(team.record.summary)
                            .font(SWType.scoreCaption)
                            .foregroundStyle(SWColor.secondary)
                    }
                }

                VStack(spacing: 0) {
                    ForEach(schedule) { entry in
                        Button {
                            inspectedMatchup = entry.pair
                        } label: {
                            scheduleRow(entry)
                        }
                        .buttonStyle(.plain)
                        if entry.id != schedule.last?.id {
                            Rectangle().fill(SWColor.hairline).frame(height: 1)
                        }
                    }
                }
            }
            .padding(SWSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(SWColor.leagueTint(snapshot.league.platform)), in: .rect(cornerRadius: SWRadius.lg))
        }
    }

    private func scheduleRow(_ entry: LeagueSnapshot.ScheduleEntry) -> some View {
        let format = SWFormat.score
        return HStack(alignment: .firstTextBaseline, spacing: SWSpacing.md) {
            Text("Week \(entry.week)")
                .font(SWType.scoreCaption)
                .foregroundStyle(entry.isCurrent ? SWColor.accent : SWColor.tertiary)
                .monospacedDigit()
                .frame(width: 60, alignment: .leading)

            Text(entry.opponent?.displayName ?? "—")
                .font(SWType.bodyMedium)
                .foregroundStyle(SWColor.primary)
                .lineLimit(1)

            Spacer(minLength: SWSpacing.sm)

            if let won = entry.won {
                // Result first, because that is what a schedule is for.
                Text(won ? "W" : "L")
                    .font(SWType.scoreCaption)
                    .foregroundStyle(won ? SWColor.positive : SWColor.negative)
                    .frame(width: 16)
                Text("\(entry.myScore.formatted(format)) – \(entry.theirScore.formatted(format))")
                    .font(SWType.scoreCaption)
                    .foregroundStyle(SWColor.secondary)
                    .monospacedDigit()
            } else if entry.isCurrent {
                Text(entry.pair.hasKickedOff
                    ? "\(entry.myScore.formatted(format)) – \(entry.theirScore.formatted(format))"
                    : "This week")
                    .font(SWType.scoreCaption)
                    .foregroundStyle(SWColor.accent)
                    .monospacedDigit()
            } else {
                Image(systemName: "chevron.right")
                    .font(SWType.glyph)
                    .foregroundStyle(SWColor.tertiary)
            }
        }
        .padding(.vertical, SWSpacing.sm)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Around the league

    /// Every other game this week, each in the same block your own scoreboard uses, so
    /// the whole league reads in one visual language. Tapping one opens both lineups.
    @ViewBuilder
    private var aroundTheLeague: some View {
        let others = snapshot.otherMatchups
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: SWSpacing.md) {
                Text("Around the league")
                    .font(SWType.headline)
                    .foregroundStyle(SWColor.primary)

                ForEach(others) { pair in
                    Button {
                        inspectedMatchup = pair
                    } label: {
                        // Same two blocks as your own scoreboard, in the same order:
                        // the banked points and how much is left come FIRST, because
                        // they change what the projection underneath means.
                        VStack(spacing: SWSpacing.sm) {
                            let left = snapshot.progress(for: pair.leftRoster)
                            let right = snapshot.progress(for: pair.rightRoster)
                            if left.total > 0 || right.total > 0 {
                                ProgressRow(mine: left, theirs: right, isCompact: true)
                            }
                            MatchupHeader(snapshot: snapshot, pair: pair)
                        }
                        .padding(SWSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: SWRadius.md, style: .continuous)
                                .fill(SWColor.primary.opacity(0.07))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: SWRadius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Shows both starting lineups")
                }
            }
            .padding(SWSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(SWColor.leagueTint(snapshot.league.platform)), in: .rect(cornerRadius: SWRadius.lg))
        }
    }

    // MARK: - Power ranking

    /// One row of the ranking, from whichever source currently has something to say.
    private struct RankRow: Identifiable {
        let teamID: String
        let rank: Int
        /// The headline number.
        let value: String
        /// What that number is called.
        let unit: String
        /// The quieter line under the team name.
        let detail: String
        let isMine: Bool
        var id: String { teamID }
    }

    /// True before any game has been scored, when an all-play blend is all zeroes and
    /// the only real signal is what the week projects.
    private var isProjectedOnly: Bool {
        snapshot.analytics?.weeksAnalyzed.isEmpty ?? true
    }

    private var rankRows: [RankRow] {
        guard let analytics = snapshot.analytics, !analytics.teams.isEmpty else { return [] }

        guard isProjectedOnly else {
            return analytics.teams.map { entry in
                RankRow(
                    teamID: entry.teamID,
                    rank: entry.powerRank,
                    value: Self.powerPoints(entry.powerScore),
                    unit: "power pts",
                    detail: "\(entry.allPlay.summary) all-play",
                    isMine: entry.teamID == snapshot.myTeam?.id
                )
            }
        }

        // Nothing has been played. Rank by what the week projects instead of showing
        // twelve identical zeroes — and say plainly that is what this is.
        return snapshot.rosters
            .map { ($0.teamID, snapshot.projectedTotal(for: $0) ?? 0) }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
            .enumerated()
            .map { index, pair in
                RankRow(
                    teamID: pair.0,
                    rank: index + 1,
                    value: pair.1.formatted(SWFormat.score),
                    unit: "projected",
                    detail: "Week \(week) projection",
                    isMine: pair.0 == snapshot.myTeam?.id
                )
            }
    }

    @ViewBuilder
    private var standings: some View {
        let rows = rankRows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: SWSpacing.sm) {
                Text(isProjectedOnly ? "Projected ranking" : "Power ranking")
                    .font(SWType.headline)
                    .foregroundStyle(SWColor.primary)
                Text(isProjectedOnly
                    ? "Nobody has scored yet, so this is week \(week) projections. Power points take over once games are played."
                    : "Power points blend all-play win rate, points for and recent form.")
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, SWSpacing.sm)

                Podium(
                    entries: rows.prefix(3).map { row in
                        Podium.Entry(
                            rank: row.rank,
                            teamName: teamName(row.teamID),
                            powerPoints: row.value,
                            unit: row.unit,
                            allPlay: row.detail,
                            face: bestPlayer(forTeam: row.teamID),
                            isMine: row.isMine
                        )
                    },
                    onSelect: { inspectedTeamID = $0 },
                    idForRank: { rank in rows.first { $0.rank == rank }?.teamID }
                )
                .padding(.bottom, SWSpacing.md)

                ForEach(rows.dropFirst(3)) { row in
                    Button { inspectedTeamID = row.teamID } label: {
                        rankRow(row)
                    }
                    .buttonStyle(.plain)
                }

                if !isProjectedOnly, let analytics = snapshot.analytics {
                    Text(analytics.weights.disclosure
                        .map { "\($0.label) \(Int($0.weight * 100))%" }
                        .joined(separator: " · "))
                        .font(SWType.micro)
                        .foregroundStyle(SWColor.tertiary)
                        .padding(.top, SWSpacing.sm)
                }
            }
            .padding(SWSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(SWColor.leagueTint(snapshot.league.platform)), in: .rect(cornerRadius: SWRadius.lg))
        }
    }

    private func rankRow(_ row: RankRow) -> some View {
        HStack(spacing: SWSpacing.md) {
            Text("\(row.rank)")
                .font(SWType.scoreCaption)
                .foregroundStyle(row.isMine ? SWColor.accent : SWColor.tertiary)
                .frame(width: 22, alignment: .trailing)

            if let face = bestPlayer(forTeam: row.teamID) {
                Headshot(player: face, size: 26)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(teamName(row.teamID))
                    .font(row.isMine ? SWType.bodyMedium : SWType.body)
                    .foregroundStyle(row.isMine ? SWColor.accent : SWColor.primary)
                    .lineLimit(1)
                Text(row.detail)
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
            }

            Spacer(minLength: SWSpacing.sm)

            VStack(alignment: .trailing, spacing: 0) {
                Text(row.value)
                    .font(SWType.scoreCaption)
                    .foregroundStyle(SWColor.secondary)
                Text(row.unit)
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
            }

            Image(systemName: "chevron.right")
                .font(SWType.glyph)
                .foregroundStyle(SWColor.tertiary)
        }
        .padding(.vertical, SWSpacing.sm)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    /// The blend is 0...1; showing it out of 100 makes it a score people can argue about.
    static func powerPoints(_ score: Double) -> String {
        (score * 100).formatted(SWFormat.score)
    }

    private func teamName(_ id: String) -> String {
        snapshot.teams.first { $0.id == id }?.displayName ?? id
    }

    /// A face per team: the highest-scoring or highest-projected starter.
    private func bestPlayer(forTeam id: String) -> PlayerRef? {
        guard let roster = snapshot.rosters.first(where: { $0.teamID == id }) else { return nil }
        return roster.starters
            .filter { !$0.player.isEmptyLineupSlot }
            .max { lhs, rhs in
                let l = lhs.points ?? snapshot.projections.projection(for: lhs.player) ?? 0
                let r = rhs.points ?? snapshot.projections.projection(for: rhs.player) ?? 0
                return l < r
            }?.player
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
