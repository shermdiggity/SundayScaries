import SwiftUI
import FantasyCore
import FantasyProviders

/// The You sheet's second group: which leagues show, and which season this is.
struct AccountLeaguesSection: View {
    let model: WeeklyModel
    let onEdit: () -> Void

    private var leagueSummary: LocalizedStringKey {
        let total = model.allLeagues.count
        let hidden = model.allLeagues.count { model.isHidden($0) }
        if total == 0 { return "None yet" }
        return hidden == 0 ? "\(total)" : "\(total - hidden) of \(total)"
    }

    var body: some View {
        Section {
            Button {
                onEdit()
            } label: {
                HStack {
                    Text("Show and reorder")
                        .font(SWType.bodyMedium)
                        .foregroundStyle(SWColor.primary)
                    Spacer()
                    Text(leagueSummary)
                        .font(SWType.caption)
                        .foregroundStyle(SWColor.tertiary)
                    Image(systemName: "chevron.right")
                        .font(SWType.glyph)
                        .foregroundStyle(SWColor.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .disabled(model.allLeagues.isEmpty)

            HStack {
                Text("Season")
                    .font(SWType.bodyMedium)
                    .foregroundStyle(SWColor.primary)
                Spacer()
                Text(model.allLeagues.first?.season ?? WeeklyModel.currentSeason())
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.tertiary)
                    .monospacedDigit()
            }
            if let fallback = model.seasonFallback {
                fallback.note
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
            }
        } header: {
            Text("Leagues")
        }
    }
}

/// Where the data comes from, the policy, the source, the version. At the bottom of a
/// screen about the app — not under every week on the main screen.
struct AccountAboutSection: View {
    let model: WeeklyModel

    var body: some View {
        Section {
            // Where the data comes from belongs here, at the bottom of a screen
            // about the app — not under every week on the main screen.
            ForEach(model.attribution, id: \.self) { line in
                Text(line)
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
            }
            if let url = URL(string: "https://github.com/shermdiggity/SundayScaries/blob/main/PRIVACY.md") {
                Link(destination: url) {
                    Text("Privacy policy")
                        .font(SWType.caption)
                        .foregroundStyle(SWColor.accent)
                }
                .frame(minHeight: SWSize.hitTarget)
            }
            if let url = URL(string: "https://github.com/shermdiggity/SundayScaries") {
                Link(destination: url) {
                    Text("Source and support")
                        .font(SWType.caption)
                        .foregroundStyle(SWColor.accent)
                }
                .frame(minHeight: SWSize.hitTarget)
            }
            HStack {
                Text("Version")
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.secondary)
                Spacer()
                Text(Self.version)
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.tertiary)
                    .monospacedDigit()
            }
        } header: {
            Text("About")
        }
    }

    private static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }
}
