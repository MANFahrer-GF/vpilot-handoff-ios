import Testing
import Foundation
@testable import Handoff

/// gallery/12-unread-messages.png: per-conversation badges, with directed messages
/// standing out from ambient frequency chatter. Counting them all into one number
/// (or clearing them all at once) loses exactly the distinction that makes the
/// feature useful in flight.
@MainActor
struct UnreadTrackingTests {
    private func store() -> AppStore {
        TestDefaults.installOnce()
        let store = AppStore()
        store.connect(host: "10.0.0.77", port: 48765)
        store.disconnect()
        return store
    }

    private func chat(_ messagesJSON: String) -> ChatMessagePayload {
        try! JSONDecoder().decode(
            ChatMessagePayload.self,
            from: Data("{\"messages\":[\(messagesJSON)]}".utf8)
        )
    }

    private let radioOne = """
    {"channel":"radio","direction":"incoming","from":"EDDF_TWR","text":"traffic on final",
     "frequencies":[19400],"timestamp":"2026-08-07T10:00:00Z"}
    """
    private let privateOne = """
    {"channel":"private","direction":"incoming","peer":"EDDF_TWR","text":"contact me",
     "timestamp":"2026-08-07T10:01:00Z"}
    """
    private let ownReply = """
    {"channel":"private","direction":"outgoing","peer":"EDDF_TWR","text":"wilco",
     "timestamp":"2026-08-07T10:02:00Z"}
    """

    @Test func theInitialSnapshotIsNotCountedAsUnread() {
        let store = store()
        store.connection.onChat?(chat("\(radioOne),\(privateOne)"))
        // The first payload after connecting is the existing log, not news.
        #expect(store.unreadChatCount == 0)
    }

    @Test func laterMessagesCountAgainstTheirOwnConversation() {
        let store = store()
        store.connection.onChat?(chat(radioOne))
        store.connection.onChat?(chat("\(radioOne),\(privateOne)"))

        #expect(store.unreadByConversation["EDDF_TWR"] == 1)
        #expect(store.unreadByConversation[ChatMessage.radioConversationKey] ?? 0 == 0)
        #expect(store.unreadChatCount == 1)
    }

    @Test func readingOneConversationLeavesTheOthersAlone() {
        let store = store()
        store.connection.onChat?(chat(radioOne))
        store.connection.onChat?(chat("\(radioOne),\(privateOne)"))
        store.chatPanelVisible = true

        store.markConversationRead(ChatMessage.radioConversationKey)
        // Glancing at the frequency must not silently clear a private message.
        #expect(store.unreadByConversation["EDDF_TWR"] == 1)

        store.markConversationRead("EDDF_TWR")
        #expect(store.unreadChatCount == 0)
    }

    @Test func messagesArrivingInTheOpenConversationAreAlreadyRead() {
        let store = store()
        store.connection.onChat?(chat(radioOne))
        store.chatPanelVisible = true
        store.markConversationRead("EDDF_TWR")

        store.connection.onChat?(chat("\(radioOne),\(privateOne)"))
        #expect(store.unreadChatCount == 0)
    }

    @Test func ownRepliesNeverCountAsUnread() {
        let store = store()
        store.connection.onChat?(chat(radioOne))
        store.connection.onChat?(chat("\(radioOne),\(ownReply)"))
        #expect(store.unreadChatCount == 0)
    }

    @Test func directedTrafficIsDistinguishedFromFrequencyChatter() {
        let store = store()
        store.connection.onChat?(chat(radioOne))

        let secondRadio = radioOne.replacingOccurrences(of: "10:00:00", with: "10:05:00")
        store.connection.onChat?(chat("\(radioOne),\(secondRadio)"))
        // Radio chatter alone must not trigger the directed-message treatment.
        #expect(store.unreadChatCount == 1)
        #expect(!store.hasUnreadDirectedMessage)

        store.connection.onChat?(chat("\(radioOne),\(secondRadio),\(privateOne)"))
        #expect(store.hasUnreadDirectedMessage)
    }

    @Test func reconnectingClearsStaleBadges() {
        let store = store()
        store.connection.onChat?(chat(radioOne))
        store.connection.onChat?(chat("\(radioOne),\(privateOne)"))
        #expect(store.unreadChatCount == 1)

        store.connect(host: "10.0.0.77", port: 48765)
        #expect(store.unreadChatCount == 0)
        store.disconnect()
    }

    @Test func conversationKeySeparatesRadioFromPrivate() throws {
        let radio = try JSONDecoder().decode(ChatMessage.self, from: Data(radioOne.utf8))
        let direct = try JSONDecoder().decode(ChatMessage.self, from: Data(privateOne.utf8))
        #expect(radio.conversationKey == ChatMessage.radioConversationKey)
        #expect(direct.conversationKey == "EDDF_TWR")
        // A station can talk on both channels; those must not share a badge.
        #expect(radio.conversationKey != direct.conversationKey)
    }
}
