import SwiftUI

// Colour arithmetic the tokens and the sky both use. Shared with the widgets.
extension Color {
    static func hex(_ value: UInt32) -> Color {
        Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// Linear blend in sRGB. Enough for interpolating two nearby sky colours.
    func mixed(with other: Color, by amount: Double) -> Color {
        let t = min(max(amount, 0), 1)
        let a = components
        let b = other.components
        return Color(
            red: a.r + (b.r - a.r) * t,
            green: a.g + (b.g - a.g) * t,
            blue: a.b + (b.b - a.b) * t
        )
    }

    private var components: (r: Double, g: Double, b: Double) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
        #else
        return (0, 0, 0)
        #endif
    }
}
