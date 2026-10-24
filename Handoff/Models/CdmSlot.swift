import Foundation

/// A-CDM milestone times for one flight, all bare "HHmm" UTC strings ("1725" for 17:25Z).
/// The backend sends `""` rather than null/absent for a milestone that hasn't happened yet.
struct CdmFlightData: Decodable, Equatable {
    var tobt = ""
    var tsat = ""
    var ttot = ""
    var ctot = ""
    var reqTobt = ""
    var asrt = ""
    /// Runway and SID the controller assigned, as "29/LANUX2C"; blank until they do.
    var depInfo = ""
    var reason = ""
    var confirmed = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tobt = try c.decodeIfPresent(String.self, forKey: .tobt) ?? ""
        tsat = try c.decodeIfPresent(String.self, forKey: .tsat) ?? ""
        ttot = try c.decodeIfPresent(String.self, forKey: .ttot) ?? ""
        ctot = try c.decodeIfPresent(String.self, forKey: .ctot) ?? ""
        reqTobt = try c.decodeIfPresent(String.self, forKey: .reqTobt) ?? ""
        asrt = try c.decodeIfPresent(String.self, forKey: .asrt) ?? ""
        depInfo = try c.decodeIfPresent(String.self, forKey: .depInfo) ?? ""
        reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
        confirmed = try c.decodeIfPresent(Bool.self, forKey: .confirmed) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case tobt, tsat, ttot, ctot, reqTobt, asrt, depInfo, reason, confirmed
    }
}

/// One flight's A-CDM record. `atot` (actual takeoff time) is the signal that the flight has
/// departed and there is nothing left to track. `cdmSts` and `atfcmStatus` are the backend's own
/// strings; they are carried through as text and deliberately not decoded into a colour, because
/// their vocabulary was never confirmed (see `CdmWindowPhase`).
struct CdmFlight: Decodable, Equatable {
    let callsign: String
    var departure: String?
    var arrival: String?
    var eobt: String?
    /// Accepted TOBT at flight level; `cdmData.tobt` can stay blank even once this is set.
    var tobt: String?
    var ctot: String?
    var atot: String?
    var cdmSts: String?
    var atfcmStatus: String?
    /// This flight's expected taxi-out time in minutes — the EXOT the backend itself works with:
    /// measured live on 2026-10-16, TTOT − TSAT equalled it for 37 of 48 flights, against 2 for the
    /// airport's `taxiTime`. It varies with the runway (EDDF 8–21 min where the airport says 15).
    /// `0` is treated as unknown.
    var taxi: Int?
    var cdmData: CdmFlightData?

    init(
        callsign: String, departure: String? = nil, arrival: String? = nil, eobt: String? = nil,
        tobt: String? = nil, ctot: String? = nil, atot: String? = nil, cdmSts: String? = nil,
        atfcmStatus: String? = nil, taxi: Int? = nil, cdmData: CdmFlightData? = nil
    ) {
        self.callsign = callsign
        self.departure = departure
        self.arrival = arrival
        self.eobt = eobt
        self.tobt = tobt
        self.ctot = ctot
        self.atot = atot
        self.cdmSts = cdmSts
        self.atfcmStatus = atfcmStatus
        self.taxi = taxi
        self.cdmData = cdmData
    }
}

/// One airport as the backend lists it. Being listed at all is what gates polling (upstream issue
/// #191): the `isCdm`/`tobtReady` flags are not part of it, because the backend tracks every filed
/// flight and a TOBT set at a flag-less airport is kept for the day a controller starts using CDM.
struct CadAirport: Decodable, Equatable {
    let icao: String
    var isCdm = false
    var tobtReady = false
    /// The airport's default taxi-out time, only the fallback for a flight without its own `taxi`.
    var taxiTime: Int?

    init(icao: String, taxiTime: Int? = nil) {
        self.icao = icao
        self.taxiTime = taxiTime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        icao = try c.decodeIfPresent(String.self, forKey: .icao) ?? ""
        isCdm = try c.decodeIfPresent(Bool.self, forKey: .isCdm) ?? false
        tobtReady = try c.decodeIfPresent(Bool.self, forKey: .tobtReady) ?? false
        // Optional twice over: a fallback nobody needs must not cost the whole airport list.
        taxiTime = try? c.decodeIfPresent(Int.self, forKey: .taxiTime)
    }

    enum CodingKeys: String, CodingKey { case icao, isCdm, tobtReady, taxiTime }
}

