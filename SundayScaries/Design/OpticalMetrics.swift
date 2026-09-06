import SwiftUI
import UIKit

/// Sets a display face and corrects for a line box that does not suit Latin text.
///
/// SwiftUI places a line's baseline at the font's own ascent, and sizes the box from
/// ascent to descent. For a Latin face those metrics are cut for Latin, and the result
/// looks right. For a face carrying another script — Damascus, Noto Sans Syriac, most
/// Arabic and Indic families — the box is sized for marks that sit far above and below
/// the baseline, so the baseline lands high in a box that is much taller than the Latin
/// glyphs need. Set unchanged, the type reads as floating too high with a pool of dead
/// space beneath it. That is exactly what it looks like, and it is a metrics problem,
/// not a rendering fault.
///
/// The correction is measured, not eyeballed, and it is relative rather than absolute:
/// it compares the face's baseline position against where a well-behaved Latin face
/// puts it, and only moves the difference. A normal face measures a shift near zero and
/// is left alone, so this is safe to apply everywhere.
struct SWOpticalMetrics: ViewModifier {
    let face: SWType.Face

    /// Where a Latin text face puts its baseline within its line box.
    private static let latinBaselineFraction: CGFloat = 0.78

    /// Real Latin faces scatter either side of that norm — Helvetica Neue measures
    /// 0.799, EB Garamond 0.78 — and those differences are the typeface's own design,
    /// not a fault to correct. Only a face outside this band is doing something a Latin
    /// face never does, and only then is anything touched. Inside the band this
    /// modifier is a pure no-op.
    private static let baselineTolerance: CGFloat = 0.03

    /// A Latin line box is a little over one em. Anything well beyond this is a
    /// script's mark zone, not leading, and reclaiming it is what closes the dead space.
    private static let latinLineHeightRatio: CGFloat = 1.22
    private static let lineHeightTolerance: CGFloat = 1.35

    func body(content: Content) -> some View {
        if let font = UIFont(name: face.name, size: face.size) {
            let styled = content.font(.custom(face.name, size: face.size))
            if Self.needsCorrection(font, size: face.size) {
                styled
                    // `offset` moves the glyphs without disturbing layout; the negative
                    // padding then takes back the mark zone the glyphs never occupied.
                    .offset(y: Self.latinBaselineFraction * font.lineHeight - font.ascender)
                    .padding(.vertical, -max(0, font.lineHeight - Self.latinLineHeightRatio * face.size) / 2)
            } else {
                styled
            }
        } else {
            // Registration failed or the family was removed: fall back rather than
            // render something wrong.
            content.font(.system(size: face.size, weight: face.fallback))
        }
    }

    private static func needsCorrection(_ font: UIFont, size: CGFloat) -> Bool {
        let fraction = font.ascender / font.lineHeight
        let ratio = font.lineHeight / size
        return abs(fraction - latinBaselineFraction) > baselineTolerance || ratio > lineHeightTolerance
    }
}

extension View {
    /// Applies one of the two display-voice faces, metrics corrected.
    ///
    /// Use this rather than `.font(SWType.display)` anywhere the weekly view speaks in
    /// its own voice, so the app survives the display family being swapped for one with
    /// non-Latin metrics.
    func swVoice(_ face: SWType.Face) -> some View {
        modifier(SWOpticalMetrics(face: face))
    }
}
