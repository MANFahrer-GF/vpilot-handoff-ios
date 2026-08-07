import Testing
import Foundation
@testable import Handoff

/// The spacing toggle originally changed a label and nothing else, and the first
/// attempt at a real rule accepted every 5 kHz step. Both slipped through because
/// the logic sat in a view where nothing could check it.
struct ChannelGridTests {
    @Test func twentyFiveKilohertzAcceptsOnlyQuarterSteps() {
        #expect(VHFChannelGrid.khz25.contains(122.800))
        #expect(VHFChannelGrid.khz25.contains(119.475))
        #expect(!VHFChannelGrid.khz25.contains(122.805))
        #expect(!VHFChannelGrid.khz25.contains(122.830))
    }

    @Test func eightThirtyThreeAcceptsItsAssignedChannels() {
        for ending in [0, 5, 10, 15, 25, 30, 35, 40, 50, 55, 60, 65, 75, 80, 85, 90] {
            let mhz = 122.0 + Double(ending) / 1000
            #expect(VHFChannelGrid.khz833.contains(mhz), "122.\(String(format: "%03d", ending)) should be valid")
        }
    }

    @Test func eightThirtyThreeRejectsTheUnassignedEndings() {
        // The gap this exists for: .x20/.x45/.x70/.x95 are not channel names, even
        // though a naive "every 5 kHz" rule would wave them through.
        for ending in [20, 45, 70, 95] {
            let mhz = 122.0 + Double(ending) / 1000
            #expect(!VHFChannelGrid.khz833.contains(mhz), "122.\(ending) should be rejected")
        }
    }

    @Test func everyTwentyFiveChannelIsAlsoAnEightThirtyThreeChannel() {
        // Real avionics accept the old 25 kHz names on an 8.33-capable radio, so the
        // narrower grid must be a superset of the wider one.
        for kHz in stride(from: 118_000, through: 136_975, by: 25) {
            let mhz = Double(kHz) / 1000
            #expect(VHFChannelGrid.khz833.contains(mhz), "\(mhz) valid on 25 but not on 8.33")
        }
    }

    @Test func bandLimitsAreEnforcedOnBothGrids() {
        #expect(!VHFChannelGrid.khz25.contains(117.975))
        #expect(!VHFChannelGrid.khz833.contains(117.975))
        #expect(!VHFChannelGrid.khz25.contains(137.000))
        #expect(!VHFChannelGrid.khz833.contains(137.000))
        #expect(VHFChannelGrid.khz25.contains(118.000))
        #expect(VHFChannelGrid.khz833.contains(136.990))
    }

    @Test func inBandIgnoresTheGrid() {
        // "Allow all" relaxes the grid but never the band -- the plugin drops
        // out-of-band values silently, so letting them through helps nobody.
        #expect(VHFChannelGrid.inBand(122.806))
        #expect(!VHFChannelGrid.inBand(140.000))
    }

    @Test func toggleGoesBothWays() {
        #expect(VHFChannelGrid.khz25.other == .khz833)
        #expect(VHFChannelGrid.khz833.other == .khz25)
        #expect(VHFChannelGrid.khz25.label == "25")
        #expect(VHFChannelGrid.khz833.label == "8.33")
    }
}
