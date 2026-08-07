import Foundation

// Every client->server message per docs/protocol.md. Kept as small, dedicated
// Encodable structs (rather than one generic enum) so JSONEncoder can produce
// the exact wire shape without a hand-rolled encode(to:).

struct AuthenticateCommand: Encodable {
    let type = "authenticate"
    let token: String?
    let pairingCode: String?
    let deviceId: String
}

struct SendPrivateMessageCommand: Encodable {
    let type = "sendPrivateMessage"
    let to: String
    let message: String
}

struct SendRadioMessageCommand: Encodable {
    let type = "sendRadioMessage"
    let message: String
}

/// Covers setCom1Frequency / setCom2Frequency / setCom1StandbyFrequency / setCom2StandbyFrequency.
/// `megahertz` is plain decimal MHz -- the one place the wire format is NOT the
/// compressed-integer encoding used elsewhere (see protocol.md).
struct SetFrequencyCommand: Encodable {
    let type: String
    let megahertz: Double
}

/// Covers setCom1ActiveAndStandbyFrequency / setCom2ActiveAndStandbyFrequency.
struct SetActiveAndStandbyCommand: Encodable {
    let type: String
    let megahertz: Double
    let standbyMegahertz: Double
}

struct SetTransponderCodeCommand: Encodable {
    let type = "setTransponderCode"
    let transponderCode: Int
}

/// Covers selectCom1Transmitter / selectCom2Transmitter -- no fields of their own.
struct SelectTransmitterCommand: Encodable {
    let type: String
}

/// Covers setCom1ReceiveEnabled / setCom2ReceiveEnabled.
struct SetReceiveEnabledCommand: Encodable {
    let type: String
    let enabled: Bool
}

struct SetSimbriefCredentialsCommand: Encodable {
    let type = "setSimbriefCredentials"
    let simbriefUserId: String?
    let simbriefUsername: String?
}

struct SetUpdateIntervalCommand: Encodable {
    let type = "setUpdateInterval"
    let interval: String // fast | normal | slow
}

/// Covers pinController / clearPinnedController.
struct PinControllerCommand: Encodable {
    let type: String
    let callsign: String
}

struct DismissSelcalCommand: Encodable {
    let type = "dismissSelcal"
    let callsign: String
}

/// Covers confirmDiversion / dismissDiversion / refreshFlightPlan -- no fields of their own.
struct SimpleCommand: Encodable {
    let type: String
}

struct PingCommand: Encodable {
    let type = "ping"
    let clientTimestamp: Int64
}

struct SetDebugModeCommand: Encodable {
    let type = "setDebugMode"
    let enabled: Bool
}

struct SaveDebugSnapshotCommand: Encodable {
    let type = "saveDebugSnapshot"
    let snapshotId: String
    let appVersion: String
}

struct AttachDebugSnapshotScreenshotCommand: Encodable {
    let type = "attachDebugSnapshotScreenshot"
    let snapshotId: String
    let screenshotPngBase64: String
}

struct NameDebugSnapshotCommand: Encodable {
    let type = "nameDebugSnapshot"
    let snapshotId: String
    let name: String
}
