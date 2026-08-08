import Foundation

/// Properties are `var` so demo mode can reflect a tap locally. Live state is
/// only ever replaced wholesale by what the plugin sends -- never edited in place,
/// because the sim is the authority on what the radios are actually set to.
struct RadioState: Decodable, Equatable {
    var com1Frequency: Int?
    var com2Frequency: Int?
    var com1StandbyFrequency: Int?
    var com2StandbyFrequency: Int?
    var modeCEnabled: Bool
    var transponderCode: Int?
    var com1TransmitEnabled: Bool
    var com2TransmitEnabled: Bool
    var com1ReceiveEnabled: Bool
    var com2ReceiveEnabled: Bool

    /// Only demo mode builds one of these by hand -- live radio state always comes
    /// off the wire, because the sim is the authority on what the radios are doing.
    init(
        com1Frequency: Int?, com2Frequency: Int?,
        com1StandbyFrequency: Int?, com2StandbyFrequency: Int?,
        modeCEnabled: Bool, transponderCode: Int?,
        com1TransmitEnabled: Bool, com2TransmitEnabled: Bool,
        com1ReceiveEnabled: Bool, com2ReceiveEnabled: Bool
    ) {
        self.com1Frequency = com1Frequency
        self.com2Frequency = com2Frequency
        self.com1StandbyFrequency = com1StandbyFrequency
        self.com2StandbyFrequency = com2StandbyFrequency
        self.modeCEnabled = modeCEnabled
        self.transponderCode = transponderCode
        self.com1TransmitEnabled = com1TransmitEnabled
        self.com2TransmitEnabled = com2TransmitEnabled
        self.com1ReceiveEnabled = com1ReceiveEnabled
        self.com2ReceiveEnabled = com2ReceiveEnabled
    }

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
