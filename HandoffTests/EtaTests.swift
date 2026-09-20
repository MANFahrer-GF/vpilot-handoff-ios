import Testing
import Foundation
@testable import Handoff

/// Plugin v0.6.0 (upstream issue #127) moved the ETA from the `controllers` message
/// onto each controller. Two things about that are easy to get wrong in ways nothing
/// on screen would reveal: the raw value drifts every second, and the old header
/// figure must not linger next to the new row badges.
@MainActor
struct EtaTests {
    private func store() -> AppStore {
        TestDefaults.installOnce()
        return AppStore()
    }

    private func controllers(_ json: String) throws -> [Controller] {
        try JSONDecoder().decode(ControllersMessage.self, from: Data(json.utf8)).controllers
    }

    /// The store skips re-assigning an unchanged list so the ~1x/s resend doesn't
    /// re-render every row. The raw ETA is a distance over a groundspeed, so it moves
    /// a little on every tick: left raw, it would defeat that diff for the whole
    /// approach. Rounding at decode time is what keeps the two payloads equal.
    @Test func subMinuteEtaDriftDoesNotCountAsAListChange() throws {
        let first = try controllers("""
            {"type":"controllers","controllers":[{"callsign":"EDMM_CTR","frequency":19400,"etaMinutes":14.1}]}
            """)
        let second = try controllers("""
            {"type":"controllers","controllers":[{"callsign":"EDMM_CTR","frequency":19400,"etaMinutes":14.4}]}
            """)
        #expect(first == second)

        // A genuine minute change still has to come through, or the badge would freeze.
        let later = try controllers("""
            {"type":"controllers","controllers":[{"callsign":"EDMM_CTR","frequency":19400,"etaMinutes":12.9}]}
            """)
        #expect(first != later)
        #expect(later[0].etaBadgeText == "ETA 13′")
    }

    /// The plugin only sends an ETA for a sector still being approached, so a value
    /// under a minute means "nearly there", not "arrived" -- "ETA 0′" would read like
    /// the bug upstream just fixed. A negative one means the opposite (already past),
    /// and must not turn into an imminent arrival.
    @Test func underAMinuteReadsAsLessThanOneRatherThanZero() throws {
        let rows = try controllers("""
            {"type":"controllers","controllers":[
              {"callsign":"EDMM_CTR","frequency":19400,"etaMinutes":0.3},
              {"callsign":"EDDM_TWR","frequency":19410,"etaMinutes":-2},
              {"callsign":"EDDM_APP","frequency":19420}]}
            """)
        #expect(rows[0].etaBadgeText == "ETA <1′")
        #expect(rows[1].etaMinutes == nil)
        #expect(rows[1].etaBadgeText == nil)
        #expect(rows[2].etaBadgeText == nil)
    }

    /// Both directions of the fallback: an old plugin's list-level ETA still shows in
    /// the header, and it steps aside as soon as any row carries its own.
    @Test func headerEtaOnlyShowsWhileNoRowCarriesOne() throws {
        let store = self.store()
        store.etaMinutes = 12
        store.controllers = try controllers("""
            {"type":"controllers","controllers":[{"callsign":"EDDF_TWR","frequency":19400}]}
            """)
        #expect(store.listLevelEtaText == "ETA 12′")

        store.controllers = try controllers("""
            {"type":"controllers","controllers":[{"callsign":"EDMM_CTR","frequency":19400,"etaMinutes":7}]}
            """)
        #expect(store.listLevelEtaText == nil)
    }
}
