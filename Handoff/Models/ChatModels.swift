import Foundation

/// Every model here decodes defensively (optionals + defaults), because
/// HandoffConnection dispatches with `try?` -- a single missing or newly-added
/// field would otherwise silently drop the entire message rather than degrade.
/// protocol.md's Compatibility section makes this the contract, not an edge case.
struct ChatMessagePayload: Decodable {
    let messages: [ChatMessage]
    let selcalAlerts: [SelcalAlert]
    /// Issue #151: changes on every plugin restart, which invalidates every message
    /// `id` that came before it. `nil` from a plugin that predates the feature, and
    /// that absence is what tells the app to keep tracking unread by itself.
    let sessionId: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        messages = try c.decodeIfPresent([ChatMessage].self, forKey: .messages) ?? []
        selcalAlerts = try c.decodeIfPresent([SelcalAlert].self, forKey: .selcalAlerts) ?? []
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
    }

    enum CodingKeys: String, CodingKey { case messages, selcalAlerts, sessionId }
}

/// The plugin's own per-tab read watermark (issue #151), so an unread count survives
/// an app restart and matches on every paired device. Its own message rather than part
/// of `chat`, because it changes far more often than the log it refers to.
struct ChatReadStateMessage: Decodable {
    let sessionId: String?
    /// Tab -> highest message id read there. A tab nobody has read yet is simply absent.
    let readThrough: [String: Int]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try c.decodeIfPresent(String.self, forKey: .sessionId)
        readThrough = try c.decodeIfPresent([String: Int].self, forKey: .readThrough) ?? [:]
    }

    enum CodingKeys: String, CodingKey { case sessionId, readThrough }

    /// The wire name of the shared frequency tab, which the app keys as
    /// `ChatMessage.radioConversationKey` internally.
    static let radioTab = "radio"
}

struct ChatMessage: Decodable, Identifiable, Equatable {
    /// The plugin's own message id (issue #151): monotonic for one plugin run, reset by
    /// a restart, and only meaningful together with the payload's `sessionId`. `nil`
    /// from an older plugin. Distinct from `id` below, which identifies a row on screen.
    let messageId: Int?
    let channel: String // private | radio | broadcast
    let direction: String // incoming | outgoing
    let peer: String?
    let from: String?
    let text: String
    /// True when `text` above is the `""` decode fallback rather than a real value the
    /// plugin sent -- i.e. the `text` key was absent or JSON `null`. Lets the UI show
    /// "message not received" instead of a silent blank bubble indistinguishable from
    /// an actually-empty message.
    let textWasMissing: Bool
    let frequencies: [Int]?
    let timestamp: String

    /// Derived from content rather than a fresh UUID: the plugin resends the whole
    /// chat log on every change, so a per-decode UUID would give every message a new
    /// identity each second and make SwiftUI rebuild (and scroll-jump) the list.
    var id: String { "\(timestamp)|\(channel)|\(direction)|\(peer ?? from ?? "")|\(text)" }

    /// Only demo mode builds a message locally. A live conversation is always the
    /// plugin's full resend, so echoing a sent message here would duplicate it the
    /// moment the real one comes back.
    init(
        channel: String, direction: String, peer: String?, from: String?,
        text: String, frequencies: [Int]?, timestamp: String, messageId: Int? = nil
    ) {
        self.messageId = messageId
        self.channel = channel
        self.direction = direction
        self.peer = peer
        self.from = from
        self.text = text
        self.textWasMissing = false
        self.frequencies = frequencies
        self.timestamp = timestamp
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        messageId = try c.decodeIfPresent(Int.self, forKey: .id)
        channel = try c.decodeIfPresent(String.self, forKey: .channel) ?? "radio"
        direction = try c.decodeIfPresent(String.self, forKey: .direction) ?? "incoming"
        peer = try c.decodeIfPresent(String.self, forKey: .peer)
        from = try c.decodeIfPresent(String.self, forKey: .from)
        if let decodedText = try c.decodeIfPresent(String.self, forKey: .text) {
            text = decodedText
            textWasMissing = false
        } else {
            text = ""
            textWasMissing = true
        }
        frequencies = try c.decodeIfPresent([Int].self, forKey: .frequencies)
        timestamp = try c.decodeIfPresent(String.self, forKey: .timestamp) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id, channel, direction, peer, from, text, frequencies, timestamp
    }

    /// The tab name the plugin uses in `readThrough`/`markChatRead`: `"radio"` for the
    /// shared frequency, otherwise the peer's callsign as the plugin spelled it.
    var readStateTab: String {
        conversationKey == Self.radioConversationKey ? ChatReadStateMessage.radioTab : (peer ?? "?")
    }

    var isOutgoing: Bool { direction == "outgoing" }
    var isRadio: Bool { channel == "radio" }

    /// Reserved key for the frequency's own traffic, distinct from any callsign.
    static let radioConversationKey = "\u{0}radio"

    /// Does this message belong in `key`'s tab? The one place that decides it, so the list on
    /// screen and the unread count can never disagree about where a message lives.
    func belongs(toConversation key: String) -> Bool { conversationKey == key }

    /// Which tab this message belongs to: a private exchange sits under the station it was with,
    /// everything else — radio *and* broadcast — under the shared frequency. protocol.md names
    /// one tab `"radio"` for both, so a broadcast in its own tab would mark the wrong tab read
    /// on the plugin and leave the real one unread on the pilot's other device.
    var conversationKey: String {
        channel == "private" ? (peer ?? "?") : Self.radioConversationKey
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
        if channel == "private" { return true }
        // A broadcast goes to everyone on the network, so it is only directed at this pilot if
        // it names them -- same test as frequency chatter.
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
