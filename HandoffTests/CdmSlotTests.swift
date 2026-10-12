import Testing
import Foundation
@testable import Handoff

/// The departure-slot tile (upstream issue #143). The rules are ported from the Android client
/// so both show the same thing for the same flight, which is exactly why they are pinned here:
/// a quiet divergence would mean two of the pilot's own devices disagreeing about whether a
/// start-up window is still open.
struct CdmSlotTests {
    private func utc(_ hour: Int, _ minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026; components.month = 10; components.day = 12
        components.hour = hour; components.minute = minute
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: components)!
    }

    private func flight(
        tobt: String = "", tsat: String = "", ctot: String = "", reqTobt: String = "",
        asrt: String = "", depInfo: String = "", eobt: String? = nil, status: String? = nil
    ) -> CdmFlight {
        var data = CdmFlightData()
        data.tobt = tobt; data.tsat = tsat; data.ctot = ctot
        data.reqTobt = reqTobt; data.asrt = asrt; data.depInfo = depInfo
        var result = CdmFlight(callsign: "EIDGX", departure: "LEBL", eobt: eobt)
        result.cdmSts = status
        result.cdmData = data
        return result
    }

    @Test func countsMinutesForwardAndBackAcrossMidnight() {
        #expect(CdmSlot.minutesUntilUtcHhmm("1730", now: utc(17, 0)) == 30)
        #expect(CdmSlot.minutesUntilUtcHhmm("1700", now: utc(17, 30)) == -30)
        // The wire format carries no date, so the nearest occurrence is the intended one.
        #expect(CdmSlot.minutesUntilUtcHhmm("0010", now: utc(23, 50)) == 20)
        #expect(CdmSlot.minutesUntilUtcHhmm("2350", now: utc(0, 10)) == -20)
    }

    @Test func rejectsTimesThatAreNotFourDigitsOfClock() {
        #expect(CdmSlot.minutesUntilUtcHhmm("", now: utc(12, 0)) == nil)
        #expect(CdmSlot.minutesUntilUtcHhmm("25:00", now: utc(12, 0)) == nil)
        #expect(CdmSlot.minutesUntilUtcHhmm("173", now: utc(12, 0)) == nil)
        #expect(CdmSlot.minutesUntilUtcHhmm("2560", now: utc(12, 0)) == nil)
        // The sequencer sends seconds once it has processed a TOBT.
        #expect(CdmSlot.hhmm("181500") == "1815")
        #expect(CdmSlot.hhmm("1815") == "1815")
    }

    /// No milestone and no filed EOBT means there is nothing to show — an empty tile would only
    /// claim the backend knows something about this flight when it doesn't.
    @Test func noTimesMeansNoTile() {
        #expect(CdmSlot.display(for: nil, now: utc(12, 0)) == nil)
        #expect(CdmSlot.display(for: CdmFlight(callsign: "EIDGX"), now: utc(12, 0)) == nil)
        #expect(CdmSlot.display(for: flight(), now: utc(12, 0)) == nil)
    }

    /// The latest milestone the backend assigned wins: CTOT over TSAT over TOBT.
    @Test func theMostActionableMilestoneIsTheTarget() {
        let all = flight(tobt: "1800", tsat: "1810", ctot: "1825", status: "COMPLY")
        let display = CdmSlot.display(for: all, now: utc(18, 0))
        #expect(display?.targetLabel == "CTOT")
        #expect(display?.minutesUntil == 25)
        #expect(display?.statusText == "COMPLY")
        #expect(CdmSlot.display(for: flight(tobt: "1800", tsat: "1810"), now: utc(17, 0))?.targetLabel == "TSAT")
        #expect(CdmSlot.display(for: flight(tobt: "1800"), now: utc(16, 0))?.targetLabel == "TOBT")
    }

    /// An accepted TOBT follows the CDM plugin's ±5 minute window, not a simple countdown.
    @Test func anAcceptedTobtFollowsTheStartUpWindow() {
        func urgency(at hour: Int, _ minute: Int) -> CdmUrgency? {
            CdmSlot.display(for: flight(tobt: "1810"), now: utc(hour, minute))?.urgency
        }
        #expect(urgency(at: 17, 54) == .attention)  // 16 min out, before the window
        #expect(urgency(at: 18, 4) == .attention)   // 6 min out, still before it
        #expect(urgency(at: 18, 5) == .good)        // window opens at TOBT-5
        #expect(urgency(at: 18, 13) == .good)       // TOBT+3
        #expect(urgency(at: 18, 14) == .flashing)   // running out
        #expect(urgency(at: 18, 15) == .flashing)   // last minute, TOBT+5
        #expect(urgency(at: 18, 16) == .urgent)     // expired
    }

    /// With a start-up request filed the window never expires — the same condition the CDM
    /// plugin itself uses before invalidating a time.
    @Test func anAsrtKeepsTheWindowFromExpiring() {
        let withAsrt = flight(tobt: "1810", asrt: "1808")
        #expect(CdmSlot.display(for: withAsrt, now: utc(18, 20))?.urgency == .good)
    }

    /// A CTOT keeps the simple thresholds, since its colour mapping was never confirmed.
    @Test func aCtotUsesPlainThresholds() {
        let slot = flight(ctot: "1730")
        #expect(CdmSlot.display(for: slot, now: utc(17, 0))?.urgency == .good)
        #expect(CdmSlot.display(for: slot, now: utc(17, 20))?.urgency == .attention)
        #expect(CdmSlot.display(for: slot, now: utc(17, 27))?.urgency == .urgent)
    }

    /// A requested-but-unaccepted TOBT and a bare filed EOBT are shown, but marked: the tile
    /// says the system is tracking the flight without claiming a time was granted.
    @Test func requestedAndFiledTimesAreMarkedTentative() {
        let requested = CdmSlot.display(for: flight(reqTobt: "1750"), now: utc(17, 0))
        #expect(requested?.targetLabel == "TOBT?")
        #expect(requested?.tentative == true)
        #expect(requested?.urgency == .neutral)

        let filed = CdmSlot.display(for: flight(eobt: "1800"), now: utc(17, 0))
        #expect(filed?.targetLabel == "EOBT?")
        #expect(filed?.tentative == true)
    }

    @Test func runwayAndSidAreSplitOutOfTheBackendsOneField() {
        let display = CdmSlot.display(for: flight(tobt: "1810", depInfo: "29/LANUX2C"), now: utc(18, 0))
        #expect(display?.depRunway == "29")
        #expect(display?.sid == "LANUX2C")
        #expect(display?.departureLine == "RWY 29 · SID LANUX2C")
        #expect(display?.chipLabel == "TOBT T-10m")

        // Past the target the chip counts up instead, so an overdue slot reads as overdue.
        let overdue = CdmSlot.display(for: flight(tobt: "1810"), now: utc(18, 25))
        #expect(overdue?.chipLabel == "TOBT +15m")
    }

    /// What one backend answer means for the tile — the layer the polling loop acts on, and
    /// where both previous reviews found their bugs.
    @Test func oneAnswerDecidesDepartedTrackedOrWaiting() {
        var airborne = flight(tobt: "1810")
        airborne.atot = "1812"
        let mine = flight(tobt: "1810")
        let someoneElse = CdmFlight(callsign: "AUA123", eobt: "1900")

        // Airborne: tracking is over, and that must not read as "nothing filed yet".
        #expect(CdmSlot.outcome(forFlights: [airborne], callsign: "EIDGX", now: utc(18, 20)) == .departed)
        // Another aircraft's row must never become ours.
        #expect(CdmSlot.outcome(forFlights: [someoneElse], callsign: "EIDGX", now: utc(18, 0)) == .waiting)
        // How the network spells the callsign is not a reason to miss our own flight.
        if case .slot(let display) = CdmSlot.outcome(forFlights: [mine], callsign: "eidgx", now: utc(18, 0)) {
            #expect(display.targetLabel == "TOBT")
        } else {
            Issue.record("own flight was not matched")
        }
    }

    /// The gate that runs before any flight list is ever requested. "Does CDM but not
    /// TOBT-ready" still counts — live data shows pilots getting TOBTs at those airports.
    @Test func onlyCdmAirportsAreWorthAsking() throws {
        let json = """
            [{"icao":"LEBL","isCdm":true,"tobtReady":true},
             {"icao":"LEMD","isCdm":true,"tobtReady":false},
             {"icao":"EDDM","isCdm":false,"tobtReady":false}]
            """
        let list = try JSONDecoder().decode([CadAirport].self, from: Data(json.utf8))
        #expect(CdmSlot.isCdmCovered(list, origin: "LEBL"))
        #expect(CdmSlot.isCdmCovered(list, origin: "lemd"))
        #expect(CdmSlot.isCdmCovered(list, origin: "EDDM") == false)
        #expect(CdmSlot.isCdmCovered(list, origin: "EDDF") == false)
        #expect(CdmSlot.isCdmCovered([], origin: "LEBL") == false)
    }

    /// Sub-resources must pass: the bot check in front of the site loads frames and scripts from
    /// hosts nobody listed, and gating those would break the page this exists to show. What the
    /// privacy policy actually promises is fenced in is whole-page navigation — including a new
    /// window, which arrives with no frame at all.
    @Test func onlyWholePageNavigationIsFenced() {
        let site = URL(string: "https://vdgs.vatsimspain.es/vdgs/index.php")
        let elsewhere = URL(string: "https://example.com/")
        #expect(vdgsNavigationAllowed(url: site, isMainFrame: true))
        #expect(vdgsNavigationAllowed(url: elsewhere, isMainFrame: true) == false)
        #expect(vdgsNavigationAllowed(url: elsewhere, isMainFrame: nil) == false)
        #expect(vdgsNavigationAllowed(url: elsewhere, isMainFrame: false))
    }

    /// The sequencer sends seconds once it has processed a TOBT; the tile works in minutes.
    @Test func sixDigitTimesFromTheSequencerAreAccepted() {
        let display = CdmSlot.display(for: flight(tobt: "181500"), now: utc(18, 0))
        #expect(display?.tobt == "1815")
        #expect(display?.minutesUntil == 15)
    }

    /// The placeholder for "this airport does CDM, but your flight isn't in the system yet" — a
    /// grey, time-less chip, so that reads differently from no CDM coverage at all.
    @Test func theWaitingPlaceholderShowsNoTimeAndNoColour() {
        let waiting = CdmSlot.waitingDisplay()
        #expect(waiting.urgency == .neutral)
        #expect(waiting.chipLabel == "TOBT –")
        #expect(waiting.detailLine == "waiting for flight")
    }

    /// Only https on the site, VATSIM's login and the bot check in front of them -- a stray link
    /// must not be able to take a JavaScript-enabled web view somewhere else.
    @Test func theEmbeddedSiteOnlyFollowsItsOwnHosts() {
        #expect(isAllowedVdgsNavigation(URL(string: "https://vdgs.vatsimspain.es/vdgs/index.php")))
        #expect(isAllowedVdgsNavigation(URL(string: "https://auth.vatsim.net/oauth/authorize")))
        // The bot check in front of both is on the list for a reason: without it the site is
        // unreachable, which looks like a broken feature rather than a blocked host.
        #expect(isAllowedVdgsNavigation(URL(string: "https://challenges.cloudflare.com/turnstile")))
        #expect(isAllowedVdgsNavigation(URL(string: "http://vdgs.vatsimspain.es/")) == false)
        #expect(isAllowedVdgsNavigation(URL(string: "https://vatsimspain.es.evil.example/")) == false)
        #expect(isAllowedVdgsNavigation(URL(string: "https://example.com/")) == false)
        #expect(isAllowedVdgsNavigation(nil) == false)
    }
}
