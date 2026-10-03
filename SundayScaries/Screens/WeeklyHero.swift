import SwiftUI
import FantasyCore

/// The sky owns the fold, carrying one fact. Not a headline stack — the whole point is
/// that the atmosphere and a single sentence do the work. The week control sits above
/// the sentence; the welcome takes the sentence's place until there is an account.
struct WeeklyHero<Welcome: View>: View {
    let model: WeeklyModel
    @ViewBuilder let welcome: () -> Welcome
    @Environment(\.dynamicTypeSize) private var typeSize
    private var isAccessibilitySize: Bool { typeSize.isAccessibilitySize }

    /// The sky owns the fold, carrying one fact. Not a headline stack — the whole point
    /// is that the atmosphere and a single sentence do the work.
    var body: some View {
        VStack(alignment: .leading, spacing: SWSpacing.lg) {
            if model.isLoading, model.snapshots.isEmpty {
                HeroSkeleton()
            }

            if let week = model.week {
                WeekControl(
                    week: week, canStepBack: model.canStepBack, canStepForward: model.canStepForward,
                    isOnLiveWeek: model.isOnLiveWeek
                ) { target in
                    Task { await model.show(week: target) }
                }
            }

            if !showsWelcome {
                // One line, always. It shrinks rather than wrapping.
                Text(quietHeadline)
                    .swVoice(SWType.displayFace)
                    .foregroundStyle(SWColor.onSky)
                    .accessibilityAddTraits(.isHeader)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                    .lineLimit(isAccessibilitySize ? 3 : 1)
                    .minimumScaleFactor(0.5)
            } else {
                welcome()
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

    /// The connect cards are the way in, and they stay the way in when a connect FAILED.
    /// A mistyped handle used to be kept, which threw the cards away and left the reader
    /// with "Nothing to show yet.", an error, and no field to fix it in.
    private var showsWelcome: Bool {
        !model.hasAccount || (model.knownLeagues.isEmpty && !model.isLoading && model.loadProblem != nil)
    }

    /// The header answers one question, and which question depends on the day. Before
    /// kickoff: are my lineups set? While games are on: am I winning? Once the week is
    /// over, or when you step back to a played week: how did it go?
    private var quietHeadline: LocalizedStringKey {
        if model.snapshots.isEmpty { return model.isLoading ? "" : "Nothing to show yet." }
        let leagues = model.leaguesNeedingAttention
        if leagues > 0 { return "\(leagues) lineups need you." }
        guard let tally = model.weekTally else { return "Every lineup is set." }
        return tally.isOver ? Self.result(tally) : Self.standing(tally)
    }

    /// The week, done. One league gets its margin; several get the record.
    static func result(_ tally: WeeklyModel.WeekTally) -> LocalizedStringKey {
        if tally.games == 1 {
            if tally.margin > 0 { return "You won by \(tally.margin, specifier: "%.1f")." }
            if tally.margin < 0 { return "You lost by \(-tally.margin, specifier: "%.1f")." }
            return "You tied."
        }
        if tally.ties > 0 { return "You went \(tally.wins)-\(tally.losses)-\(tally.ties)." }
        if tally.losses == 0 { return "A clean sweep, \(tally.wins)-0." }
        if tally.wins == 0 { return "Winless, 0-\(tally.losses)." }
        return "You went \(tally.wins)-\(tally.losses)."
    }

    /// Games on. The same shape as the result, in the present tense, and every league
    /// you have a game in is in it: the ones not yet kicked off are counted as still to
    /// start rather than left out.
    static func standing(_ tally: WeeklyModel.WeekTally) -> LocalizedStringKey {
        if tally.total == 1 {
            if tally.margin > 0 { return "Up by \(tally.margin, specifier: "%.1f")." }
            if tally.margin < 0 { return "Down by \(-tally.margin, specifier: "%.1f")." }
            return "All square."
        }
        if tally.toStart == 0, tally.ties == 0 {
            if tally.losses == 0 { return "Up in all \(tally.wins)." }
            if tally.wins == 0 { return "Down in all \(tally.losses)." }
        }
        return "\(Self.counts(tally))"
    }

    /// "Up in 2, down in 1, 3 yet to start." Only the counts that are not zero.
    private static func counts(_ tally: WeeklyModel.WeekTally) -> String {
        var parts: [String] = []
        if tally.wins > 0 { parts.append("up in \(tally.wins)") }
        if tally.losses > 0 { parts.append("down in \(tally.losses)") }
        if tally.ties > 0 { parts.append("tied in \(tally.ties)") }
        if tally.toStart > 0 { parts.append("\(tally.toStart) yet to start") }
        let line = parts.joined(separator: ", ")
        return line.prefix(1).uppercased() + line.dropFirst() + "."
    }
}
