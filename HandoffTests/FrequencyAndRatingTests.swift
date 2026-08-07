import Testing
import Foundation
@testable import Handoff

struct FrequencyTests {
    @Test func decodesCompressedIntegerToMegahertz() {
        #expect(VHFFrequency.decode(compressed: 23725) == 123.725)
        #expect(VHFFrequency.decode(compressed: 19400) == 119.400)
        #expect(VHFFrequency.decode(compressed: 36990) == 136.990)
    }

    @Test func encodesMegahertzToCompressedInteger() {
        #expect(VHFFrequency.encode(mhz: 123.725) == 23725)
        #expect(VHFFrequency.encode(mhz: 118.0) == 18000)
    }

    @Test func roundTripsEveryChannelInTheBand() {
        // 8.33 kHz channels land on 3-decimal values; walking the whole band catches
        // any rounding drift the Double maths might introduce at the edges.
        for compressed in stride(from: 18000, through: 36990, by: 5) {
            let mhz = VHFFrequency.decode(compressed: compressed)
            #expect(VHFFrequency.encode(mhz: mhz) == compressed)
        }
    }

    @Test func formatsWithThreeDecimals() {
        let controller = Controller.preview(callsign: "EDDF_TWR", frequency: 19400, facility: 4)
        #expect(controller.frequencyMHzText == "119.400")
    }
}

struct RatingLabelTests {
    private func controller(rating: Int?, callsign: String = "EDDF_TWR") -> Controller {
        let json = """
        {"callsign":"\(callsign)","frequency":19400,
         "rating":\(rating.map(String.init) ?? "null")}
        """
        return try! JSONDecoder().decode(Controller.self, from: Data(json.utf8))
    }

    @Test func mapsVatsimRatingsToTheirBadges() {
        #expect(controller(rating: 2).ratingLabel == "S1")
        #expect(controller(rating: 3).ratingLabel == "S2")
        #expect(controller(rating: 4).ratingLabel == "S3")
        #expect(controller(rating: 5).ratingLabel == "C1")
        #expect(controller(rating: 11).ratingLabel == "SUP")
        #expect(controller(rating: 12).ratingLabel == "ADM")
    }

    @Test func hasNoBadgeWhileTheFeedEnrichmentIsStillPending() {
        // cid/name/facility/rating are null until the ~15s-lagged VATSIM feed
        // solidifies for a callsign -- the row must not invent a badge meanwhile.
        #expect(controller(rating: nil).ratingLabel == nil)
    }

    @Test func atisStationsShowAtisInsteadOfARating() {
        #expect(controller(rating: nil, callsign: "EDDF_ATIS").ratingLabel == "ATIS")
        #expect(controller(rating: 5, callsign: "LOWW_D_ATIS").ratingLabel == "ATIS")
    }

    @Test func fallsBackToCallsignSuffixWhenFacilityIsUnknown() {
        let unknown = Controller.preview(callsign: "EDDF_APRON", frequency: 19400, facility: nil)
        #expect(unknown.facilityLabel == "APRON")
    }

    @Test func mapsKnownFacilityCodes() {
        #expect(Controller.preview(callsign: "X_DEL", frequency: 1, facility: 2).facilityLabel == "DEL")
        #expect(Controller.preview(callsign: "X_GND", frequency: 1, facility: 3).facilityLabel == "GND")
        #expect(Controller.preview(callsign: "X_TWR", frequency: 1, facility: 4).facilityLabel == "TWR")
        #expect(Controller.preview(callsign: "X_APP", frequency: 1, facility: 5).facilityLabel == "APP/DEP")
        #expect(Controller.preview(callsign: "X_CTR", frequency: 1, facility: 6).facilityLabel == "CTR")
    }
}

struct FlightPlanWarningTests {
    private func plan(_ json: String) -> FlightPlanMessage {
        try! JSONDecoder().decode(FlightPlanMessage.self, from: Data(json.utf8))
    }

    @Test func flagsConnectedPilotWithNoFiledPlan() {
        let message = plan(#"{"vatsimCallsign":"BAW123","vatsimOrigin":null,"vatsimDestination":null}"#)
        #expect(message.vatsimPlanMissing)
        #expect(message.hasAnyWarning)
    }

    @Test func doesNotFlagMissingPlanBeforeConnecting() {
        let message = plan(#"{"vatsimCallsign":null}"#)
        #expect(!message.vatsimPlanMissing)
        #expect(!message.hasAnyWarning)
    }

    @Test func flagsSimbriefVatsimDivergence() {
        let message = plan(
            """
            {"simbriefOrigin":"EGLL","simbriefDestination":"KJFK",
             "vatsimCallsign":"BAW123","vatsimOrigin":"EGLL","vatsimDestination":"KBOS"}
            """
        )
        #expect(message.simbriefVatsimMismatch)
    }

    @Test func agreeingPlansRaiseNoWarning() {
        let message = plan(
            """
            {"simbriefOrigin":"EGLL","simbriefDestination":"KJFK",
             "vatsimCallsign":"BAW123","vatsimOrigin":"EGLL","vatsimDestination":"KJFK",
             "originMismatch":false,"vatsimCidMismatch":false}
            """
        )
        #expect(!message.hasAnyWarning)
    }

    @Test func originMismatchAloneIsAWarning() {
        // Both sides can confidently agree on the wrong airport -- this is the
        // plugin's separate on-ground sanity gate, not a SimBrief/VATSIM disagreement.
        let message = plan(
            """
            {"simbriefOrigin":"EGLL","simbriefDestination":"KJFK",
             "vatsimCallsign":"BAW123","vatsimOrigin":"EGLL","vatsimDestination":"KJFK",
             "originMismatch":true}
            """
        )
        #expect(!message.simbriefVatsimMismatch)
        #expect(message.hasAnyWarning)
    }
}
