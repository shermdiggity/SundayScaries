import SwiftUI
import FantasyCore

/// Who is carrying your week and who is coming for it. Starters only: a bench player
/// you own five times changes nothing about your Sunday, and neither does one sitting
/// on an opponent's bench.
struct PortfolioSection: View {
    let model: WeeklyModel

    var body: some View {
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
}

/// One league's season, reduced to the two players who explain it, for every league
/// that has one to tell.
struct OutlookSection: View {
    let snapshots: [LeagueSnapshot]

    var body: some View {
        let withOutlook = snapshots.filter { $0.outlook.mvp != nil }
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
}
