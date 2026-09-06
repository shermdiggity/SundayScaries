#if DEBUG
import SwiftUI
import UIKit
import CoreText

/// Every typeface the app can actually render right now, gathered from the runtime.
///
/// Two sources, and the distinction matters when picking one:
///
/// - **System families.** ~80 faces shipped with iOS. They cost nothing to use, add
///   nothing to the bundle, need no licence, and are on every device. Several are
///   genuinely distinctive — Optima, Iowan Old Style, Charter, Didot, Hoefler Text —
///   and none of them are the free-webfont rotation that reads as generic.
/// - **Bundled families.** Anything dropped into `Design/Fonts/` and registered by
///   `FontRegistrar`. Right now that is EB Garamond alone.
///
/// This is debug-only: the whole file compiles out of release.
enum FontCatalog {

    // MARK: Families

    struct Family: Identifiable, Hashable {
        let name: String
        let faces: [String]
        let kind: Kind

        var id: String { name }
        /// Bundled faces are the ones we ship ourselves rather than borrow from iOS.
        var isBundled: Bool { FontCatalog.bundledFamilies.contains(name) }
    }

    enum Kind: String, CaseIterable, Identifiable {
        case serif   = "Serif"
        case sans    = "Sans"
        case mono    = "Mono"
        case display = "Display"

        var id: String { rawValue }
    }

    /// Families registered by us rather than by the OS.
    static let bundledFamilies: Set<String> = ["EB Garamond"]

    /// Sorted so the faces we ship come first — they are the ones being judged against.
    static let all: [Family] = UIFont.familyNames
        .map { Family(name: $0, faces: UIFont.fontNames(forFamilyName: $0).sorted(), kind: kind(of: $0)) }
        .filter { !$0.faces.isEmpty }
        .sorted { a, b in
            if a.isBundled != b.isBundled { return a.isBundled }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

    // MARK: Classification

    /// Read off the font's own descriptor rather than guessed from its name. The family
    /// class lives in the top four bits of the symbolic traits.
    private static func kind(of family: String) -> Kind {
        guard let first = UIFont.fontNames(forFamilyName: family).first,
              let font = UIFont(name: first, size: 12) else { return .sans }
        let traits = font.fontDescriptor.symbolicTraits
        if traits.contains(.traitMonoSpace) { return .mono }
        switch traits.rawValue & 0xF000_0000 {
        case 1 << 28, 2 << 28, 3 << 28, 4 << 28, 5 << 28, 7 << 28: return .serif
        case 8 << 28:                                              return .sans
        case 9 << 28, 10 << 28:                                    return .display
        default:                                                   return .sans
        }
    }

    // MARK: Weight matching

    /// Picks the face in `family` that best stands in for `reference`.
    ///
    /// The app asks for its display face by exact PostScript name ("EBGaramond-Bold").
    /// When the debug override swaps the family, that name no longer exists, so the
    /// nearest weight in the new family has to be found — while avoiding the italics,
    /// condensed and expanded cuts that would change more than the typeface.
    static func face(in family: String, like reference: String) -> String {
        // "-SemiBold" does not end in "-Bold", so this separates the two correctly.
        let wantsBold = reference.hasSuffix("-Bold")
        let names = UIFont.fontNames(forFamilyName: family)
        guard !names.isEmpty else { return family }

        func score(_ name: String) -> Int {
            let n = name.lowercased()
            var s = 0
            for bad in ["italic", "oblique", "condensed", "expanded", "narrow"] where n.contains(bad) {
                s -= 100
            }
            if wantsBold {
                if n.contains("semibold") || n.contains("demibold") { s += 60 } else if n.contains("bold") { s += 80 } else if n.contains("black") || n.contains("heavy") { s += 40 } else if n.contains("medium") { s += 30 } else { s += 10 }
            } else {
                if n.contains("semibold") || n.contains("demibold") { s += 80 } else if n.contains("medium") { s += 70 } else if n.contains("bold") { s += 40 } else if n.contains("light") || n.contains("thin") { s += 5 } else { s += 50 }
            }
            return s
        }

        return names.max { score($0) < score($1) } ?? family
    }

    // MARK: Latin coverage

    /// Whether the face can actually draw Latin text.
    ///
    /// This is not hypothetical. Noto Sans Syriac ships with iOS, appears in the family
    /// list like any other font, and contains 150 codepoints with no Latin alphabet at
    /// all — no `A`, no `a`. Asking for it renders every English word in iOS's fallback
    /// face instead, so the specimen on screen is not the font named above it. Without
    /// this check the browser confidently shows you a font you are not looking at.
    static func hasLatin(_ faceName: String) -> Bool {
        guard let font = UIFont(name: faceName, size: 12) else { return false }
        var characters = Array("AaGgQq1".utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        let mapped = CTFontGetGlyphsForCharacters(font as CTFont, &characters, &glyphs, characters.count)
        return mapped && glyphs.allSatisfy { $0 != 0 }
    }

    // MARK: Tabular figures

    /// True when the face's digits are all the same width.
    ///
    /// This is the one objective test in the browser, and the one that actually decides
    /// whether a face can carry live scores: proportional digits make a column of
    /// numbers shuffle sideways every time a score ticks over.
    static func hasTabularFigures(_ faceName: String) -> Bool {
        guard let font = UIFont(name: faceName, size: 32) else { return false }
        let widths = (0...9).map { digit -> CGFloat in
            (String(digit) as NSString).size(withAttributes: [.font: font]).width
        }
        guard let first = widths.first else { return false }
        return widths.allSatisfy { abs($0 - first) < 0.01 }
    }
}
#endif
