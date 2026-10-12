import Testing
import Foundation
@testable import Handoff

/// Issue #151 upstream: the plugin took ownership of the chat read watermark, so an
/// unread count survives an app restart and agrees across every paired device. The
/// app has to run two tracking paths now — the plugin's, and the local one it used
/// before — and pick by what the connected plugin actually sends. These pin the
/// switch between them, because the wrong one looks perfectly fine on screen right
/// up until a second device disagrees.
@MainActor
struct ChatReadStateTests {
    private func store() -> AppStore {
        TestDefaults.installOnce()
        let store = AppStore()
        store.connect(host: "127.0.0.1", port: 48765)
        store.disconnect()
        return store
    }

    private func chat(_ json: String) throws -> ChatMessagePayload {
        try JSONDecoder().decode(ChatMessagePayload.self, from: Data(json.utf8))
    }

    private func readState(_ json: String) throws -> ChatReadStateMessage {
        try JSONDecoder().decode(ChatReadStateMessage.self, from: Data(json.utf8))
    }

    private func log(sessionId: String?, _ entries: String) -> String {
        let session = sessionId.map { "\"sessionId\":\"\($0)\"," } ?? ""
        return "{\"type\":\"chat\",\(session)\"messages\":[\(entries)]}"
    }

    private let radioFromTwr = """
        {"id":41,"channel":"radio","direction":"incoming","from":"EDDM_TWR","text":"DLH4TK wind calm","timestamp":"2026-10-12T10:00:00Z"}
        """
    private let privateFromApp = """
        {"id":42,"channel":"private","direction":"incoming","peer":"EDDM_APP","text":"descend FL100","timestamp":"2026-10-12T10:01:00Z"}
        """

    /// The whole point of the feature: a message the plugin already knows was read
    /// must not come back as unread when the app reconnects or starts fresh.
    @Test func alreadyReadMessagesArriveRead() throws {
        let store = self.store()
        store.connection.onChat?(try chat(log(sessionId: "abc", "\(radioFromTwr),\(privateFromApp)")))
        #expect(store.unreadChatCount == 2)

        store.connection.onChatReadState?(try readState("""
            {"type":"chatReadState","sessionId":"abc","readThrough":{"radio":41,"EDDM_APP":42}}
            """))
        #expect(store.unreadChatCount == 0)
        #expect(store.hasUnreadDirectedMessage == false)
    }

    /// A watermark from a previous plugin run refers to ids that no longer exist.
    /// Honouring it would silence genuinely unread traffic.
    @Test func watermarkFromAnotherSessionIsIgnored() throws {
        let store = self.store()
        store.connection.onChat?(try chat(log(sessionId: "new", "\(radioFromTwr),\(privateFromApp)")))
        store.connection.onChatReadState?(try readState("""
            {"type":"chatReadState","sessionId":"old","readThrough":{"radio":41,"EDDM_APP":42}}
            """))
        #expect(store.unreadChatCount == 2)
    }

    /// Reading a tab here has to reach the plugin, or the same message stays unread
    /// on the pilot's other device.
    @Test func openingATabTellsThePluginHowFarItWasRead() throws {
        let store = self.store()
        store.connection.onChat?(try chat(log(sessionId: "abc", "\(radioFromTwr),\(privateFromApp)")))

        store.markConversationRead("EDDM_APP")
        #expect(store.unreadByConversation["EDDM_APP", default: 0] == 0)
        // The radio tab was not the one being read, so its badge stays.
        #expect(store.unreadByConversation[ChatMessage.radioConversationKey] == 1)
    }

    /// The plugin spells a peer the way the network did; nothing promises both sides
    /// capitalise it the same way.
    @Test func tabNamesMatchRegardlessOfCase() throws {
        let store = self.store()
        store.connection.onChat?(try chat(log(sessionId: "abc", privateFromApp)))
        store.connection.onChatReadState?(try readState("""
            {"type":"chatReadState","sessionId":"abc","readThrough":{"eddm_app":42}}
            """))
        #expect(store.unreadChatCount == 0)
    }

