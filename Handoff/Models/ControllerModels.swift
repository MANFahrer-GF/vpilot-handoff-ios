import Foundation

struct ControllersMessage: Decodable {
    /// Plugin <= v0.5.0 only: one ETA for the whole list. Plugin v0.6.0 moved this
    /// onto each controller (`Controller.etaMinutes`); both are still read so the
    /// app keeps working against either side.
    let etaMinutes: Double?
    let debug: ControllersDebug?
    let controllers: [Controller]
}

/// Only non-nil while debug mode is on (see `setDebugMode`) -- deliberately
/// plain-language per protocol.md, not the raw ranking internals.
struct ControllersDebug: Decodable, Equatable {
    let phaseOfFlight: String?
    let hasTakenOffThisSession: Bool?
    let ownshipAltitudeTrue: Double?
    let ownshipAltitudeAgl: Double?
    let ownshipGroundspeedKt: Double?
    let ownshipHeadingTrue: Double?
    let activeRouteWaypoint: String?
    let lastPassedWaypoint: String?
    let activeRouteWaypointDistanceNm: Double?
    let etaCalculationDetail: String?
}

/// Per-controller ranking explanation, only non-nil in debug mode.
struct ControllerDebug: Decodable, Equatable {
    let bucket: Int?
    let bucketName: String?
    let subBucket: String?
    let reason: String?
    let distanceNm: Double?
    let vatGlassesSectorMatch: Bool?
    let vatSpyPolygonMatch: Bool?
    let routeMatch: Bool?
}

struct Controller: Decodable, Identifiable, Equatable {
    var id: String { callsign }

    let callsign: String
    let frequency: Int
    let latitude: Double?
    let longitude: Double?
    let cid: Int?
    let name: String?
    let facility: Int?
    let rating: Int?
    let stationName: String?
    let textAtis: [String]?
    let requestsContactMe: Bool
    let isCurrent: Bool
    let isContactMe: Bool
    let isHighlighted: Bool
    let isNext: Bool
    let isLikelyNext: Bool
    /// `var` only so demo mode can reflect a pin locally. In a live session the
    /// plugin owns this and sends the list back with the flag already set.
    var isPinned: Bool
    let isStandbyTuned: Bool
    let isSelcalActive: Bool
    /// Minutes until ownship reaches this controller's own sector, per protocol.md,
    /// **rounded to whole minutes at decode time**. Per-controller since plugin v0.6.0
    /// (issue #127); before that the plugin sent a single ownship-level `etaMinutes` on
    /// the message instead -- see `ControllersMessage.etaMinutes`, which the list still
    /// falls back to.
    ///
    /// Rounded here rather than in the view for a reason: the raw value is a distance
    /// divided by groundspeed, so it drifts on every one-second resend while approaching
    /// a sector. Keeping it raw would make `controllers != msg.controllers` true every
    /// second and re-render the whole list -- exactly the cost `AppStore`'s diff exists
    /// to avoid. The badge only ever shows whole minutes anyway.
    ///
    /// `0` means "less than a minute out", not "arrived": the plugin only sends a value
    /// for a sector still being approached (protocol.md), so a sub-minute value rounds
    /// down into 0 rather than meaning zero distance.
    let etaMinutes: Double?
    let debug: ControllerDebug?

