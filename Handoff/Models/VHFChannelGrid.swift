import Foundation

/// Which frequencies count as a real channel.
///
/// Deliberately a model type rather than a couple of private helpers on the tune
/// sheet: the first version of this lived in the view, untested, and shipped doing
/// nothing at all -- the spacing toggle changed a label and no behaviour. Anything
/// that decides whether a command goes out belongs where it can be pinned down.
enum VHFChannelGrid: Equatable {
    case khz25
    case khz833

    /// Civil VHF airband. The plugin drops anything outside this without a word, so
    /// there's no value in letting it through.
    static let band: ClosedRange<Double> = 118.0...136.990

    /// 8.33 kHz *channel names* aren't simply every 5 kHz: each 25 kHz block carries
    /// three channels, which leaves .x20, .x45, .x70 and .x95 unassigned.
    private static let valid833Endings: Set<Int> = [
        0, 5, 10, 15, 25, 30, 35, 40, 50, 55, 60, 65, 75, 80, 85, 90
    ]

    func contains(_ megahertz: Double) -> Bool {
        guard Self.band.contains(megahertz) else { return false }
        let kHz = Int((megahertz * 1000).rounded())
        switch self {
        case .khz25: return kHz % 25 == 0
        case .khz833: return Self.valid833Endings.contains(kHz % 100)
        }
    }

    var label: String {
        switch self {
        case .khz25: return "25"
        case .khz833: return "8.33"
        }
    }

    var other: VHFChannelGrid {
        self == .khz25 ? .khz833 : .khz25
    }

    static func inBand(_ megahertz: Double) -> Bool {
        band.contains(megahertz)
    }
}
