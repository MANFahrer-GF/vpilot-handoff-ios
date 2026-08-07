import Foundation

/// vPilot's compressed-integer frequency format: 123.725 MHz <-> 23725.
/// Only used for fields the plugin sends on the wire (`radioState`, `controllers`);
/// outgoing `setComXFrequency` commands take plain decimal MHz instead (see protocol.md).
enum VHFFrequency {
    static func decode(compressed: Int) -> Double {
        Double(compressed + 100_000) / 1000.0
    }

    static func encode(mhz: Double) -> Int {
        Int((mhz * 1000).rounded()) - 100_000
    }
}