    // Defensive decoding per protocol.md's Compatibility section: new optional
    // fields get added over time, existing clients should tolerate their absence
    // rather than fail to decode the whole controller list.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        callsign = try c.decode(String.self, forKey: .callsign)
        frequency = try c.decode(Int.self, forKey: .frequency)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        cid = try c.decodeIfPresent(Int.self, forKey: .cid)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        facility = try c.decodeIfPresent(Int.self, forKey: .facility)
        rating = try c.decodeIfPresent(Int.self, forKey: .rating)
        stationName = try c.decodeIfPresent(String.self, forKey: .stationName)
        textAtis = try c.decodeIfPresent([String].self, forKey: .textAtis)
        requestsContactMe = try c.decodeIfPresent(Bool.self, forKey: .requestsContactMe) ?? false
        isCurrent = try c.decodeIfPresent(Bool.self, forKey: .isCurrent) ?? false
        isContactMe = try c.decodeIfPresent(Bool.self, forKey: .isContactMe) ?? false
        isHighlighted = try c.decodeIfPresent(Bool.self, forKey: .isHighlighted) ?? false
        isNext = try c.decodeIfPresent(Bool.self, forKey: .isNext) ?? false
        isLikelyNext = try c.decodeIfPresent(Bool.self, forKey: .isLikelyNext) ?? false
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        isStandbyTuned = try c.decodeIfPresent(Bool.self, forKey: .isStandbyTuned) ?? false
        isSelcalActive = try c.decodeIfPresent(Bool.self, forKey: .isSelcalActive) ?? false
        etaMinutes = try c.decodeIfPresent(Double.self, forKey: .etaMinutes)
            .flatMap { Controller.wholeMinutes($0) }
        debug = try c.decodeIfPresent(ControllerDebug.self, forKey: .debug)
    }

    enum CodingKeys: String, CodingKey {
        case callsign, frequency, latitude, longitude, cid, name, facility, rating
        case stationName, textAtis, requestsContactMe
        case isCurrent, isContactMe, isHighlighted, isNext, isLikelyNext
        case isPinned, isStandbyTuned, isSelcalActive, etaMinutes, debug
    }

    /// Whole minutes, or nil when there is nothing sensible to count down to: a
    /// negative ETA means the geometry already passed the sector, and a non-finite one
    /// means the plugin divided by something it shouldn't have. Both are dropped rather
    /// than shown as an imminent arrival.
    static func wholeMinutes(_ minutes: Double) -> Double? {
        guard minutes.isFinite, minutes >= 0 else { return nil }
        return minutes.rounded()
    }

    /// What the row badge shows, or nil when there is no ETA to show.
    var etaBadgeText: String? {
        guard let etaMinutes else { return nil }
        return etaMinutes < 1 ? "ETA <1\u{2032}" : "ETA \(Int(etaMinutes))\u{2032}"
    }

    var frequencyMHzText: String {
        String(format: "%.3f", VHFFrequency.decode(compressed: frequency))
    }

    /// Fallback used only when `stationName` is nil (see protocol.md) -- parses the
    /// conventional callsign suffix rather than leaving the row blank.
    var facilityLabel: String {
        switch facility {
        case 2: return "DEL"
        case 3: return "GND"
        case 4: return "TWR"
        case 5: return "APP/DEP"
        case 6: return "CTR"
        default:
            return callsign.split(separator: "_").last.map(String.init) ?? ""
        }
    }

    /// Synthesises a controller for previews and the theme editor's sample rows --
    /// the wire type has no memberwise init because every real one is decoded.
    static func preview(
        callsign: String,
        frequency: Int,
        facility: Int?,
        isHighlighted: Bool = false
    ) -> Controller {
        let json = """
        {"callsign":"\(callsign)","frequency":\(frequency),
         "facility":\(facility.map(String.init) ?? "null"),
         "isHighlighted":\(isHighlighted)}
        """
        // Force-unwrapped on purpose: the literal above is fixed and self-consistent,
        // so a failure here is a programming error, not a runtime condition.
        return try! JSONDecoder().decode(Controller.self, from: Data(json.utf8))
    }

    var isAtis: Bool { callsign.contains("ATIS") }

    /// The badge on the right of each row is the controller's VATSIM rating
    /// (C1/S2/S3/...), display-only per protocol.md -- never a tuned indicator.
    /// ATIS stations have no human rating, so they show "ATIS" instead.
    var ratingLabel: String? {
        if isAtis { return "ATIS" }
        guard let rating else { return nil }
        switch rating {
        case 1: return "OBS"
        case 2: return "S1"
        case 3: return "S2"
        case 4: return "S3"
        case 5: return "C1"
        case 6: return "C2"
        case 7: return "C3"
        case 8: return "I1"
        case 9: return "I2"
        case 10: return "I3"
        case 11: return "SUP"
        case 12: return "ADM"
        default: return nil
        }
    }
}
