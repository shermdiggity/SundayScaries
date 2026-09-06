import SwiftUI

/// Where the scroll position lives, so that only the sky reacts to it.
///
/// This used to be `@State` on `WeeklyView`, which meant every eight points of scroll
/// re-evaluated the ENTIRE screen — the hero, every league card, both carousels, the
/// outlook — purely to move a background by a couple of points. That was the single
/// largest source of scroll lag. With `@Observable`, a view re-renders only if its body
/// READS a property; `WeeklyView` passes this object down without reading it, so a
/// scroll tick re-renders `ParallaxSky` and nothing else.
@MainActor
@Observable
final class ScrollTracker {
    /// Distance from rest, quantised by the caller. Negative while rubber-banding.
    var fromRest: CGFloat = 0
}

/// The animated sky, offset by the scroll. The one view that observes `ScrollTracker`.
struct ParallaxSky: View {
    let palette: SkyPalette
    let scroll: ScrollTracker

    /// How far the sky may drift while the scroll view rubber-bands past its top.
    static let maxParallax: CGFloat = 120

    /// Only an overscroll past the top moves the sky, and never further than the
    /// distance the layer is extended above the screen.
    private var parallax: CGFloat {
        min(max(0, -scroll.fromRest) * 0.30, Self.maxParallax)
    }

    var body: some View {
        // Extended above the top edge by the largest parallax it can take, so a
        // downward drift can never uncover the flat colour underneath.
        SkyView(palette: palette, parallax: parallax)
            .padding(.top, -Self.maxParallax)
            .ignoresSafeArea()
    }
}
