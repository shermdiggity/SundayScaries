import SwiftUI
import FantasyCore

/// Shimmer sweep, adapted from ShipSwift (MIT) — github.com/signerlabs/ShipSwift.
/// Changed: honours Reduce Motion by holding a still highlight instead of sweeping.
struct SWShimmer<Content: View>: View {
    var duration: Double = 1.6
    var delay: Double = 0.2
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    private var band: LinearGradient {
        LinearGradient(
            colors: [.clear, .clear, .white.opacity(0.14), .clear, .clear],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    var body: some View {
        content()
            .overlay {
                GeometryReader { geo in
                    let width = geo.size.width * 0.5
                    band
                        .frame(width: width)
                        .offset(x: animate ? geo.size.width + width : -width * 1.5)
                        .animation(
                            reduceMotion ? nil :
                                .linear(duration: duration).delay(delay).repeatForever(autoreverses: false),
                            value: animate
                        )
                }
                .clipped()
                .allowsHitTesting(false)
            }
            .task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                animate = true
            }
    }
}

/// A placeholder block. Skeletons over spinners, everywhere: a spinner says "wait",
/// a skeleton says "here is the shape of what is coming", and the screen does not
/// reflow when the data lands.
struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat = 12
    var radius: CGFloat = 4

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
            HStack(spacing: SWSpacing.sm) {
                PlatformMark(platform: league.platform)
                VStack(alignment: .leading, spacing: 2) {
                    Text(league.name)
                        .font(SWType.cardTitle)
                        .foregroundStyle(SWColor.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    SkeletonBlock(width: 64, height: 11)
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

    private var placeholderSide: some View {
        VStack(spacing: SWSpacing.sm) {
            HStack(spacing: SWSpacing.xs) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(SWColor.primary.opacity(0.12)).frame(width: 34, height: 34)
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
