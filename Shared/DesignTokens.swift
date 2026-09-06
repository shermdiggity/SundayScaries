import SwiftUI
import UIKit
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
    /// 50% clears WCAG AA (4.9 on the raised surface); 42% did not.
    static let tertiary  = Color(red: 0.976, green: 0.969, blue: 0.957).opacity(0.50)

    /// Content sitting directly on the sky, which can be bright at midday. Always
    /// paired with `Sky.scrim` so the contrast holds in every state.
    static let onSky          = Color.white
    static let onSkySecondary = Color.white.opacity(0.78)

    // Meaning. Tonal rather than poster-bright: a saturated accent sprayed across a
    // page is the fastest way to look templated.
    static let positive = Color(red: 0.388, green: 0.831, blue: 0.545)
    /// The launch screen's one flat colour (an asset, so the launch screen can use it
    /// too). The app's first frame starts here and fades into the live sky.
    static let launch = Color("LaunchBackground")
    static let negative = Color(red: 0.965, green: 0.427, blue: 0.408)
    static let warning  = Color(red: 1.000, green: 0.761, blue: 0.290)
    static let neutral  = Color(red: 0.976, green: 0.969, blue: 0.957).opacity(0.50)

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

    /// The ink for a letter set on a platform's own colour: whichever of the app's two
    /// inks clears it. Canvas on Yahoo purple was 2.9 to 1.
    static func onPlatform(_ platform: Platform) -> Color {
        switch platform {
        case .sleeper, .fleaflicker:            canvas
        case .yahoo, .espn, .myFantasyLeague, .cbs: primary
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

/// One face, throughout: **Helvetica Neue**.
///
/// It ships with iOS, so there is nothing to bundle, register or license, and no
/// fallback to design around. Hierarchy comes from size and weight alone, which is the
/// whole idea — a single family used with conviction reads as a decision, where a
/// display face paired with a separate interface face reads as two.
///
/// Weights: Helvetica Neue has no semibold and no heavy, so SF's `.semibold` maps to
/// Medium in running text and Bold in headings, and `.heavy` maps to Bold. Those are
/// the real faces in the family — nothing here asks for a weight that would be
/// synthesised.
///
/// Numbers keep `.monospacedDigit()`, the highest-leverage typographic decision in a
/// live-scoring app: proportional digits make columns jitter as scores update.
/// Helvetica Neue's digits are already uniform width (556 units, every one), so the
/// columns hold.
///
/// SF Symbols are the one exception and stay on the system face: a symbol is a drawn
/// glyph, not type, and it is designed against SF's metrics.
///
/// EB Garamond preceded this and is still bundled in `Design/Fonts/`, now unreferenced.
enum SWType {
    private static let displayBold = "HelveticaNeue-Bold"
    private static let displayMedium = "HelveticaNeue-Medium"

    /// A resolved display face: the PostScript name actually being rendered, its size,
    /// and what to fall back to. Carried as a value because the optical-metrics
    /// correction has to measure the real face, which a `Font` will not surrender.
    struct Face {
        let name: String
        let size: CGFloat
        let fallback: Font.Weight
    }

    /// Falls back to the system face if registration failed, so a broken bundle looks
    /// plain rather than wrong.
    private static func voice(_ name: String, _ size: CGFloat, fallback: Font.Weight) -> Font {
        let resolved = resolvedName(name)
        return UIFont(name: resolved, size: size) != nil
            ? .custom(resolved, size: size)
            : .system(size: size, weight: fallback)
    }

    /// The debug font browser can swap the display family out from under the app, so a
    /// candidate is judged on the real screen instead of on a specimen sheet.
    private static func resolvedName(_ name: String) -> String {
        #if DEBUG && FONT_BROWSER
        if let family = debugFaceOverride {
            return FontCatalog.face(in: family, like: name)
        }
        #endif
        return name
    }

    #if DEBUG && FONT_BROWSER
    /// Where `FontBrowser` parks the family it wants previewed. `UserDefaults` rather
    /// than a static var so there is no shared mutable state to isolate, and so the
    /// choice survives a relaunch while you sleep on it.
    static let debugFaceKey = "sw.debug.displayFamily"

    private static var debugFaceOverride: String? {
        let name = UserDefaults.standard.string(forKey: debugFaceKey) ?? ""
        return name.isEmpty ? nil : name
    }
    #endif

    // MARK: The two display-voice tokens

    //
    // These are the weekly view's own voice — the hero line and the headers that
    // introduce a group. They are the only tokens with a `Face`, because only they go
    // through `.swVoice(_:)`, which needs to measure the real face to correct a
    // typeface whose line box was not cut for Latin.

    /// The weekly view's hero line, and nothing else.
    static var display: Font { voice(displayBold, 46, fallback: .bold) }
    static var displayFace: Face { Face(name: resolvedName(displayBold), size: 46, fallback: .bold) }

    /// The weekly view's section headers — "Riding on", "Up against", "The season so
    /// far".
    // Bold, and a clear step above the card title (Bold 19). Set Medium at 23 it was
    // OUTWEIGHED by the cards it introduces — the sections' own titles read as the
    // headers and these read as captions, the hierarchy exactly inverted.
    static var sectionHeader: Font { voice(displayBold, 30, fallback: .bold) }
    static var sectionHeaderFace: Face { Face(name: resolvedName(displayBold), size: 30, fallback: .bold) }

    // MARK: Interface

    static var title: Font { voice(displayBold, 26, fallback: .bold) }
    static var headline: Font { voice(displayBold, 19, fallback: .semibold) }
    static var section: Font { voice(displayMedium, 15, fallback: .medium) }
    static var body: Font { voice(displayMedium, 15, fallback: .medium) }
    static var bodyMedium: Font { voice(displayBold, 15, fallback: .semibold) }
    static var caption: Font { voice(displayMedium, 13, fallback: .medium) }
    static var micro: Font { voice(displayBold, 11, fallback: .bold) }
    /// The league card's title line: the most prominent interface text in the app.
    static var cardTitle: Font { voice(displayBold, 19, fallback: .bold) }

    /// Sized to the mark they sit in rather than to a step on the scale, so they scale
    /// with the circle that contains them.
    static func mark(_ size: CGFloat) -> Font { voice(displayBold, size, fallback: .black) }
    static func initials(_ size: CGFloat) -> Font { voice(displayMedium, size, fallback: .semibold) }

    // SF Symbols only. A symbol is a drawn glyph, not type, and it is cut against SF's
    // own metrics — setting it in Helvetica Neue would only misalign it.
    /// The one icon size in the app.
    static let icon  = Font.system(size: 20, weight: .bold, design: .rounded)
    /// Small glyphs that sit inside a control — a checkmark, a chevron.
    static let glyph = Font.system(size: 10, weight: .black, design: .rounded)

    // MARK: Numbers

    static var score: Font { voice(displayBold, 18, fallback: .bold).monospacedDigit() }
    static var scoreLarge: Font { voice(displayBold, 34, fallback: .heavy).monospacedDigit() }
    static var scoreCaption: Font { voice(displayBold, 13, fallback: .semibold).monospacedDigit() }
    static var scoreMicro: Font { voice(displayBold, 11, fallback: .bold).monospacedDigit() }
}

// MARK: - Numbers

enum SWFormat {
    /// Every score, projection and total in the app: one decimal, so a column of them holds.
    static let score = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
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
