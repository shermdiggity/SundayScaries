import SwiftUI
import CoreText

/// Registers the bundled display face at launch.
///
/// Registering in code rather than through `UIAppFonts` keeps this working with the
/// project's synchronized-folder layout, where there is no hand-edited Info.plist.
enum FontRegistrar {
    private static let faces = [
        "EBGaramond-Regular", "EBGaramond-Medium", "EBGaramond-SemiBold", "EBGaramond-Bold",
    ]

    /// Idempotent: registering twice is harmless, and a missing file degrades to the
    /// system face rather than crashing.
    static func registerAll() {
        for face in faces {
            guard let url = Bundle.main.url(forResource: face, withExtension: "otf")
                ?? Bundle.main.url(forResource: face, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// True when the display face actually loaded, so a preview or a broken build shows
    /// the fallback rather than silently looking wrong.
    static var displayFaceAvailable: Bool {
        UIFont(name: "EBGaramond-SemiBold", size: 12) != nil
    }
}
