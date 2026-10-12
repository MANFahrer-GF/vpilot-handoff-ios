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
/// departed and there is nothing left to track. `cdmSts` is the backend's own network-wide
/// compliance string; it is carried through as text and deliberately not decoded into a colour,
/// because its vocabulary was never confirmed (see `CdmUrgency`).
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
    var cdmData: CdmFlightData?

    init(
        callsign: String, departure: String? = nil, arrival: String? = nil, eobt: String? = nil,
        tobt: String? = nil, ctot: String? = nil, atot: String? = nil, cdmSts: String? = nil,
        cdmData: CdmFlightData? = nil
    ) {
        self.callsign = callsign
        self.departure = departure
        self.arrival = arrival
        self.eobt = eobt
        self.tobt = tobt
        self.ctot = ctot
        self.atot = atot
        self.cdmSts = cdmSts
        self.cdmData = cdmData
    }
}

/// One airport's CDM capability, which is what gates polling at all: a departure airport outside
/// the CDM network would otherwise mean a permanently empty tile and pointless traffic.
struct CadAirport: Decodable, Equatable {
    let icao: String
    var isCdm = false
    var tobtReady = false

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        icao = try c.decodeIfPresent(String.self, forKey: .icao) ?? ""
        isCdm = try c.decodeIfPresent(Bool.self, forKey: .isCdm) ?? false
        tobtReady = try c.decodeIfPresent(Bool.self, forKey: .tobtReady) ?? false
    }

    enum CodingKeys: String, CodingKey { case icao, isCdm, tobtReady }
}

/// Coarse urgency for the tile's traffic-light dot, derived purely from the time to the target —
/// *not* a decode of the backend's own `cdmSts` string, whose vocabulary was never confirmed.
/// `CdmSlotDisplay.statusText` carries that raw string instead, so nothing is hidden.
enum CdmUrgency: Equatable {
    case neutral
    case good
    case attention
    case urgent
    /// The last minutes of a TOBT/TSAT window: alternates between good and attention.
    case flashing
}

/// Everything the CDM tile renders, derived once per poll. The time-dependent parts go stale
/// between polls, so the view re-derives them every second with `at(_:)`.
struct CdmSlotDisplay: Equatable {
    var statusText: String?
    var tobt: String?
    var tsat: String?
    var ctot: String?
    /// A TOBT the pilot asked for that the backend hasn't accepted yet.
    var requestedTobt: String?
    /// Filed EOBT — only ever the target as a last resort, before any TOBT exists.
    var eobt: String?
    /// Why the flow system is holding the flight, when it is.
    var reason: String?
    var depRunway: String?
    var sid: String?
    var targetLabel: String?
    /// The target's bare "HHmm" UTC time, kept so `at(_:)` can re-derive the countdown.
    var targetHhmm: String?
    var minutesUntil: Int?
    /// The target is only a request or the filed EOBT, not an accepted CDM time.
    var tentative: Bool
    /// An accepted TOBT/TSAT, which follows the ±5 minute window rules.
    var windowed: Bool
    /// The backend has an ASRT (ready for start-up); the window then never expires, matching the
    /// CDM plugin's own condition for invalidating times.
    var asrtSet: Bool
    var urgency: CdmUrgency

    /// The same display with the countdown and dot re-derived for `now`.
    func at(_ now: Date) -> CdmSlotDisplay {
        var copy = self
        copy.minutesUntil = targetHhmm.flatMap { CdmSlot.minutesUntilUtcHhmm($0, now: now) }
        copy.urgency = CdmSlot.urgency(
            minutes: copy.minutesUntil, tentative: tentative, windowed: windowed, asrtSet: asrtSet
        )
        return copy
    }

    /// The compact chip label: "TOBT T-12m" before the target, "TOBT +3m" once it has passed.
    var chipLabel: String {
        if let minutes = minutesUntil {
            return "\(targetLabel ?? "CDM") \(minutes < 0 ? "+" : "T-")\(abs(minutes))m"
        }
        if targetHhmm == nil { return "\(targetLabel ?? "CDM") –" }
        return targetLabel ?? statusText ?? "CDM"
    }

