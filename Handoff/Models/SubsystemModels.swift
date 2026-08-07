import Foundation

struct SubsystemStatus: Decodable, Equatable {
    let radioHostConnected: Bool
    let simulatorConnected: Bool
    let vatsimDataFeedConnected: Bool
    let simbriefFetched: Bool
    let pluginVersion: String
    let updateInterval: String?
    let systemsDebug: SystemsDebug?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        radioHostConnected = try c.decodeIfPresent(Bool.self, forKey: .radioHostConnected) ?? false
        simulatorConnected = try c.decodeIfPresent(Bool.self, forKey: .simulatorConnected) ?? false
        vatsimDataFeedConnected = try c.decodeIfPresent(Bool.self, forKey: .vatsimDataFeedConnected) ?? false
        simbriefFetched = try c.decodeIfPresent(Bool.self, forKey: .simbriefFetched) ?? false
        pluginVersion = try c.decodeIfPresent(String.self, forKey: .pluginVersion) ?? "?"
        updateInterval = try c.decodeIfPresent(String.self, forKey: .updateInterval)
        systemsDebug = try c.decodeIfPresent(SystemsDebug.self, forKey: .systemsDebug)
    }

    enum CodingKeys: String, CodingKey {
        case radioHostConnected, simulatorConnected, vatsimDataFeedConnected
        case simbriefFetched, pluginVersion, updateInterval, systemsDebug
    }
}

/// Only non-nil while debug mode is on -- one plain-language health line per
/// non-ranking subsystem (see docs/protocol.md's subsystemStatus section).
struct SystemsDebug: Decodable, Equatable {
    let radioHostConnected: Bool?
    let simulatorConnected: Bool?
    let vatsimFeedConnected: Bool?
    let simbriefFetchedSuccessfully: Bool?
    let simbriefLastError: String?
    let vatGlassesLoadedRegionCount: Int?
    let vatSpyBoundaryCount: Int?
    let pairedClientCount: Int?
    let authenticatedSocketCount: Int?
    let activeOperationCount: Int?
}

struct OperationProgressMessage: Decodable {
    let operationId: String
    let status: String
    let finished: Bool
    let success: Bool?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        operationId = try c.decodeIfPresent(String.self, forKey: .operationId) ?? ""
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        finished = try c.decodeIfPresent(Bool.self, forKey: .finished) ?? false
        success = try c.decodeIfPresent(Bool.self, forKey: .success)
    }

    enum CodingKeys: String, CodingKey { case operationId, status, finished, success }
}
