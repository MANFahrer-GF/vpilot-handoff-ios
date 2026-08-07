import SwiftUI

/// Everything the controller-row colour editor can change (gallery/06-controller-colors.png):
/// one highlight colour per facility, the fixed contact-me alert colour, and the three
/// derived-appearance axes -- how dark non-highlighted rows sit, when row text flips
/// from dark to white, and how much extra darkening dark mode applies.
struct ControllerTheme: Codable, Equatable, Identifiable {
    var id: String { name }

    var name: String
    var delivery: RGBColor
    var ground: RGBColor
    var tower: RGBColor
    var approach: RGBColor
    var center: RGBColor
    var atis: RGBColor
    var other: RGBColor
    var contactMeAlert: RGBColor

    /// Where a non-highlighted row sits between black (0) and white (1), with 0.5
    /// meaning "exactly its highlight colour".
    var nonHighlightBrightness: Double
    /// Luminance below which row text switches from black to white.
    var textContrastThreshold: Double
    /// Extra darkening applied to every row in dark mode: 0 = off, 1 = black.
    var darkModeOffset: Double

    func highlightColor(for controller: Controller) -> RGBColor {
        if controller.isAtis { return atis }
        switch controller.facility {
        case 2: return delivery
        case 3: return ground
        case 4: return tower
        case 5: return approach
        case 6: return center
        default: return other
        }
    }

    /// The colour a row actually renders in, after the highlight/non-highlight and
    /// dark-mode adjustments.
    func rowColor(for controller: Controller, darkMode: Bool) -> Color {
        var rgb = highlightColor(for: controller)
        if !controller.isHighlighted {
            rgb = rgb.mixedTowardExtremes(nonHighlightBrightness)
        }
        if darkMode, darkModeOffset > 0 {
            rgb = rgb.mixed(with: .black, amount: darkModeOffset)
        }
        return rgb.color
    }

    func textColor(on background: RGBColor) -> Color {
        background.luminance > textContrastThreshold ? .black : .white
    }
}

/// Codable colour storage -- SwiftUI's `Color` isn't Codable, and round-tripping
/// through UIColor loses precision on the sliders.
struct RGBColor: Codable, Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double

    static let black = RGBColor(red: 0, green: 0, blue: 0)
    static let white = RGBColor(red: 1, green: 1, blue: 1)

    var color: Color { Color(red: red, green: green, blue: blue) }

    /// Perceptual-ish luminance, the same weighting the text-contrast slider works against.
    var luminance: Double { 0.299 * red + 0.587 * green + 0.114 * blue }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(_ color: Color) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(red: Double(r), green: Double(g), blue: Double(b))
        #else
        self.init(red: 0, green: 0, blue: 0)
        #endif
    }

    /// Hex convenience for the built-in palettes.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    func mixed(with other: RGBColor, amount: Double) -> RGBColor {
        let t = min(max(amount, 0), 1)
        return RGBColor(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t
        )
    }

    /// 0 -> black, 0.5 -> unchanged, 1 -> white. This is the non-highlight
    /// brightness slider's Black … Highlight … White axis.
    func mixedTowardExtremes(_ position: Double) -> RGBColor {
        let p = min(max(position, 0), 1)
        if p < 0.5 {
            return mixed(with: .black, amount: 1 - p / 0.5)
        }
        return mixed(with: .white, amount: (p - 0.5) / 0.5)
    }
}

extension ControllerTheme {
    static let `default` = ControllerTheme(
        name: "Default",
        delivery: RGBColor(hex: 0x4A7BC8),
        ground: RGBColor(hex: 0x59993D),
        tower: RGBColor(hex: 0xB82222),
        approach: RGBColor(hex: 0xCC731C),
        center: RGBColor(hex: 0x8C66C7),
        atis: RGBColor(hex: 0xEDC733),
        other: RGBColor(hex: 0x6B6B75),
        contactMeAlert: RGBColor(hex: 0xA15CD9),
        nonHighlightBrightness: 0.14,
        textContrastThreshold: 0.6,
        darkModeOffset: 0.15
    )

    /// Okabe-Ito derived palettes: hues chosen to stay separable for the two most
    /// common forms of red-green colour deficiency. Picked for distinguishability,
    /// not clinically validated -- the per-row editor is there if these don't work
    /// for a given pilot.
    static let deuteranopiaSafe = ControllerTheme(
        name: "Deuteranopia-safe",
        delivery: RGBColor(hex: 0x0072B2),
        ground: RGBColor(hex: 0x009E73),
        tower: RGBColor(hex: 0xD55E00),
        approach: RGBColor(hex: 0xE69F00),
        center: RGBColor(hex: 0xCC79A7),
        atis: RGBColor(hex: 0xF0E442),
        other: RGBColor(hex: 0x6B6B75),
        contactMeAlert: RGBColor(hex: 0x56B4E9),
        nonHighlightBrightness: 0.14,
        textContrastThreshold: 0.6,
        darkModeOffset: 0.15
    )

    static let protanopiaSafe = ControllerTheme(
        name: "Protanopia-safe",
        delivery: RGBColor(hex: 0x0072B2),
        ground: RGBColor(hex: 0x009E73),
        tower: RGBColor(hex: 0xE69F00),
        approach: RGBColor(hex: 0xF0E442),
        center: RGBColor(hex: 0x9C7BC4),
        atis: RGBColor(hex: 0x56B4E9),
        other: RGBColor(hex: 0x6B6B75),
        contactMeAlert: RGBColor(hex: 0xCC79A7),
        nonHighlightBrightness: 0.14,
        textContrastThreshold: 0.6,
        darkModeOffset: 0.15
    )

    static let presets: [ControllerTheme] = [.default, .deuteranopiaSafe, .protanopiaSafe]
}
