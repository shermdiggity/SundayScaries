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

    /// The header answers one question and one only: are my lineups set?
    private var quietHeadline: LocalizedStringKey {
        if model.snapshots.isEmpty { return model.isLoading ? "" : "Nothing to show yet." }
        let leagues = model.leaguesNeedingAttention
        guard leagues > 0 else { return "Every lineup is set." }
        return "\(leagues) lineups need you."
    }
}
