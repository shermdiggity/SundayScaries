import SwiftUI
import FantasyCore

// Every colour, size, duration and font in this app resolves through this file.
// Nothing else defines a raw hex, a raw spacing number, or an ad-hoc Animation.

// MARK: - Colour

/// Named by meaning, never by value. Fantasy is unusually semantic — everything is
/// winning or losing, started or benched, healthy or hurt — so the palette can change
/// without a find-and-replace.
enum SWColor {
    // Surfaces. The canvas is deliberately near-black rather than the cool blue-charcoal
    // every dark product ships; this one is warmed, so it belongs to the sky above it.
    static let canvas        = Color(red: 0.055, green: 0.051, blue: 0.047)
    static let surface       = Color(red: 0.094, green: 0.086, blue: 0.078)
    static let surfaceRaised = Color(red: 0.129, green: 0.118, blue: 0.106)
    static let hairline      = Color.white.opacity(0.10)

    // Content.
    static let primary   = Color(red: 0.976, green: 0.969, blue: 0.957)
    static let secondary = Color(red: 0.976, green: 0.969, blue: 0.957).opacity(0.68)
    static let tertiary  = Color(red: 0.976, green: 0.969, blue: 0.957).opacity(0.42)

    /// Content sitting directly on the sky, which can be bright at midday. Always
    /// paired with `Sky.scrim` so the contrast holds in every state.
    static let onSky          = Color.white
    static let onSkySecondary = Color.white.opacity(0.78)

    // Meaning. Tonal rather than poster-bright: a saturated accent sprayed across a
    // page is the fastest way to look templated.
    static let positive = Color(red: 0.388, green: 0.831, blue: 0.545)
    static let negative = Color(red: 0.965, green: 0.427, blue: 0.408)
    static let warning  = Color(red: 1.000, green: 0.761, blue: 0.290)
    static let neutral  = Color(red: 0.976, green: 0.969, blue: 0.957).opacity(0.42)

    /// A game in progress.
    static let live = Color(red: 0.937, green: 0.616, blue: 0.286)

    /// One accent, and only one. A warm ember — it reads against every sky state from
    /// dawn to midnight, which a cool accent does not.
    static let accent = Color(red: 1.000, green: 0.596, blue: 0.235)

    /// Each platform's own colour, held quiet. Used as a small mark rather than a
    /// borrowed logo — never louder than the content it labels.
    static func platform(_ platform: Platform) -> Color {
        switch platform {
        case .sleeper:          Color(red: 0.28, green: 0.63, blue: 0.93)
        case .yahoo:            Color(red: 0.44, green: 0.24, blue: 0.75)
        case .espn:             Color(red: 0.85, green: 0.20, blue: 0.20)
        case .myFantasyLeague:  Color(red: 0.20, green: 0.45, blue: 0.75)
        case .fleaflicker:      Color(red: 0.25, green: 0.60, blue: 0.35)
        case .cbs:              Color(red: 0.10, green: 0.40, blue: 0.80)
        }
    }

    /// The tint a league's surfaces carry. One value, used by the card's glass and by
    /// every panel on the detail screen, so opening a league continues the material it
    /// started from instead of cutting to a different one.
    static func leagueTint(_ platform: Platform) -> Color {
        self.platform(platform).opacity(0.30)
    }

    /// The single flat colour a league's card reads as: its sky, tinted by the same
    /// amount the card's glass tints it, lifted slightly for the glass itself.
    ///
    /// A gradient cannot survive being compressed to card height — the whole ramp
    /// squashes and the colour visibly shifts. Flattening to this before the zoom means
    /// the shrinking rectangle is already the colour of the card it becomes.
    static func leagueFlat(_ platform: Platform, over sky: Color) -> Color {
        sky.mixed(with: self.platform(platform), by: 0.30)
           .mixed(with: surfaceRaised, by: 0.28)
    }

    /// Each platform's own mark, served from its own CDN. Used nominatively — to say
    /// "this league lives on Sleeper" — never restyled or redrawn, and never bundled.
    static func platformLogo(_ platform: Platform) -> URL? {
        switch platform {
        case .sleeper: URL(string: "https://sleepercdn.com/images/v2/logos/sleeper.png")
        default:       nil
        }
    }

