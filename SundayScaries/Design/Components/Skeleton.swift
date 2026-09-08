import SwiftUI
import FantasyCore

/// A loading state that breathes.
///
/// This was a shimmer: a half-width gradient band in a `GeometryReader` overlay, offset
/// across the view forever and clipped, one per skeleton. Two problems, one cause. Each
/// band was a continuously animating, clipped layer compositing over a full-screen Metal
/// shader — several of them at once dropped frames on every load. And because it was an
/// overlay, it was literally a rectangle laid on top of the content: it swept across
/// text, gaps and rounded corners alike, which is what made it read as boxy and canned.
///
/// Now the content itself pulses in opacity — a single Core Animation property on the
/// group, no overlay, no mask, no geometry. The effect belongs to the placeholder
/// shapes, so it follows every rounded corner and every gap for free, and it costs
/// almost nothing. The name is kept so nothing that uses it had to change.
struct SWShimmer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @State private var dimmed = false

    var body: some View {
        content()
            .opacity(dimmed ? 0.55 : 1)
            .animation(SWMotion.breathe, value: dimmed)
            .onAppear { dimmed = true }
    }
}

/// A placeholder block. Skeletons over spinners, everywhere: a spinner says "wait",
/// a skeleton says "here is the shape of what is coming", and the screen does not
/// reflow when the data lands.
struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat = SWSpacing.md
    var radius: CGFloat = SWSpacing.xs

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(SWColor.primary.opacity(0.12))
            .frame(width: width, height: height)
    }
}

/// The loading form of a league card.
///
/// It is the real card's geometry, with the league's real name and platform already in
/// place — those are known the moment the league list returns. Only the matchup is
/// skeletal, so a card resolving is a small change in one place rather than the whole
/// screen rearranging.
struct LeagueCardSkeleton: View {
    let league: League

    var body: some View {
        VStack(alignment: .leading, spacing: SWSpacing.md) {
            // The card's header, line for line: your team (not known until the rosters
            // land) as a block on the title line, the league already named under it,
            // and a block where the record goes. Each block sits in a hidden line of
            // the real type, so it is exactly as tall as the text that replaces it.
            HStack(alignment: .top, spacing: SWSpacing.sm) {
                PlatformMark(platform: league.platform)
                    .padding(.top, SWSpacing.xxs)
                VStack(alignment: .leading, spacing: SWSpacing.xxs) {
                    line(SWType.cardTitle) { SkeletonBlock(width: 152, height: 15, radius: 5) }
                    Text(league.name)
                        .font(SWType.caption)
                        .foregroundStyle(SWColor.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    line(SWType.scoreCaption) { SkeletonBlock(width: 64, height: 11) }
                }
                Spacer(minLength: 0)
            }

            // No shimmer inside the card: the list wraps all of its placeholders in a
            // single sweep, so N loading cards cost one animation rather than N.
            VStack(spacing: SWSpacing.md) {
                SkeletonBlock(height: 34, radius: SWRadius.sm)

                HStack(spacing: SWSpacing.lg) {
                    placeholderSide
                    SkeletonBlock(width: 22, height: 12)
                    placeholderSide
                }

                SkeletonBlock(height: 8, radius: 4)
            }
        }
        .padding(SWSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .leagueSurface(league.platform)
        .accessibilityLabel(Text("Loading \(league.name)"))
    }

    /// A placeholder block on a line of the given type: the line's height without its
    /// words.
    private func line<Block: View>(_ font: Font, @ViewBuilder block: () -> Block) -> some View {
        Text(verbatim: "Ag")
            .font(font)
            .hidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) { block() }
            .accessibilityHidden(true)
    }

    private var placeholderSide: some View {
        VStack(spacing: SWSpacing.sm) {
            HStack(spacing: SWSpacing.xs) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(SWColor.primary.opacity(0.12))
                        .frame(width: SWSize.faceMatchup, height: SWSize.faceMatchup)
                }
            }
            SkeletonBlock(width: 72, height: 11)
            SkeletonBlock(width: 46, height: 14, radius: 5)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The hero's loading form: the sentence has a shape before it has words.
struct HeroSkeleton: View {
    var body: some View {
        SWShimmer {
            VStack(alignment: .leading, spacing: SWSpacing.md) {
                SkeletonBlock(width: 66, height: 13)
                SkeletonBlock(width: 292, height: 34, radius: 8)
                SkeletonBlock(width: 208, height: 34, radius: 8)
            }
        }
        .accessibilityLabel("Loading your week")
    }
}
