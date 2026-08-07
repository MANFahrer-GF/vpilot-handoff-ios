import Foundation

/// Every model here decodes defensively (optionals + defaults), because
/// HandoffConnection dispatches with `try?` -- a single missing or newly-added
/// field would otherwise silently drop the entire message rather than degrade.
/// protocol.md's Compatibility section makes this the contract, not an edge case.
struct ChatMessagePayload: Decodable {
    let messages: [ChatMessage]
    let selcalAlerts: [SelcalAlert]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        messages = try c.decodeIfPresent([ChatMessage].self, forKey: .messages) ?? []
        selcalAlerts = try c.decodeIfPresent([SelcalAlert].self, forKey: .selcalAlerts) ?? []
    }

    enum CodingKeys: String, CodingKey { case messages, selcalAlerts }
}

struct ChatMessage: Decodable, Identifiable, Equatable {
    let channel: String // private | radio | broadcast
    let direction: String // incoming | outgoing
    let peer: String?
    let from: String?
    let text: String
    let frequencies: [Int]?
    let timestamp: String

    /// Derived from content rather than a fresh UUID: the plugin resends the whole
    /// chat log on every change, so a per-decode UUID would give every message a new
    /// identity each second and make SwiftUI rebuild (and scroll-jump) the list.
    var id: String { "\(timestamp)|\(channel)|\(direction)|\(peer ?? from ?? "")|\(text)" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        channel = try c.decodeIfPresent(String.self, forKey: .channel) ?? "radio"
        direction = try c.decodeIfPresent(String.self, forKey: .direction) ?? "incoming"
        peer = try c.decodeIfPresent(String.self, forKey: .peer)
        from = try c.decodeIfPresent(String.self, forKey: .from)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        frequencies = try c.decodeIfPresent([Int].self, forKey: .frequencies)
        timestamp = try c.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case channel, direction, peer, from, text, frequencies, timestamp
    }

    var isOutgoing: Bool { direction == "outgoing" }
    var isRadio: Bool { channel == "radio" }

    /// Reserved key for the frequency's own traffic, distinct from any callsign.
    static let radioConversationKey = "\u{0}radio"

    /// Which tab this message belongs to: the shared radio channel, or the station
    /// it was exchanged with.
    var conversationKey: String {
        isRadio ? Self.radioConversationKey : (peer ?? "?")
    }

    /// Does this radio call name us? Matched on whole tokens rather than a substring,
    /// so "DLH12" doesn't light up for "DLH123" and a callsign inside a longer word
    /// doesn't count.
    func mentions(callsign: String?) -> Bool {
        guard let callsign, !callsign.isEmpty else { return false }
        let needle = callsign.uppercased()
        return text.uppercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .contains { $0 == needle }
    }

    /// Aimed at this pilot rather than at the frequency in general: an incoming
    /// private message, or a radio call that names us. This is what earns a
    /// highlight -- ambient chatter does not.
    func isDirectedAtUs(ownCallsign: String?) -> Bool {
        guard !isOutgoing else { return false }
        if !isRadio { return true }
        return mentions(callsign: ownCallsign)
    }

    /// "122.800" for radio messages (the frequency identifies the channel),
    /// the other party's callsign for private/broadcast.
    var headerLabel: String {
        if isRadio {
            if let frequency = frequencies?.first {
                return String(format: "%.3f", VHFFrequency.decode(compressed: frequency))
            }
            return from ?? "RADIO"
        }
        return peer ?? "?"
    }

    /// Incoming radio traffic carries a transmitting station; show it alongside the
    /// frequency so ambient chatter is attributable.
    var senderLabel: String? {
        guard isRadio, !isOutgoing else { return nil }
        return from
    }

    var timeLabel: String {
        guard let date = Date.fromHandoffTimestamp(timestamp) else { return "" }
        return DateFormatter.handoffTime.string(from: date)
    }
}

extension Date {
    /// protocol.md documents plain "2026-07-25T10:15:30Z", but .NET's own serializer
    /// emits fractional seconds in some configurations -- try both rather than
    /// silently rendering an empty timestamp.
    static func fromHandoffTimestamp(_ value: String) -> Date? {
        ISO8601DateFormatter.handoffFractional.date(from: value)
            ?? ISO8601DateFormatter.handoffPlain.date(from: value)
    }
}

struct SelcalAlert: Decodable, Identifiable, Equatable {
    let from: String
    let frequencies: [Int]
    let timestamp: String

    var id: String { "\(from)|\(timestamp)" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.from = try c.decodeIfPresent(String.self, forKey: .from) ?? "?"
        frequencies = try c.decodeIfPresent([Int].self, forKey: .frequencies) ?? []
        timestamp = try c.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
    }

    enum CodingKeys: String, CodingKey { case from, frequencies, timestamp }
}

// Formatters are configured once and only ever read afterwards; Foundation
// documents that as thread-safe, which is what `nonisolated(unsafe)` asserts here.
// Rebuilding them per call would be the alternative, and these run once per chat
// row per render.
extension ISO8601DateFormatter {
    nonisolated(unsafe) static let handoffFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) static let handoffPlain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension DateFormatter {
    static let handoffTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