    /// The milestone line for the expanded footer: every time the backend actually has.
    var detailLine: String {
        let parts = [
            tobt.map { "TOBT \($0)" },
            tsat.map { "TSAT \($0)" },
            ctot.map { "CTOT \($0)" },
            tobt == nil ? requestedTobt.map { "TOBT? \($0)" } : nil,
            eobt.map { "EOBT \($0)" },
            statusText
        ].compactMap { $0 }
        return parts.isEmpty ? "----" : parts.joined(separator: " · ")
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
/// rules can be tested without a server, and ported 1:1 from the Android client so both show the
/// same thing for the same flight.
enum CdmSlot {
    // A CTOT keeps simple thresholds — issue #143 lists its colour mapping as an open question.
    private static let attentionThresholdMinutes = 15
    private static let urgentThresholdMinutes = 5

    // The rpuig2001/CDM EuroScope plugin's TOBT/TSAT window, in whole minutes either side:
    // attention before it opens, good inside it, flashing as it runs out, expired after — unless
    // the flight already has an ASRT. The plugin flashes only for the final minute; like the
    // Android client we start two minutes early, because not every controller can take a flight
    // right at the edge of the window.
    private static let windowMinutes = 5
    private static let flashFromMinutesAfter = 4

    /// `minutes` is the time until the target, negative once it has passed. `windowed` is true for
    /// an accepted TOBT/TSAT; a CTOT keeps the simple thresholds.
    static func urgency(minutes: Int?, tentative: Bool, windowed: Bool, asrtSet: Bool) -> CdmUrgency {
        guard !tentative, let minutes else { return .neutral }
        if windowed {
            if minutes > windowMinutes { return .attention }
            if minutes > -flashFromMinutesAfter || asrtSet { return .good }
            if minutes >= -windowMinutes { return .flashing }
            return .urgent
        }
        if minutes <= urgentThresholdMinutes { return .urgent }
        if minutes <= attentionThresholdMinutes { return .attention }
        return .good
    }

    /// Nil only when there is no milestone and no filed EOBT at all. Falls back past the accepted
    /// times to the requested TOBT, then the filed EOBT — marked `tentative` and shown with a "?"
    /// — so the tile appears as soon as the backend tracks the flight, showing the system is live
    /// before a TOBT has been accepted.
    static func display(for flight: CdmFlight?, now: Date) -> CdmSlotDisplay? {
        guard let flight else { return nil }
        let data = flight.cdmData ?? CdmFlightData()
        let eobt = nonBlank(hhmm(flight.eobt))
        let tobt = hhmm(data.tobt.isEmpty ? (flight.tobt ?? "") : data.tobt)
        let ctot = hhmm(data.ctot.isEmpty ? (flight.ctot ?? "") : data.ctot)
        let tsat = hhmm(data.tsat)
        let reqTobt = hhmm(data.reqTobt)
        let depParts = data.depInfo.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let depRunway = depParts.first.map { String($0).trimmingCharacters(in: .whitespaces) }.flatMap(nonBlank)
        let sid = depParts.count > 1
            ? nonBlank(String(depParts[1]).trimmingCharacters(in: .whitespaces))
            : nil

        // Whichever milestone is most actionable now: CTOT (an assigned slot) outranks TSAT (a
        // startup target) outranks TOBT (the pilot's own off-block target). Each is only set once
        // its predecessor's phase is reached, so this is "the latest the backend assigned", not an
        // arbitrary priority.
        let targetLabel: String
        let targetHhmm: String
        let tentative: Bool
        if !ctot.isEmpty { (targetLabel, targetHhmm, tentative) = ("CTOT", ctot, false) }
        else if !tsat.isEmpty { (targetLabel, targetHhmm, tentative) = ("TSAT", tsat, false) }
        else if !tobt.isEmpty { (targetLabel, targetHhmm, tentative) = ("TOBT", tobt, false) }
        else if !reqTobt.isEmpty { (targetLabel, targetHhmm, tentative) = ("TOBT?", reqTobt, true) }
        else if let eobt { (targetLabel, targetHhmm, tentative) = ("EOBT?", eobt, true) }
        else { return nil }

        return CdmSlotDisplay(
            statusText: flight.cdmSts.flatMap(nonBlank),
            tobt: nonBlank(tobt),
            tsat: nonBlank(tsat),
            ctot: nonBlank(ctot),
            requestedTobt: nonBlank(reqTobt),
            eobt: eobt,
            reason: nonBlank(data.reason),
            depRunway: depRunway,
            sid: sid,
            targetLabel: targetLabel,
            targetHhmm: targetHhmm,
            minutesUntil: nil,
            tentative: tentative,
            windowed: targetLabel == "TOBT" || targetLabel == "TSAT",
            asrtSet: !data.asrt.isEmpty,
            urgency: .neutral
        ).at(now)
    }

    /// "This airport does CDM, but the backend isn't tracking the flight yet": a grey, time-less
    /// chip rather than nothing, so the pilot can tell the difference between "no CDM here" and
    /// "CDM here, nothing filed for you yet".
    static func waitingDisplay() -> CdmSlotDisplay {
        CdmSlotDisplay(
            statusText: "waiting for flight",
            targetLabel: "TOBT",
            tentative: true,
            windowed: false,
            asrtSet: false,
            urgency: .neutral
        )
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
