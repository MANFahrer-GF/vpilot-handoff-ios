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
        asrt: String = "", depInfo: String = "", eobt: String? = nil, status: String? = nil,
        taxi: Int? = nil
    ) -> CdmFlight {
        var data = CdmFlightData()
        data.tobt = tobt; data.tsat = tsat; data.ctot = ctot
        data.reqTobt = reqTobt; data.asrt = asrt; data.depInfo = depInfo
        var result = CdmFlight(callsign: "EIDGX", departure: "LEBL", eobt: eobt)
        result.cdmSts = status
        result.taxi = taxi
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

    /// The window is anchored the way the VDGS site's banner does it (upstream issue #165): TSAT,
    /// else CTOT minus the EXOT, else the accepted T/OBT. This replaces the earlier "CTOT outranks
    /// everything" rule on purpose — that one counted to takeoff while the banner is about start-up.
    @Test func theReferenceFollowsTheSitesOffBlockOrder() {
        let all = flight(tobt: "1800", tsat: "1810", ctot: "1825", status: "COMPLY", taxi: 12)
        let display = CdmSlot.display(for: all, now: utc(18, 0))
        #expect(display?.referenceLabel == "TSAT")
        #expect(display?.referenceHhmm == "1810")
        #expect(display?.statusText == "COMPLY")

        let ctotOnly = CdmSlot.display(for: flight(tobt: "1800", ctot: "1825", taxi: 12), now: utc(17, 0))
        #expect(ctotOnly?.referenceLabel == "CTOT-EXOT")
        #expect(ctotOnly?.referenceHhmm == "1813")
        #expect(CdmSlot.display(for: flight(tobt: "1800"), now: utc(16, 0))?.referenceLabel == "T/OBT")
    }

    /// Without any taxi time a CTOT cannot be turned into an off-block time, so the accepted
    /// T/OBT anchors instead — and with neither, nothing does.
    @Test func aCtotWithoutTaxiTimeFallsThroughToTheTobt() {
        let display = CdmSlot.display(for: flight(tobt: "1800", ctot: "1825"), now: utc(17, 0))
        #expect(display?.referenceLabel == "T/OBT")
        let ctotAlone = CdmSlot.display(for: flight(ctot: "1825"), now: utc(17, 0))
        #expect(ctotAlone?.referenceLabel == nil)
        #expect(ctotAlone?.phase == .unknown)
    }

    /// The deliberate difference to Android: the flight's own taxi time is the EXOT, because that
    /// is what the backend computes TTOT with (measured 2026-10-16). The airport's is the fallback.
    @Test func theFlightsOwnTaxiTimeWinsOverTheAirports() {
        let own = CdmSlot.display(for: flight(ctot: "1825", taxi: 9), airportTaxiTime: 15, now: utc(17, 0))
        #expect(own?.exot == 9)
        #expect(own?.referenceHhmm == "1816")

        let fallback = CdmSlot.display(for: flight(ctot: "1825"), airportTaxiTime: 15, now: utc(17, 0))
        #expect(fallback?.exot == 15)
        #expect(fallback?.referenceHhmm == "1810")

        // The backend sends 0 for "unknown"; it must not turn a CTOT into the off-block time.
        let zero = CdmSlot.display(for: flight(ctot: "1825", taxi: 0), airportTaxiTime: 15, now: utc(17, 0))
        #expect(zero?.exot == 15)
        #expect(CdmSlot.exot(flightTaxi: 0, airportTaxiTime: 0) == nil)
        #expect(CdmSlot.exot(flightTaxi: nil, airportTaxiTime: nil) == nil)
    }

    /// The start-up window runs from 5 minutes before the reference to 6 after it: yellow before,
    /// green inside, red after, each with the one number the chip shows.
    @Test func theStartUpWindowRunsFromMinusFiveToPlusSix() {
        func at(_ hour: Int, _ minute: Int) -> CdmSlotDisplay? {
            CdmSlot.display(for: flight(tobt: "1810"), now: utc(hour, minute))
        }
        #expect(at(17, 54)?.phase == .before)       // 16 min out
        #expect(at(17, 54)?.minutes == 11)           // opens in 11
        #expect(at(18, 4)?.phase == .before)        // 6 min out
        #expect(at(18, 5)?.phase == .open)          // opens at reference -5
        #expect(at(18, 5)?.minutes == 11)            // 11 min left in it
        #expect(at(18, 16)?.phase == .open)         // last minute, reference +6
        #expect(at(18, 16)?.minutes == 0)
        #expect(at(18, 17)?.phase == .missed)       // closed
        #expect(at(18, 17)?.minutes == 1)
    }

    /// With a start-up request filed the window never counts as missed.
    @Test func anAsrtKeepsTheWindowFromExpiring() {
        let withAsrt = CdmSlot.display(for: flight(tobt: "1810", asrt: "1808"), now: utc(18, 30))
        #expect(withAsrt?.phase == .open)
        #expect(withAsrt?.minutes == nil)
        #expect(withAsrt?.chipLabel(compact: false) == "STUP ok")
        #expect(withAsrt?.windowSummary == "open, start-up requested (ASRT) (T/OBT)")
    }

    /// A requested-but-unaccepted T/OBT and a bare filed EOBT are shown, but anchor nothing: the
    /// chip stays grey, so a pilot who hasn't set a T/OBT yet never sees a false MISS.
    @Test func requestedAndFiledTimesAnchorNothing() {
        let requested = CdmSlot.display(for: flight(reqTobt: "1750"), now: utc(19, 0))
        #expect(requested?.phase == .unknown)
        #expect(requested?.chipLabel(compact: false) == "STUP T-?")
        #expect(requested?.requestedTobt == "1750")

        let filed = CdmSlot.display(for: flight(eobt: "1800"), now: utc(19, 0))
        #expect(filed?.phase == .unknown)
        #expect(filed?.eobt == "1800")
        #expect(filed?.windowSummary == "no T/OBT or TSAT yet")

        // A request the backend already accepted is not shown twice.
        #expect(CdmSlot.display(for: flight(tobt: "1800", reqTobt: "1800"), now: utc(17, 0))?.requestedTobt == nil)
    }

    @Test func theChipCountsTheWayAndroidWordsIt() {
        func chip(_ hour: Int, _ minute: Int, tobt: String = "1810", compact: Bool = false) -> String? {
            CdmSlot.display(for: flight(tobt: tobt), now: utc(hour, minute))?.chipLabel(compact: compact)
        }
        #expect(chip(17, 57) == "STUP T-8m")
        #expect(chip(18, 12) == "STUP 4m left")
        #expect(chip(18, 19) == "MISS +3m")
        #expect(chip(18, 0, tobt: "1930") == "STUP T-1h25m")
        // The narrow footer drops the prefix; MISS keeps its word even without the number.
        #expect(chip(17, 57, compact: true) == "T-8m")
        #expect(chip(18, 12, compact: true) == "4m")
        #expect(chip(18, 19, compact: true) == "MISS")
        #expect(CdmSlot.display(for: flight(tobt: "1810"), now: utc(18, 19))?.windowSummary
            == "missed 3m ago (T/OBT) - update T/OBT, coordinate")
    }

    @Test func runwayAndSidAreSplitOutOfTheBackendsOneField() {
        let display = CdmSlot.display(for: flight(tobt: "1810", depInfo: "29/LANUX2C"), now: utc(18, 0))
        #expect(display?.depRunway == "29")
        #expect(display?.sid == "LANUX2C")
        #expect(display?.departureLine == "RWY 29 · SID LANUX2C")
    }

    /// The drawer lists the site's own terms, in its order, and only what the backend has.
    @Test func theDrawerUsesTheSitesTerms() {
        var full = flight(
            tobt: "1800", tsat: "1805", ctot: "1825", reqTobt: "1810", depInfo: "25C/OBOKA1G",
            eobt: "1750", status: "COMPLY", taxi: 12
        )
        full.atfcmStatus = "ATC_ACTIV"
        full.cdmData?.reason = "WEATHER"
        let labels = CdmSlot.display(for: full, now: utc(17, 0))?.detailRows.map(\.label)
        #expect(labels == [
            "EOBT", "T/OBT", "T/OBT req.", "TSAT", "EXOT", "CTOT", "Reason", "ATFCM", "CDM status", "Departure"
        ])
        #expect(CdmSlot.display(for: flight(tobt: "1800"), now: utc(17, 0))?.detailRows.map(\.label) == ["T/OBT"])
    }

    @Test func subtractingMinutesWrapsPastMidnight() {
        #expect(CdmSlot.subtractMinutesHhmm("1825", 12) == "1813")
        #expect(CdmSlot.subtractMinutesHhmm("0005", 12) == "2353")
        #expect(CdmSlot.subtractMinutesHhmm("", 12) == nil)
        #expect(CdmSlot.subtractMinutesHhmm("2460", 12) == nil)
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
            #expect(display.referenceLabel == "T/OBT")
        } else {
            Issue.record("own flight was not matched")
        }
    }

    /// The gate that runs before any flight list is ever requested (upstream issue #191): an
    /// airport only has to be listed. Its CDM flags no longer matter — the backend tracks every
    /// filed flight there, and a TOBT set early is kept for the day CDM goes live.
    @Test func anyListedAirportIsWorthAsking() throws {
        let json = """
            [{"icao":"LEBL","isCdm":true,"tobtReady":true,"taxiTime":15},
             {"icao":"EINN","isCdm":false,"tobtReady":false,"taxiTime":10},
             {"icao":"GCRR","isCdm":false}]
            """
        let list = try JSONDecoder().decode([CadAirport].self, from: Data(json.utf8))
        #expect(CdmSlot.listedAirport(list, origin: "LEBL")?.taxiTime == 15)
        #expect(CdmSlot.listedAirport(list, origin: "einn")?.taxiTime == 10)
        #expect(CdmSlot.listedAirport(list, origin: "GCRR") != nil)
        #expect(CdmSlot.listedAirport(list, origin: "GCRR")?.taxiTime == nil)
        #expect(CdmSlot.listedAirport(list, origin: "EDDF") == nil)
        #expect(CdmSlot.listedAirport([], origin: "LEBL") == nil)
    }

    /// The per-flight fields the tile now reads, decoded from the backend's own shape.
    @Test func theFlightRecordCarriesTaxiAndAtfcm() throws {
        let json = """
            [{"callsign":"DLH1DB","departure":"EDDF","eobt":"1945","taxi":12,"atfcmStatus":"ATC_ACTIV",
              "cdmData":{"tobt":"195500","tsat":"195500","ttot":"200700","asrt":"1952","depInfo":"25C/OBOKA1G"}}]
            """
        let flights = try JSONDecoder().decode([CdmFlight].self, from: Data(json.utf8))
        #expect(flights.first?.taxi == 12)
        #expect(flights.first?.atfcmStatus == "ATC_ACTIV")
        let display = CdmSlot.display(for: flights.first, now: utc(19, 50))
        #expect(display?.exot == 12)
        #expect(display?.asrtSet == true)
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
        #expect(display?.referenceHhmm == "1815")
        #expect(display?.minutes == 10)
    }

    /// The placeholder for "listed airport, but your flight isn't in the system yet" — a grey,
    /// time-less chip, so that reads differently from no tile at all.
    @Test func theWaitingPlaceholderShowsNoTimeAndNoColour() {
        let waiting = CdmSlot.waitingDisplay()
        #expect(waiting.phase == .unknown)
        #expect(waiting.chipLabel(compact: false) == "STUP T-?")
        #expect(waiting.chipLabel(compact: true) == "T-?")
        #expect(waiting.windowSummary == "waiting for flight")
        #expect(waiting.at(utc(12, 0)) == waiting)
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