/// Where the pilot stands relative to the start-up window (upstream issue #165), mirroring the
/// banner on the VDGS site: before it (yellow, prepare), inside it (green, request start-up),
/// after it (red, missed). `unknown` is the grey state: nothing to anchor a window to yet.
enum CdmWindowPhase: Equatable {
    case unknown
    case before
    case open
    case missed
}

/// Everything the CDM tile renders, derived once per poll. The time-dependent parts go stale
/// between polls, so the view re-derives them every second with `at(_:)`.
struct CdmSlotDisplay: Equatable {
    /// The airport is listed, but the backend isn't tracking the flight yet (the placeholder).
    var waiting = false
    var eobt: String?
    /// The accepted T/OBT ("tobt" on the wire).
    var tobt: String?
    var tsat: String?
    var ctot: String?
    /// Expected taxi-out time in minutes: the flight's own, else the airport's.
    var exot: Int?
    /// A T/OBT the pilot asked for that the backend hasn't accepted yet.
    var requestedTobt: String?
    /// Why the flow system is holding the flight, when it is.
    var reason: String?
    var atfcmStatus: String?
    /// The backend's own compliance string ("COMPLY"), shown as text, never turned into a colour.
    var statusText: String?
    var depRunway: String?
    var sid: String?
    /// Which time the window is anchored on: "TSAT", "CTOT-EXOT" or "T/OBT"; nil when none exists
    /// (a filed EOBT or a merely requested T/OBT deliberately anchors nothing).
    var referenceLabel: String?
    /// The reference's bare "HHmm" UTC time, kept so `at(_:)` can re-derive the phase.
    var referenceHhmm: String?
    /// The backend has an ASRT (start-up requested); the window then never counts as missed.
    var asrtSet = false
    var phase: CdmWindowPhase = .unknown
    /// Minutes until the window opens (before), left in it (open) or since it closed (missed);
    /// nil while unknown, and while open with an ASRT.
    var minutes: Int?

    /// The same display with the phase and its number re-derived for `now`.
    func at(_ now: Date) -> CdmSlotDisplay {
        var copy = self
        guard let untilReference = referenceHhmm.flatMap({ CdmSlot.minutesUntilUtcHhmm($0, now: now) }) else {
            copy.phase = .unknown
            copy.minutes = nil
            return copy
        }
        (copy.phase, copy.minutes) = CdmSlot.window(minutesUntilReference: untilReference, asrtSet: asrtSet)
        return copy
    }

    /// The chip label, worded as the Android client does: "STUP T-8m", "STUP 4m left",
    /// "STUP ok", "MISS +3m", or "STUP T-?" while there is nothing to count to. The narrow layout
    /// drops the prefix ("T-8m", "4m", "MISS") so the status text beside it keeps some room.
    func chipLabel(compact: Bool) -> String {
        func withPrefix(_ text: String) -> String { compact ? text : "STUP \(text)" }
        switch phase {
        case .unknown: return withPrefix("T-?")
        case .before: return withPrefix("T-\(CdmSlot.formatMinutes(minutes ?? 0))")
        case .open:
            guard let minutes else { return withPrefix("ok") }
            return compact ? CdmSlot.formatMinutes(minutes) : "STUP \(CdmSlot.formatMinutes(minutes)) left"
        // "MISS" has to stay readable as "start-up is gone" even where the number doesn't fit.
        case .missed: return compact ? "MISS" : "MISS +\(CdmSlot.formatMinutes(minutes ?? 0))"
        }
    }

    /// The expanded footer's one-line explanation of the phase — the roomy version of the chip.
    var windowSummary: String {
        let source = referenceLabel.map { " (\($0))" } ?? ""
        switch phase {
        case .unknown: return waiting ? "waiting for flight" : "no T/OBT or TSAT yet"
        case .before: return "opens in \(CdmSlot.formatMinutes(minutes ?? 0))\(source)"
        case .open:
            guard let minutes else { return "open, start-up requested (ASRT)\(source)" }
            return "open, \(CdmSlot.formatMinutes(minutes)) left\(source)"
        case .missed: return "missed \(CdmSlot.formatMinutes(minutes ?? 0)) ago\(source) - update T/OBT, coordinate"
        }
    }

    /// The labelled rows of the expanded footer, in the site's own terms and order. A requested
    /// T/OBT shows beside the accepted one rather than replacing it.
    var detailRows: [(label: String, value: String)] {
        var rows: [(label: String, value: String)] = []
        if let eobt { rows.append(("EOBT", eobt)) }
        if let tobt { rows.append(("T/OBT", tobt)) }
        if let requestedTobt { rows.append(("T/OBT req.", requestedTobt)) }
        if let tsat { rows.append(("TSAT", tsat)) }
        if let exot { rows.append(("EXOT", "\(exot)m")) }
        if let ctot { rows.append(("CTOT", ctot)) }
        if let reason { rows.append(("Reason", reason)) }
        if let atfcmStatus { rows.append(("ATFCM", atfcmStatus)) }
        if let statusText { rows.append(("CDM status", statusText)) }
        if let departureLine { rows.append(("Departure", departureLine)) }
        return rows
    }

