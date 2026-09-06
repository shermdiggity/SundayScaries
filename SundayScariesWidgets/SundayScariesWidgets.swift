import WidgetKit
import SwiftUI

@main
struct SundayScariesWidgetBundle: WidgetBundle {
    var body: some Widget {
        LineupStatusWidget()
        ScoreboardWidget()
        StatusScoreboardWidget()
        PlayersWidget()
        StatusPlayersWidget()
        PlayersScoreboardWidget()
    }
}

/// The dark, warm surface the league cards wear, and the app's home as the tap target.
private struct WidgetFrame<Content: View>: View {
    let entry: SnapshotEntry
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if entry.isEmpty { EmptyBlock() } else { content() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(SWColor.surface, for: .widget)
        .widgetURL(WidgetStore.homeURL)
    }
}

/// Two blocks, one above the other, sharing the height evenly. Spacing, not a rule.
private struct HalfAndHalf<Top: View, Bottom: View>: View {
    @ViewBuilder var top: () -> Top
    @ViewBuilder var bottom: () -> Bottom

    var body: some View {
        VStack(alignment: .leading, spacing: SWSpacing.lg) {
            top().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            bottom().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: 1. Lineup status

struct LineupStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LineupStatus", provider: SnapshotProvider()) { entry in
            LineupStatusView(entry: entry)
        }
        .configurationDisplayName("Lineups")
        .description("Whether every lineup is set, across all your leagues.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct LineupStatusView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var pending: Int { entry.snapshot.leaguesNeedingAttention.count }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                if entry.isEmpty {
                    Image(systemName: "football")
                } else if pending == 0 {
                    Image(systemName: "checkmark").font(SWType.icon)
                } else {
                    Text("\(pending)").font(SWType.scoreLarge)
                }
            }
            .widgetURL(WidgetStore.homeURL)
        case .accessoryInline:
            Text(entry.isEmpty ? "Sunday Scaries" : StatusBlock(snapshot: entry.snapshot).headline)
                .widgetURL(WidgetStore.homeURL)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isEmpty ? "Sunday Scaries" : StatusBlock(snapshot: entry.snapshot).headline)
                    .font(SWType.bodyMedium)
                if !entry.isEmpty {
                    Text(entry.snapshot.leaguesNeedingAttention.map(\.name).joined(separator: ", "))
                        .font(SWType.micro)
                        .lineLimit(2)
                }
            }
            .widgetURL(WidgetStore.homeURL)
        default:
            WidgetFrame(entry: entry) { StatusBlock(snapshot: entry.snapshot, compact: true) }
        }
    }
}

// MARK: 2. Scoreboard

struct ScoreboardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Scoreboard", provider: SnapshotProvider()) { entry in
            ScoreboardView(entry: entry)
        }
        .configurationDisplayName("Scoreboard")
        .description("Your matchup in every league.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct ScoreboardView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetFrame(entry: entry) {
            ScoreboardBlock(snapshot: entry.snapshot, rows: family == .systemLarge ? 6 : 2)
        }
    }
}

// MARK: 3. Status + scoreboard

struct StatusScoreboardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StatusScoreboard", provider: SnapshotProvider()) { entry in
            WidgetFrame(entry: entry) {
                HalfAndHalf {
                    StatusBlock(snapshot: entry.snapshot, compact: true)
                } bottom: {
                    ScoreboardBlock(snapshot: entry.snapshot, rows: 3)
                }
            }
        }
        .configurationDisplayName("Lineups and scores")
        .description("Are your lineups set, and how every matchup stands.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: 4. Your Guys and Up against

struct PlayersWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Players", provider: SnapshotProvider()) { entry in
            PlayersView(entry: entry)
        }
        .configurationDisplayName("Your Guys")
        .description("Who you're relying on, and who's coming for you.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct PlayersView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetFrame(entry: entry) {
            PlayersBlock(snapshot: entry.snapshot, rows: family == .systemLarge ? 6 : 2)
        }
    }
}

// MARK: 5. Status + players

struct StatusPlayersWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StatusPlayers", provider: SnapshotProvider()) { entry in
            WidgetFrame(entry: entry) {
                HalfAndHalf {
                    StatusBlock(snapshot: entry.snapshot, compact: true)
                } bottom: {
                    PlayersBlock(snapshot: entry.snapshot, rows: 3)
                }
            }
        }
        .configurationDisplayName("Lineups and your guys")
        .description("Are your lineups set, and who your Sunday rides on.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: 6. Players + scoreboard

struct PlayersScoreboardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PlayersScoreboard", provider: SnapshotProvider()) { entry in
            WidgetFrame(entry: entry) {
                HalfAndHalf {
                    PlayersBlock(snapshot: entry.snapshot, rows: 3)
                } bottom: {
                    ScoreboardBlock(snapshot: entry.snapshot, rows: 3)
                }
            }
        }
        .configurationDisplayName("Your guys and scores")
        .description("Who you're relying on, and how every matchup stands.")
        .supportedFamilies([.systemLarge])
    }
}
