import SwiftUI
import FantasyCore
import FantasyProviders

/// A player's season: every week, what they did, what was expected, what it was worth.
///
/// Worth under WHICH rules is the one control on the screen. It opens on the league you
/// were looking at and can be switched to any other, because the same six catches are a
/// different number in a half-PPR league than a full one, and the whole point of one app
/// for several leagues is being able to see that.
///
/// A dimmed number is an estimate — computed from the raw stats under that league's rules
/// because the league itself never scored this player that week (nobody rostered him
/// there, or it is another platform's league). Everything else is the league's own
/// figure. One legend line says so, and only when it applies.
struct PlayerSheet: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    private var isAccessibilitySize: Bool { typeSize.isAccessibilitySize }
    let selection: PlayerInspector.Selection
    /// Passed in, never read from the environment. Sheet content is hosted in its own
    /// hierarchy and an environment value set on the presenting screen did not reach it
    /// — the sheet came up with no model and a skeleton that never resolved. A
    /// parameter cannot fail to arrive.
    let model: WeeklyModel
    /// Set only when the reader picks another league from the menu.
    @State private var chosenLeagueID: String?
    @State private var season: PlayerSeason?
    @State private var isLoading = true

    private var player: PlayerRef { selection.player }
    private var options: [WeeklyModel.ScoringOption] { model.visibleScoringOptions }
    /// Resolved on the first frame rather than in `onAppear`: the first `.task(id:)` used
    /// to fire with nil, return without loading, and leave the skeleton up until the
    /// second pass — and with no model at all, forever.
    private var leagueID: String? { chosenLeagueID ?? selection.leagueID ?? options.first?.leagueID }
    private var option: WeeklyModel.ScoringOption? { options.first { $0.leagueID == leagueID } ?? options.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SWSpacing.lg) {
                    header
                    scoringControl
                    if let season {
                        summary(season)
                        log(season)
                    } else if isLoading {
                        SWShimmer {
                            VStack(spacing: SWSpacing.sm) {
                                ForEach(0..<6, id: \.self) { _ in SkeletonBlock(height: 44, radius: SWRadius.sm) }
                            }
                        }
                    } else {
                        StateView(
                            kind: .empty, title: "No season to show yet.",
                            detail: Text("Stats come from a league's scoring, so a league has to be showing."),
                            retry: { Task { await reload() } }
                        )
                    }
                }
                .padding(SWSpacing.lg)
            }
            .background {
                SWColor.canvas
                    .overlay(SWColor.position(player.position).opacity(0.10))
                    .ignoresSafeArea()
            }
            // The header carries the name; a title above it read the name twice.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .tint(SWColor.accent)
        .task(id: leagueID) { await reload() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: SWSpacing.md) {
            Headshot(player: player, size: SWSize.facePortrait, strokeWidth: Headshot.ring)
            VStack(alignment: .leading, spacing: SWSpacing.xxs) {
                Text(player.name)
                    .font(SWType.title)
                    .foregroundStyle(SWColor.primary)
                    .accessibilityAddTraits(.isHeader)
                    .lineLimit(2)
                HStack(spacing: SWSpacing.xs) {
                    Text(player.position.rawValue).foregroundStyle(SWColor.position(player.position))
                    if let team = player.nflTeam { Text(team).foregroundStyle(SWColor.tertiary) }
                    if player.injuryStatus != .healthy {
                        Text(player.injuryStatus.rawValue.capitalized).foregroundStyle(SWColor.warning)
                    }
                }
                .font(SWType.caption)
            }
            Spacer(minLength: 0)
        }
    }

    /// The one control, labelled so it is obvious what it changes. A menu rather than a
    /// segmented picker because league names are long and there may be six of them.
    @ViewBuilder
    private var scoringControl: some View {
        if let option, options.count > 1 {
            HStack {
                Text("Scored under")
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.tertiary)
                Spacer()
                Menu {
                    Section("Score this season with the rules of") {
                        ForEach(options) { candidate in
                            Button {
                                chosenLeagueID = candidate.leagueID
                            } label: {
                                if candidate.leagueID == option.leagueID {
                                    Label(candidate.name, systemImage: "checkmark")
                                } else {
                                    Text(candidate.name)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: SWSpacing.xs) {
                        PlatformMark(platform: option.platform, size: SWSize.markSmall)
                        Text(option.name)
                            .font(SWType.bodyMedium)
                            .foregroundStyle(SWColor.primary)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(SWType.glyph)
                            .foregroundStyle(SWColor.secondary)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, SWSpacing.md)
                    .padding(.vertical, SWSpacing.sm)
                    .background(Capsule().fill(SWColor.surface))
                    .frame(minHeight: SWSize.hitTarget)
                    .contentShape(.rect)
                }
                .accessibilityLabel("Scoring rules: \(option.name)")
            }
        } else if let option {
            HStack {
                Text("Scored under")
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.tertiary)
                Spacer()
                Text(option.name)
                    .font(SWType.bodyMedium)
                    .foregroundStyle(SWColor.primary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: Summary

    private func summary(_ season: PlayerSeason) -> some View {
        let format = SWFormat.score
        let cells = isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SWSpacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: SWSpacing.xl))
        return VStack(alignment: .leading, spacing: SWSpacing.md) {
            cells {
                StatCell(value: season.totalPoints.formatted(format), caption: "Points")
                if let average = season.averagePoints {
                    StatCell(value: average.formatted(format), caption: "Per game")
                }
                if let rank = season.positionRank {
                    StatCell(value: rank.label, caption: "Rank", detail: "of \(rank.of)")
                }
                Spacer(minLength: 0)
            }
            if let projected = season.averageProjected, let delta = season.averageVersusProjection {
                cells {
                    StatCell(value: projected.formatted(format), caption: "Proj. per game")
                    StatCell(
                        value: delta.formatted(format.sign(strategy: .always())),
                        caption: "vs. projection",
                        tone: delta >= 0 ? SWColor.positive : SWColor.negative,
                        detail: "per game"
                    )
                    StatCell(value: "\(season.gamesPlayed)", caption: "Played")
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(SWSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: SWRadius.md, style: .continuous).fill(SWColor.surface))
    }

    // MARK: Game log

    private func log(_ season: PlayerSeason) -> some View {
        VStack(alignment: .leading, spacing: SWSpacing.sm) {
            HStack {
                Text("Season")
                    .font(SWType.headline)
                    .foregroundStyle(SWColor.primary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                // The whole rule for estimates, in one line, shown only when it applies.
                if season.hasApproximations {
                    Text("Dimmed points are estimates")
                        .font(SWType.micro)
                        .foregroundStyle(SWColor.tertiary)
                }
            }
            VStack(spacing: 0) {
                // In order. A schedule reads top to bottom; the current week is marked.
                ForEach(season.weeks) { week in
                    row(week, isCurrent: week.week == currentWeek)
                    if week.week != season.weeks.last?.week {
                        Rectangle().fill(SWColor.hairline).frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, SWSpacing.lg)
            .padding(.vertical, SWSpacing.sm)
            .background(RoundedRectangle(cornerRadius: SWRadius.md, style: .continuous).fill(SWColor.surface))
        }
    }

    private var currentWeek: Int? {
        model.allLeagues.first { $0.id == leagueID }?.currentWeek
    }

    @ViewBuilder
    private func row(_ week: PlayerWeek, isCurrent: Bool) -> some View {
        let line = StatLine.summary(week.stats, position: player.position)
        HStack(alignment: .firstTextBaseline, spacing: SWSpacing.md) {
            Text("\(week.week)")
                .font(SWType.scoreCaption)
                .foregroundStyle(isCurrent ? SWColor.accent : SWColor.tertiary)
                .frame(minWidth: SWSpacing.xl, alignment: .leading)

            VStack(alignment: .leading, spacing: SWSpacing.xxs) {
                Text(week.isBye ? "Bye" : (week.opponent ?? "—"))
                    .font(SWType.bodyMedium)
                    .foregroundStyle(week.isBye ? SWColor.tertiary : SWColor.primary)
                if !line.isEmpty {
                    Text(line)
                        .font(SWType.micro)
                        .foregroundStyle(SWColor.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }

            Spacer(minLength: SWSpacing.sm)

            VStack(alignment: .trailing, spacing: SWSpacing.xxs) {
                if let actual = week.actual {
                    // An estimate is the same number, quieter. Nothing else changes.
                    Text(actual.points, format: SWFormat.score)
                        .font(SWType.score)
                        .foregroundStyle(actual.isExact ? tone(week) : SWColor.tertiary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if let projected = week.projected {
                        Text("proj \(projected.points.formatted(SWFormat.score))")
                            .font(SWType.micro)
                            .foregroundStyle(SWColor.tertiary)
                    }
                } else if let projected = week.projected {
                    Text("proj \(projected.points.formatted(SWFormat.score))")
                        .font(SWType.scoreCaption)
                        .foregroundStyle(SWColor.secondary)
                }
            }
        }
        .padding(.vertical, SWSpacing.sm)
        .opacity(week.isBye ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }

    /// The colour says one thing only: did they beat their projection.
    private func tone(_ week: PlayerWeek) -> Color {
        guard let actual = week.actual, let projected = week.projected else { return SWColor.primary }
        return actual.points >= projected.points ? SWColor.positive : SWColor.negative
    }

    private func reload() async {
        // Whatever happens below, the skeleton must come down.
        defer { isLoading = false }
        guard let leagueID else {
            #if DEBUG
            print("[player-sheet] no league to score under (options: \(options.count))")
            #endif
            return
        }
        isLoading = true
        season = await model.playerSeason(for: player, under: leagueID)
        #if DEBUG
        print("[player-sheet] \(player.name) under \(leagueID): \(season?.weeks.count ?? 0) weeks, \(season?.gamesPlayed ?? 0) played")
        #endif
    }
}
