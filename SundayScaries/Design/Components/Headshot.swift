import SwiftUI
import FantasyCore

/// A player's face, with a graceful ladder down to something that always renders.
///
/// Headshots are the reason a lineup reads as people rather than rows of text, but they
/// are also the most likely thing to be missing — a rookie signed yesterday, a defense,
/// an offline launch. So: the photo, else the player's initials on their position
/// colour, and never an empty hole.
struct Headshot: View {
    let player: PlayerRef
    var size: CGFloat = 44
    /// A thick, flat ring — the outline a sticker or a football card would have.
    var strokeWidth: CGFloat = 1
    /// Team defenses are logos, which need room to breathe rather than a tight crop.
    private var isLogo: Bool { player.position == .def }

    var body: some View {
        Group {
            if let url = player.headshotURL, !player.isEmptyLineupSlot {
                CachedImage(url: url) {
                    // Only ever seen the first time a face is fetched. On every later
                    // appearance the image is already in memory and renders on frame one.
                    placeholder
                }
                .aspectRatio(contentMode: isLogo ? .fit : .fill)
                .padding(isLogo ? size * 0.16 : 0)
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(tint.opacity(0.22))
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(tint.opacity(strokeWidth > 1 ? 0.95 : 0.45), lineWidth: strokeWidth)
        }
        .accessibilityHidden(true)
    }

    private var tint: Color {
        player.isEmptyLineupSlot ? SWColor.neutral : SWColor.position(player.position)
    }

    private var placeholder: some View {
        Circle().fill(SWColor.primary.opacity(0.10))
    }

    private var fallback: some View {
        Text(initials)
            .font(SWType.initials(size * 0.34))
            .foregroundStyle(tint)
            .minimumScaleFactor(0.6)
    }

    private var initials: String {
        guard !player.isEmptyLineupSlot else { return "–" }
        let parts = player.name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}

#Preview {
    HStack(spacing: SWSpacing.lg) {
        Headshot(player: PlayerRef(identity: .canonical(id: "1", source: .gsis),
                                   name: "Justin Jefferson", nflTeam: "MIN", position: .wr,
                                   headshotURL: URL(string: "https://sleepercdn.com/content/nfl/players/6794.jpg")))
        Headshot(player: PlayerRef(identity: .canonical(id: "2", source: .gsis),
                                   name: "Rookie Nobody", nflTeam: "BUF", position: .rb))
        Headshot(player: PlayerRef(identity: .canonical(id: "DEF-PIT", source: .teamDefense),
                                   name: "Pittsburgh Steelers", nflTeam: "PIT", position: .def,
                                   headshotURL: URL(string: "https://sleepercdn.com/images/team_logos/nfl/pit.png")))
        Headshot(player: .emptyLineupSlot(platform: .sleeper))
    }
    .padding(SWSpacing.xl)
    .background(SWColor.canvas)
}
