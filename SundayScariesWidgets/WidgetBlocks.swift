import SwiftUI
import WidgetKit
import FantasyCore

// The three blocks every widget is composed from. They wear the app's tokens and the
// league card's dark surface, so a widget reads as a piece of the app lifted onto the
// home screen. Nothing here fetches: images come from the container, text from the
// snapshot.

// MARK: - Shared pieces

/// The platform's mark as the app draws its fallback: a letter on the platform colour.
/// Widgets cannot fetch the logo images, so every platform gets the monogram.
struct WidgetPlatformMark: View {
    let platform: String
    var size: CGFloat = 16

    private var resolved: Platform? { Platform(rawValue: platform) }

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(resolved.map(SWColor.platform) ?? SWColor.tertiary)
            .frame(width: size, height: size)
            .overlay {
                Text(resolved?.displayName.prefix(1) ?? "?")
                    .font(SWType.mark(size * 0.6))
                    .foregroundStyle(SWColor.canvas)
            }
    }
}

/// A headshot from the container, or initials on the position colour.
struct WidgetHeadshot: View {
    let player: WidgetPlayer
    var size: CGFloat = 34

    private var image: UIImage? {
        guard let file = player.headshotFile, let url = WidgetStore.headshotURL(file: file) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private var initials: String {
        let parts = player.name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined()
    }

    var body: some View {
        ZStack {
            Circle().fill(SWColor.surfaceRaised)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Text(initials)
                    .font(SWType.initials(size * 0.38))
                    .foregroundStyle(SWColor.position(Position(rawValue: player.position) ?? .other))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

extension Double {
    var widgetScore: String { formatted(.number.precision(.fractionLength(1))) }
}

// MARK: - Status

/// The one question: are all your lineups set. Big glyph, one line, then which leagues.
struct StatusBlock: View {
    let snapshot: WidgetSnapshot
    var compact = false

    private var pending: [WidgetLeague] { snapshot.leaguesNeedingAttention }
    private var isSet: Bool { pending.isEmpty }
    private var tint: Color { isSet ? SWColor.positive : SWColor.accent }

    var headline: String {
        if snapshot.leagues.isEmpty { return "Open the app" }
        if isSet { return "Every lineup is set" }
        return pending.count == 1 ? "1 lineup needs you" : "\(pending.count) lineups need you"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? SWSpacing.xs : SWSpacing.sm) {
            HStack(spacing: SWSpacing.sm) {
                Image(systemName: isSet ? "checkmark" : "exclamationmark")
                    .font(SWType.icon)
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                Text("Week \(snapshot.week)")
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.secondary)
                Spacer(minLength: 0)
            }
            Text(headline)
                .font(compact ? SWType.headline : SWType.cardTitle)
                .foregroundStyle(SWColor.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if !snapshot.leagues.isEmpty {
                VStack(alignment: .leading, spacing: SWSpacing.xs) {
                    ForEach(snapshot.leagues.prefix(compact ? 3 : 5)) { league in
                        HStack(spacing: SWSpacing.sm) {
                            WidgetPlatformMark(platform: league.platform, size: 14)
                            Text(league.name)
                                .font(SWType.caption)
                                .foregroundStyle(SWColor.secondary)
                                .lineLimit(1)
                            Spacer(minLength: SWSpacing.xs)
                            if league.isLineupSet {
                                Image(systemName: "checkmark")
                                    .font(SWType.glyph)
                                    .foregroundStyle(SWColor.positive)
                            } else {
                                Text(league.issueCount == 1 ? "1 to fix" : "\(league.issueCount) to fix")
                                    .font(SWType.scoreMicro)
                                    .foregroundStyle(SWColor.accent)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Scoreboard

/// One league's matchup as the league card shows it: two names, two scores, and how much
/// of the week each side has left.
struct ScoreboardRow: View {
    let league: WidgetLeague

    private var leading: Bool { league.myScore >= league.opponentScore }

    var body: some View {
        HStack(spacing: SWSpacing.sm) {
            WidgetPlatformMark(platform: league.platform, size: 16)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: SWSpacing.xs) {
                    Text(league.myName)
                        .font(SWType.bodyMedium)
                        .foregroundStyle(SWColor.primary)
                        .lineLimit(1)
                    Spacer(minLength: SWSpacing.xs)
                    Text(league.myScore.widgetScore)
                        .font(SWType.score)
                        .monospacedDigit()
                        .foregroundStyle(league.hasMatchup && league.isLive ? (leading ? SWColor.positive : SWColor.negative) : SWColor.primary)
                }
                HStack(spacing: SWSpacing.xs) {
                    Text(league.opponentName ?? (league.hasMatchup ? "Opponent" : "No matchup this week"))
                        .font(SWType.caption)
                        .foregroundStyle(SWColor.secondary)
                        .lineLimit(1)
                    Spacer(minLength: SWSpacing.xs)
                    if league.hasMatchup {
                        Text(league.opponentScore.widgetScore)
                            .font(SWType.scoreCaption)
                            .monospacedDigit()
                            .foregroundStyle(SWColor.secondary)
                    }
                }
                if league.hasMatchup {
                    Text(league.isFinal ? "Final" : league.mySummary)
                        .font(SWType.micro)
                        .foregroundStyle(SWColor.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct ScoreboardBlock: View {
    let snapshot: WidgetSnapshot
    let rows: Int

    var body: some View {
        VStack(alignment: .leading, spacing: SWSpacing.sm) {
            ForEach(snapshot.leagues.prefix(rows)) { league in
                if let url = WidgetStore.leagueURL(league.id) {
                    Link(destination: url) { ScoreboardRow(league: league) }
                } else {
                    ScoreboardRow(league: league)
                }
            }
            if snapshot.leagues.count > rows {
                Text("+\(snapshot.leagues.count - rows) more in the app")
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
            }
        }
    }
}

// MARK: - Players

struct PlayerRow: View {
    let player: WidgetPlayer
    let against: Bool

    private var tint: Color { against ? SWColor.negative : SWColor.accent }

    var body: some View {
        HStack(spacing: SWSpacing.sm) {
            WidgetHeadshot(player: player, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(player.name)
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.primary)
                    .lineLimit(1)
                Text([player.position, player.team].compactMap { $0 }.joined(separator: " · "))
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
            }
            Spacer(minLength: SWSpacing.xs)
            VStack(alignment: .trailing, spacing: 1) {
                if let value = player.value {
                    Text(value.widgetScore)
                        .font(SWType.scoreCaption)
                        .monospacedDigit()
                        // Estimates are dimmed, never marked — the app's own rule.
                        .foregroundStyle(player.isProjected ? SWColor.tertiary : SWColor.primary)
                }
                Text("×\(player.leagueCount)")
                    .font(SWType.micro)
                    .foregroundStyle(tint)
            }
        }
    }
}

struct PlayersBlock: View {
    let snapshot: WidgetSnapshot
    let rows: Int

    var body: some View {
        HStack(alignment: .top, spacing: SWSpacing.lg) {
            column("Your Guys", snapshot.yourGuys, against: false)
            column("Up against", snapshot.upAgainst, against: true)
        }
    }

    private func column(_ title: String, _ players: [WidgetPlayer], against: Bool) -> some View {
        VStack(alignment: .leading, spacing: SWSpacing.sm) {
            Text(title)
                .font(SWType.bodyMedium)
                .foregroundStyle(against ? SWColor.negative : SWColor.accent)
            if players.isEmpty {
                Text(against ? "Nobody yet" : "No starters yet")
                    .font(SWType.micro)
                    .foregroundStyle(SWColor.tertiary)
            }
            ForEach(players.prefix(rows)) { player in
                PlayerRow(player: player, against: against)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty state

struct EmptyBlock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SWSpacing.sm) {
            Text("Sunday Scaries")
                .font(SWType.cardTitle)
                .foregroundStyle(SWColor.primary)
            Text("Open the app once and your leagues appear here.")
                .font(SWType.caption)
                .foregroundStyle(SWColor.secondary)
        }
    }
}
