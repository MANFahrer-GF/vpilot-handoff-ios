import Foundation

enum FrequencyTarget: Identifiable {
    case com1Active, com1Standby, com2Active, com2Standby

    var id: String {
        switch self {
        case .com1Active: return "com1Active"
        case .com1Standby: return "com1Standby"
        case .com2Active: return "com2Active"
        case .com2Standby: return "com2Standby"
        }
    }

    var title: String {
        switch self {
        case .com1Active: return "COM1 TUNE"
        case .com1Standby: return "COM1 STANDBY"
        case .com2Active: return "COM2 TUNE"
        case .com2Standby: return "COM2 STANDBY"
        }
    }

    var isCom1: Bool { self == .com1Active || self == .com1Standby }
    var isActive: Bool { self == .com1Active || self == .com2Active }
}

extension FrequencyTarget: Equatable {}

/// Keypad entry dialogs only -- settings is presented separately as a full-screen
/// cover, since iPadOS pins sheets to a form-sheet width too narrow for it.
enum DashboardSheet: Identifiable {
    case frequency(FrequencyTarget)
    case transponder

    var id: String {
        switch self {
        case .frequency(let target): return "frequency-\(target.id)"
        case .transponder: return "transponder"
        }
    }
}
