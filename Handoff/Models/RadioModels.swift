import Foundation

struct RadioState: Decodable, Equatable {
    let com1Frequency: Int?
    let com2Frequency: Int?
    let com1StandbyFrequency: Int?
    let com2StandbyFrequency: Int?
    let modeCEnabled: Bool
    let transponderCode: Int?
    let com1TransmitEnabled: Bool
    let com2TransmitEnabled: Bool
    let com1ReceiveEnabled: Bool
    let com2ReceiveEnabled: Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        com1Frequency = try c.decodeIfPresent(Int.self, forKey: .com1Frequency)
        com2Frequency = try c.decodeIfPresent(Int.self, forKey: .com2Frequency)
        com1StandbyFrequency = try c.decodeIfPresent(Int.self, forKey: .com1StandbyFrequency)
        com2StandbyFrequency = try c.decodeIfPresent(Int.self, forKey: .com2StandbyFrequency)
        modeCEnabled = try c.decodeIfPresent(Bool.self, forKey: .modeCEnabled) ?? false
        transponderCode = try c.decodeIfPresent(Int.self, forKey: .transponderCode)
        com1TransmitEnabled = try c.decodeIfPresent(Bool.self, forKey: .com1TransmitEnabled) ?? false
        com2TransmitEnabled = try c.decodeIfPresent(Bool.self, forKey: .com2TransmitEnabled) ?? false
        com1ReceiveEnabled = try c.decodeIfPresent(Bool.self, forKey: .com1ReceiveEnabled) ?? false
        com2ReceiveEnabled = try c.decodeIfPresent(Bool.self, forKey: .com2ReceiveEnabled) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case com1Frequency, com2Frequency, com1StandbyFrequency, com2StandbyFrequency
        case modeCEnabled, transponderCode
        case com1TransmitEnabled, com2TransmitEnabled, com1ReceiveEnabled, com2ReceiveEnabled
    }
}