    /// Runway and SID as one line, or nil while the controller hasn't assigned them.
    var departureLine: String? {
        guard sid != nil || depRunway != nil else { return nil }
        return [depRunway.map { "RWY \($0)" }, sid.map { "SID \($0)" }]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

/// Pure derivation of the CDM tile from a backend record. Separate from the networking so the
/// rules can be tested without a server, and ported from the Android client (upstream issue #165)
/// so both show the same thing for the same flight — with one deliberate difference: the EXOT is
/// the flight's own taxi time, the airport's only as a fallback (see `CdmFlight.taxi`).
enum CdmSlot {
    // The VDGS site documents the start-up window as roughly -5 to +6 minutes around the
    // off-block reference time.
    private static let windowOpensMinutesBefore = 5
    private static let windowClosesMinutesAfter = 6

    /// Phase and the one number the chip shows for it, given the minutes until the reference
    /// (negative once it has passed). With an ASRT the window never counts as missed — the pilot
    /// already asked for start-up — and open then carries no number.
    static func window(minutesUntilReference minutes: Int, asrtSet: Bool) -> (CdmWindowPhase, Int?) {
        if minutes > windowOpensMinutesBefore { return (.before, minutes - windowOpensMinutesBefore) }
        if minutes >= -windowClosesMinutesAfter { return (.open, minutes + windowClosesMinutesAfter) }
        if asrtSet { return (.open, nil) }
        return (.missed, -windowClosesMinutesAfter - minutes)
    }

    /// The EXOT to use: the flight's own taxi time, else the airport's; nil when neither is a
    /// positive number of minutes.
    static func exot(flightTaxi: Int?, airportTaxiTime: Int?) -> Int? {
        if let flightTaxi, flightTaxi > 0 { return flightTaxi }
        if let airportTaxiTime, airportTaxiTime > 0 { return airportTaxiTime }
        return nil
    }

    /// Nil only when there is no flight, or it has no milestone time and no filed EOBT at all.
    ///
    /// The start-up window is anchored on the site's own off-block order: TSAT, then CTOT minus
    /// the EXOT, then the accepted T/OBT. A filed EOBT and a merely requested T/OBT anchor nothing:
    /// the chip stays grey until something is accepted, so a pilot who just hasn't set a T/OBT
    /// yet doesn't see "MISS".
    static func display(for flight: CdmFlight?, airportTaxiTime: Int? = nil, now: Date) -> CdmSlotDisplay? {
        guard let flight else { return nil }
        let data = flight.cdmData ?? CdmFlightData()
        let eobt = nonBlank(hhmm(flight.eobt))
        let tobt = hhmm(data.tobt.isEmpty ? (flight.tobt ?? "") : data.tobt)
        let ctot = hhmm(data.ctot.isEmpty ? (flight.ctot ?? "") : data.ctot)
        let tsat = hhmm(data.tsat)
        let reqTobt = hhmm(data.reqTobt)
        guard [tobt, ctot, tsat, reqTobt].contains(where: { !$0.isEmpty }) || eobt != nil else { return nil }

        let depParts = data.depInfo.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let depRunway = depParts.first.map { String($0).trimmingCharacters(in: .whitespaces) }.flatMap(nonBlank)
        let sid = depParts.count > 1
            ? nonBlank(String(depParts[1]).trimmingCharacters(in: .whitespaces))
            : nil

        let exot = exot(flightTaxi: flight.taxi, airportTaxiTime: airportTaxiTime)
        let ctotMinusExot = exot.flatMap { subtractMinutesHhmm(ctot, $0) }
        let reference: (label: String, hhmm: String)?
        if !tsat.isEmpty { reference = ("TSAT", tsat) }
        else if let ctotMinusExot { reference = ("CTOT-EXOT", ctotMinusExot) }
        else if !tobt.isEmpty { reference = ("T/OBT", tobt) }
        else { reference = nil }

        return CdmSlotDisplay(
            eobt: eobt,
            tobt: nonBlank(tobt),
            tsat: nonBlank(tsat),
            ctot: nonBlank(ctot),
            exot: exot,
            requestedTobt: reqTobt != tobt ? nonBlank(reqTobt) : nil,
            reason: nonBlank(data.reason),
            atfcmStatus: flight.atfcmStatus.flatMap(nonBlank),
            statusText: flight.cdmSts.flatMap(nonBlank),
            depRunway: depRunway,
            sid: sid,
            referenceLabel: reference?.label,
            referenceHhmm: reference?.hhmm,
            asrtSet: !data.asrt.trimmingCharacters(in: .whitespaces).isEmpty
        ).at(now)
    }

    /// What one answer from the backend means for the tile. Pulled out of the polling loop so
    /// the decisions — departed, tracked, not tracked yet — can be tested without a server;
    /// that loop is where the last two reviews found their bugs.
    enum Outcome: Equatable {
        /// Already airborne: CDM tracking for this flight is over.
        case departed
        case slot(CdmSlotDisplay)
        /// The airport is listed, but this flight isn't in the system yet.
        case waiting
    }

    static func outcome(
        forFlights flights: [CdmFlight], callsign: String, airportTaxiTime: Int? = nil, now: Date
    ) -> Outcome {
        let mine = flights.first { $0.callsign.caseInsensitiveCompare(callsign) == .orderedSame }
        if let atot = mine?.atot, !atot.trimmingCharacters(in: .whitespaces).isEmpty { return .departed }
        guard let display = display(for: mine, airportTaxiTime: airportTaxiTime, now: now) else { return .waiting }
        return .slot(display)
    }

    /// The departure airport's own record, or nil when the backend doesn't list it — the one case
    /// not worth polling (upstream issue #191: its CDM flags no longer matter).
    static func listedAirport(_ airports: [CadAirport], origin: String) -> CadAirport? {
        airports.first { $0.icao.caseInsensitiveCompare(origin) == .orderedSame }
    }

    /// "Listed, but the backend isn't tracking the flight yet": a grey, time-less chip rather than
    /// nothing, so the pilot can tell "no tile here" from "nothing filed for you yet".
    static func waitingDisplay() -> CdmSlotDisplay {
        CdmSlotDisplay(waiting: true)
    }

    /// Whole minutes as the chip shows them: "8m", or "1h20m" from an hour on.
    static func formatMinutes(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h\(minutes % 60)m" : "\(minutes)m"
    }

    /// "HHmm" minus `minutes`, wrapping past midnight; nil for a blank or malformed time.
    static func subtractMinutesHhmm(_ hhmm: String, _ minutes: Int) -> String? {
        let t = hhmm.trimmingCharacters(in: .whitespaces)
        guard t.count == 4, t.allSatisfy(\.isNumber),
              let hour = Int(t.prefix(2)), let minute = Int(t.suffix(2)),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        let day = 24 * 60
        let total = ((hour * 60 + minute - minutes) % day + day) % day
        return String(format: "%02d%02d", total / 60, total % 60)
    }

    /// The backend sends the same time as "HHmm" or, once the sequencer has processed a TOBT, as
    /// "HHmmss". Normalised to "HHmm", since everything here works in whole minutes. Blank or
    /// unrecognised strings pass through unchanged.
    static func hhmm(_ raw: String?) -> String {
        let t = (raw ?? "").trimmingCharacters(in: .whitespaces)
        if t.count == 6, t.allSatisfy(\.isNumber) { return String(t.prefix(4)) }
        return t
    }

    /// Whole minutes from `now` to the nearest occurrence of a bare "HHmm" UTC time-of-day,
    /// negative once it has passed. The wire format carries no date, so "nearest of yesterday,
    /// today or tomorrow" is the intended reading: A-CDM milestones are always within hours of
    /// now, and that is what makes 23:50 → "0010" read as twenty minutes rather than a day back.
    static func minutesUntilUtcHhmm(_ hhmm: String, now: Date) -> Int? {
        let digits = hhmm.trimmingCharacters(in: .whitespaces)
        guard digits.count == 4, digits.allSatisfy(\.isNumber),
              let hour = Int(digits.prefix(2)), let minute = Int(digits.suffix(2)),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        // Whole minutes only: the wire format has no seconds, so compare against the current minute.
        let nowMinute = calendar.date(
            from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        ) ?? now

        let candidates = (-1...1).compactMap { dayOffset -> Date? in
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: nowMinute) else { return nil }
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
        }
        guard let nearest = candidates.min(by: {
            abs($0.timeIntervalSince(nowMinute)) < abs($1.timeIntervalSince(nowMinute))
        }) else { return nil }
        return Int((nearest.timeIntervalSince(nowMinute) / 60).rounded())
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }
}