    /// Against a plugin without the feature, nothing may change: no session id means
    /// the app counts locally, exactly as it did before.
    @Test func olderPluginKeepsTheLocalCounting() throws {
        let store = self.store()
        // First payload is the existing log, which is history rather than news.
        store.connection.onChat?(try chat(log(sessionId: nil, radioFromTwr)))
        #expect(store.pluginOwnsChatReadState == false)
        #expect(store.unreadChatCount == 0)

        store.connection.onChat?(try chat(log(sessionId: nil, "\(radioFromTwr),\(privateFromApp)")))
        #expect(store.unreadChatCount == 1)
        store.markConversationRead("EDDM_APP")
        #expect(store.unreadChatCount == 0)
    }

    /// What actually reaches the plugin is what a second device depends on: the right tab name
    /// and the right watermark. Checking only the local badge would pass even if nothing was
    /// ever sent.
    @Test func theCommandCarriesTheWireTabNameAndTheNewestId() throws {
        let store = self.store()
        store.connection.onChat?(try chat(log(sessionId: "abc", "\(radioFromTwr),\(privateFromApp)")))

        let radio = store.markChatReadCommand(forConversation: ChatMessage.radioConversationKey)
        #expect(radio?.tab == "radio")   // the wire name, not the app's internal key
        #expect(radio?.throughId == 41)

        let privateTab = store.markChatReadCommand(forConversation: "EDDM_APP")
        #expect(privateTab?.tab == "EDDM_APP")
        #expect(privateTab?.throughId == 42)

        // Once read there is nothing left to tell the plugin — otherwise an open tab would send
        // a command on every one-second resend.
        store.markConversationRead("EDDM_APP")
        #expect(store.markChatReadCommand(forConversation: "EDDM_APP") == nil)
    }

    /// A broadcast belongs to the shared frequency tab, the way protocol.md and the Android
    /// client have it. In its own tab it would mark the wrong tab read on the plugin and leave
    /// the radio tab unread on the pilot's other device.
    @Test func broadcastsCountAsRadioTraffic() throws {
        let broadcast = """
            {"id":50,"channel":"broadcast","direction":"incoming","peer":"EDDM_ATIS","text":"runway change","timestamp":"2026-10-12T10:05:00Z"}
            """
        let store = self.store()
        store.connection.onChat?(try chat(log(sessionId: "abc", broadcast)))
        #expect(store.unreadByConversation[ChatMessage.radioConversationKey] == 1)
        #expect(store.unreadByConversation["EDDM_ATIS"] == nil)
        #expect(store.markChatReadCommand(forConversation: ChatMessage.radioConversationKey)?.tab == "radio")
    }

    /// A message landing in the tab already on screen is read where it lands — and the plugin
    /// has to be told, or that message stays unread on the other device.
    @Test func arrivingInTheOpenTabAdvancesTheWatermark() throws {
        let later = """
            {"id":43,"channel":"radio","direction":"incoming","from":"EDDM_TWR","text":"line up","timestamp":"2026-10-12T10:03:00Z"}
            """
        let store = self.store()
        store.chatPanelVisible = true
        store.connection.onChat?(try chat(log(sessionId: "abc", radioFromTwr)))
        store.markConversationRead(ChatMessage.radioConversationKey)
        #expect(store.unreadChatCount == 0)

        store.connection.onChat?(try chat(log(sessionId: "abc", "\(radioFromTwr),\(later)")))
        #expect(store.unreadChatCount == 0)
        #expect(store.markChatReadCommand(forConversation: ChatMessage.radioConversationKey) == nil)
    }

    /// Own replies are not unread — true in both paths, and easy to lose when unread
    /// becomes a derivation over the whole log rather than a counter.
    @Test func ownRepliesAreNeverUnread() throws {
        let store = self.store()
        store.connection.onChat?(try chat(log(sessionId: "abc", """
            {"id":7,"channel":"private","direction":"outgoing","peer":"EDDM_APP","text":"wilco","timestamp":"2026-10-12T10:02:00Z"}
            """)))
        #expect(store.unreadChatCount == 0)
    }
}
