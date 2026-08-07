import Foundation

struct FlightPlanMessage: Decodable, Equatable {
    let simbriefCallsign: String?
    let simbriefOrigin: String?
    let simbriefDestination: String?
    let simbriefAlternate: String?
    let vatsimCallsign: String?
    let vatsimOrigin: String?
    let vatsimDestination: String?
    let originMismatch: Bool?
    let vatsimCidMismatch: Bool?

    /// Connected but the feed has no filed plan for us -- protocol.md calls this out
    /// as a real, recurring mistake worth flagging once it persists past poll lag.
    var vatsimPlanMissing: Bool {
        vatsimCallsign != nil && (vatsimOrigin == nil || vatsimDestination == nil)
    }

    /// SimBrief OFP and what's actually filed on the network have diverged.
    var simbriefVatsimMismatch: Bool {
        guard let vatsimOrigin, let vatsimDestination,
              let simbriefOrigin, let simbriefDestination else { return false }
        return vatsimOrigin != simbriefOrigin || vatsimDestination != simbriefDestination
    }

    var hasAnyWarning: Bool {
        originMismatch == true || vatsimCidMismatch == true || vatsimPlanMissing || simbriefVatsimMismatch
    }
}

struct DiversionPendingMessage: Decodable {
    let destination: String?
}

struct NearbyAircraftMessage: Decodable {
    let aircraft: [NearbyAircraft]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        aircraft = try c.decodeIfPresent([NearbyAircraft].self, forKey: .aircraft) ?? []
    }

    enum CodingKeys: String, CodingKey { case aircraft }
}

struct NearbyAircraft: Decodable, Identifiable, Equatable {
    var id: String { callsign }
    let callsign: String
    let aircraftType: String?
    let distanceNm: Double

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        callsign = try c.decodeIfPresent(String.self, forKey: .callsign) ?? "?"
        aircraftType = try c.decodeIfPresent(String.self, forKey: .aircraftType)
        distanceNm = try c.decodeIfPresent(Double.self, forKey: .distanceNm) ?? 0
    }

    enum CodingKeys: String, CodingKey { case callsign, aircraftType, distanceNm }
}
