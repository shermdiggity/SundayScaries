import SwiftUI

/// The sky is the app's signature, and it is not decoration: it tells you what time it
/// is without a clock. Sunday at 4pm looks like Sunday at 4pm — which is exactly when
/// the games that make you anxious are on.
struct SkyPalette: Equatable {
    var sky: Color
    var cloud: Color
    var warmTint: Color
    var warmth: Float
    var coverage: Float
    /// How hard the top of the sky is darkened so content stays readable. A bright
    /// midday sky needs far more than a midnight one; without this the same white type
    /// that reads at 11pm is unreadable at 1pm.
    var scrim: Double

    static func lerp(_ a: SkyPalette, _ b: SkyPalette, _ t: Double) -> SkyPalette {
        SkyPalette(
            sky: a.sky.mixed(with: b.sky, by: t),
            cloud: a.cloud.mixed(with: b.cloud, by: t),
            warmTint: a.warmTint.mixed(with: b.warmTint, by: t),
            warmth: Float(Double(a.warmth) + (Double(b.warmth) - Double(a.warmth)) * t),
            coverage: Float(Double(a.coverage) + (Double(b.coverage) - Double(a.coverage)) * t),
            scrim: a.scrim + (b.scrim - a.scrim) * t
        )
    }
}

enum Sky {
    /// Anchors through the day, interpolated between so the sky drifts rather than
    /// snapping between states.
    private static let anchors: [(hour: Double, palette: SkyPalette)] = [
        (0, SkyPalette(sky: .hex(0x080B16), cloud: .hex(0x4A5273), warmTint: .hex(0x140C06), warmth: 0.40, coverage: 0.04, scrim: 0.12)),
        (5, SkyPalette(sky: .hex(0x1B2145), cloud: .hex(0x7E6A85), warmTint: .hex(0x3A1C10), warmth: 0.90, coverage: 0.03, scrim: 0.36)),
        (7, SkyPalette(sky: .hex(0x4A4463), cloud: .hex(0xE0A98A), warmTint: .hex(0x6B2E14), warmth: 1.10, coverage: 0.05, scrim: 0.58)),
        (10, SkyPalette(sky: .hex(0x5A86B8), cloud: .hex(0xEDF1F7), warmTint: .hex(0x241608), warmth: 0.25, coverage: 0.02, scrim: 0.72)),
        (13, SkyPalette(sky: .hex(0x4E8FD0), cloud: .hex(0xFFFFFF), warmTint: .hex(0x1A1206), warmth: 0.15, coverage: 0.00, scrim: 0.78)),
        (17, SkyPalette(sky: .hex(0x7A7196), cloud: .hex(0xF2C48C), warmTint: .hex(0x7A3A12), warmth: 1.00, coverage: 0.06, scrim: 0.66)),
        (19, SkyPalette(sky: .hex(0x3B3358), cloud: .hex(0xC98A72), warmTint: .hex(0x5E2410), warmth: 1.00, coverage: 0.04, scrim: 0.46)),
        (21, SkyPalette(sky: .hex(0x121630), cloud: .hex(0x5A5F84), warmTint: .hex(0x22110A), warmth: 0.55, coverage: 0.03, scrim: 0.18)),
        (24, SkyPalette(sky: .hex(0x080B16), cloud: .hex(0x4A5273), warmTint: .hex(0x140C06), warmth: 0.40, coverage: 0.04, scrim: 0.12)),
    ]

    static func palette(at date: Date = Date(), calendar: Calendar = .current) -> SkyPalette {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(parts.hour ?? 12) + Double(parts.minute ?? 0) / 60

        for index in 0..<(anchors.count - 1) {
            let lower = anchors[index]
            let upper = anchors[index + 1]
            if hour >= lower.hour, hour <= upper.hour {
                let span = upper.hour - lower.hour
                let t = span > 0 ? (hour - lower.hour) / span : 0
                return .lerp(lower.palette, upper.palette, t)
            }
        }
        return anchors[0].palette
    }
}

/// The sky as a still gradient — the same palette, no shader.
///
/// The cloud shader runs two five-octave FBM evaluations per pixel, which is far too
/// expensive to have more than one of. The weekly view owns the animated sky; every
/// other screen uses this, so pushing a screen never puts two of them on the GPU at
/// once. That double-shader moment was what made navigation stutter.
struct StaticSky: View {
    var palette: SkyPalette

    var body: some View {
        LinearGradient(
            colors: [
                palette.sky,
                palette.sky.mixed(with: palette.cloud, by: 0.22),
                palette.sky.mixed(with: palette.cloud, by: 0.08),
                palette.sky,
            ],
            startPoint: .top, endPoint: .bottom
        )
        .overlay {
            LinearGradient(
                colors: [.black.opacity(palette.scrim * 0.35), .clear],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}

/// The sky itself. Full-bleed clouds under a scrim tuned to the time of day.
///
/// `parallax` moves the sky against the scroll rather than pinning it behind the page —
/// a background that simply trails the scroll reads as a sheet of wallpaper.
struct SkyView: View {
    var palette: SkyPalette
    var parallax: CGFloat = 0

    var body: some View {
        SWFractalClouds(
            skyColor: palette.sky,
            cloudColor: palette.cloud,
            warmTint: palette.warmTint,
            warmth: palette.warmth,
            speed: 0.9,
            zoom: 2.1,
            driftX: 0.11,
            driftY: 0.028,
            warp: 0.0,
            coverage: -0.55
        )
        .offset(y: parallax)
        .overlay {
            // Content sits in the upper half, so the darkening lives there and resolves
            // to nothing before the bottom edge — no band, no visible seam.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(palette.scrim), location: 0.0),
                    .init(color: .black.opacity(palette.scrim * 0.72), location: 0.28),
                    .init(color: .black.opacity(palette.scrim * 0.24), location: 0.62),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Colour helpers