    /// Position colours follow the near-standard convention shared by Sleeper and ESPN.
    /// Matching it buys instant legibility for free; inventing our own costs clarity for
    /// nothing. Held at a lower saturation than the platforms use, so a lineup reads as
    /// type rather than as a row of stickers.
    static func position(_ position: Position) -> Color {
        switch position {
        case .qb:    Color(red: 1.000, green: 0.431, blue: 0.545)
        case .rb:    Color(red: 0.243, green: 0.863, blue: 0.749)
        case .wr:    Color(red: 0.404, green: 0.714, blue: 1.000)
        case .te:    Color(red: 1.000, green: 0.729, blue: 0.396)
        case .k:     Color(red: 0.769, green: 0.573, blue: 1.000)
        case .def:   Color(red: 0.588, green: 0.647, blue: 0.741)
        case .other: neutral
        }
    }
}

// MARK: - Type

/// Two faces, each doing the job it is good at.
///
/// **EB Garamond** (self-hosted, SIL Open Font License) carries the identity.
///
/// Apple Garamond — the face this was specified as — is Apple's own discontinued
/// corporate font, a customised ITC Garamond that was never shipped to third parties
/// and cannot be licensed. EB Garamond is a genuine Garamond revival, it is freely
/// redistributable (unlike the ITF faces, so this one may live in a public repo), and
/// it is the closest honest substitute.
///
/// **SF Rounded** carries everything else. Rounded rather than standard because the
/// whole app should feel played-with, not audited — and every number in a column stays
/// `.monospacedDigit()`, which is the highest-leverage typographic decision in a
/// live-scoring app: proportional digits make columns jitter as scores update.
enum SWType {
    private static let display_ = "EBGaramond-SemiBold"
    private static let displayBold = "EBGaramond-Bold"
    private static let displayRegular = "EBGaramond-Medium"

    /// Falls back to the system face if registration failed, so a broken bundle looks
    /// plain rather than wrong.
    private static func serif(_ name: String, _ size: CGFloat, fallback: Font.Weight) -> Font {
        FontRegistrar.displayFaceAvailable
            ? .custom(name, size: size)
            : .system(size: size, weight: fallback)
    }

    // Garamond sits small on the body and reads light, so every size steps up.
    static var display: Font  { serif(displayBold, 46, fallback: .bold) }
    static var title: Font    { serif(displayBold, 31, fallback: .bold) }
    static var headline: Font { serif(display_, 23, fallback: .semibold) }
    static var section: Font  { serif(displayRegular, 18, fallback: .medium) }

    static let body       = Font.system(size: 15, weight: .medium, design: .rounded)
    static let bodyMedium = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let caption    = Font.system(size: 13, weight: .medium, design: .rounded)
    static let micro      = Font.system(size: 11, weight: .bold, design: .rounded)
    /// The one icon size in the app.
    static let icon       = Font.system(size: 20, weight: .bold, design: .rounded)
    /// Small glyphs that sit inside a control — a checkmark, a chevron.
    static let glyph      = Font.system(size: 10, weight: .black, design: .rounded)
    /// The league card's title line: the most prominent interface text in the app.
    static let cardTitle  = Font.system(size: 19, weight: .bold, design: .rounded)

    static let score        = Font.system(size: 18, weight: .bold, design: .rounded).monospacedDigit()
    static let scoreLarge   = Font.system(size: 34, weight: .heavy, design: .rounded).monospacedDigit()
    static let scoreCaption = Font.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit()
    static let scoreMicro   = Font.system(size: 11, weight: .bold, design: .rounded).monospacedDigit()
}

// MARK: - Spacing, radius, motion

enum SWSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum SWRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
}

/// Three durations, so nothing on the screen feels out of tempo with anything else.
enum SWMotion {
    static let quick    = Animation.snappy(duration: 0.2)
    static let standard = Animation.smooth(duration: 0.3)
    static let reveal   = Animation.spring(response: 0.5, dampingFraction: 0.8)
}
