import Foundation

struct AuthResult: Decodable {
    let success: Bool
    let token: String?
    let reason: String? // "pairingRequired" | "invalidCode"
    let simbriefUserId: String?
    let simbriefUsername: String?
}

struct DebugSnapshotSavedMessage: Decodable {
    let snapshotId: String
    let path: String
}

struct DebugSnapshotNamedMessage: Decodable {
    let snapshotId: String
    let success: Bool
    let error: String?
}
