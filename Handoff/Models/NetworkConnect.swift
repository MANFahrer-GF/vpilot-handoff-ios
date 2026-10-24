import Foundation

/// The rules behind the connect-to-VATSIM form (upstream issue #171), ported from the Android
/// client's `NetworkConnect` so both refuse and warn about the same input. Kept free of SwiftUI so
/// they can be tested on their own.
enum NetworkConnect {
    /// The first plugin release that understands connectNetwork/disconnectNetwork and
    /// refreshVatsimFeed. An older one ignores them and never answers (protocol.md).
    static let minPluginVersion = "0.8.0"

    // Deliberately permissive: vPilot and the network enforce the real callsign/type limits and
    // report a rejection back, so these only catch obvious typos before sending.
    // Computed, not stored: `Regex` isn't Sendable, so a stored static fails Swift 6's checks.
    private static var callsignPattern: Regex<Substring> { #/^[A-Z0-9_-]{1,10}$/# }
    private static var typePattern: Regex<Substring> { #/^[A-Z0-9]{2,4}$/# }

    /// Whether the connected plugin is new enough to offer the controls. An unknown version ("?",
    /// the decoder's default for a plugin that never sent one) counts as too old, and so does a
    /// pre-release of 0.8.0 itself ("0.8.0-beta"), which may predate the finished commands.
    static func isSupported(pluginVersion: String?) -> Bool {
        guard let installed = versionParts(pluginVersion) else { return false }
        let required = versionParts(minPluginVersion)?.numbers ?? []
        for index in 0..<max(installed.numbers.count, required.count) {
            let have = index < installed.numbers.count ? installed.numbers[index] : 0
            let need = index < required.count ? required[index] : 0
            if have != need { return have > need }
        }
        return !installed.isPrerelease
    }

    /// "0.10.1" as [0, 10, 1], compared number by number so 0.10 is newer than 0.9. A suffix after
    /// the numbers ("-beta") marks a pre-release, which ranks below the same numbers without one;
    /// nil when there is no leading number at all.
    private static func versionParts(_ version: String?) -> (numbers: [Int], isPrerelease: Bool)? {
        guard let version else { return nil }
        let trimmed = version.trimmingCharacters(in: .whitespaces)
        let numeric = trimmed.prefix { $0.isNumber || $0 == "." }
        let parts = numeric.split(separator: ".").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        return (parts, numeric.count < trimmed.count)
    }

    static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// What the SELCAL field holds: uppercase letters and digits, no dash or spaces, at most four.
    /// Digits are kept so a plan's "IAZ9" stays on screen to be corrected; `selcalWarning` then
    /// says vPilot currently doesn't take them.
    static func cleanSelcal(_ text: String) -> String {
        String(text.uppercased().filter { ("A"..."Z").contains($0) || $0.isASCII && $0.isNumber }.prefix(4))
    }

    /// The form vPilot accepts: "AB-CD", with the dash once there is a third character.
    static func formatSelcal(_ text: String) -> String {
        let chars = cleanSelcal(text)
        guard chars.count > 2 else { return chars }
        return "\(chars.prefix(2))-\(chars.dropFirst(2))"
    }

    /// Why Connect must stay disabled, or nil when the form can be sent. Ordered by what the pilot
    /// most likely needs to fix first. The simulator link is deliberately not checked: vPilot
    /// reports a missing one itself, and the plugin relays that.
    static func blockedReason(callsign: String, aircraftType: String, observer: Bool) -> String? {
        let callsign = normalize(callsign)
        let type = normalize(aircraftType)
        if callsign.isEmpty { return "Enter a callsign." }
        if callsign.wholeMatch(of: callsignPattern) == nil {
            return "Callsign can only use letters, digits, - and _ (max 10)."
        }
        if observer { return nil }
        if type.isEmpty { return "Enter the aircraft type." }
        if type.wholeMatch(of: typePattern) == nil {
            return "Aircraft type is the 2-4 character ICAO code, e.g. A320."
        }
        return nil
    }

    // Classic SELCAL-16 alphabet: A-S without I, N and O.
    private static let selcalLetters = Set("ABCDEFGHJKLMPQRS")

    /// A heads-up, never a block: vPilot accepts or refuses the code itself, with its own message.
    /// Nil while the field is empty or the code is fine.
    static func selcalWarning(_ selcal: String) -> String? {
        let chars = Array(cleanSelcal(selcal))
        if chars.isEmpty { return nil }
        if chars.count != 4 { return "SELCAL is normally 4 characters, e.g. AB-CD." }
        if chars.contains(where: \.isNumber) { return "vPilot currently doesn't support SELCAL with digits (SELCAL32)." }
        if chars.contains(where: { !selcalLetters.contains($0) }) {
            return "Unusual SELCAL: standard codes use the letters A-S without I, N and O."
        }
        if Set(chars).count != 4 { return "Unusual SELCAL: standard codes don't repeat a letter." }
        if chars[0] > chars[1] || chars[2] > chars[3] {
            return "Unusual SELCAL: standard codes have each pair in alphabetical order, e.g. AB-CD."
        }
        return nil
    }

    /// The command for a filled-in form, or nil when `blockedReason` would refuse it. As an
    /// observer the type and SELCAL are left out, since the plugin ignores them anyway.
    static func command(
        operationId: String, callsign: String, aircraftType: String, selcal: String, observer: Bool
    ) -> ConnectNetworkCommand? {
        guard blockedReason(callsign: callsign, aircraftType: aircraftType, observer: observer) == nil else { return nil }
        let code = cleanSelcal(selcal)
        return ConnectNetworkCommand(
            operationId: operationId,
            callsign: normalize(callsign),
            aircraftType: observer ? nil : normalize(aircraftType),
            selcalCode: observer || code.isEmpty ? nil : formatSelcal(code),
            observer: observer
        )
    }
}

/// One connect or disconnect this device asked for, followed through the plugin's
/// `operationProgress` under the id it minted.
struct NetworkRequest: Equatable {
    enum Kind: Equatable { case connect, disconnect }

    let id: String
    let kind: Kind
    var status: String
    var finished = false
    var success: Bool?

    var failed: Bool { finished && success == false }
    var succeeded: Bool { finished && success == true }
}
