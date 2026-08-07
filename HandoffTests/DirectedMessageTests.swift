import Testing
import Foundation
@testable import Handoff

/// A call on the frequency that names this pilot has to stand out from the chatter
/// around it -- that's the whole reason to have the panel open on approach. Matching
/// it by naive substring would light up on the wrong traffic, which is worse than
/// not highlighting at all.
struct DirectedMessageTests {
    private func radio(_ text: String, outgoing: Bool = false) -> ChatMessage {
        let json = """
        {"channel":"radio","direction":"\(outgoing ? "outgoing" : "incoming")",
         "from":"EDDF_TWR","text":"\(text)","frequencies":[19400],
         "timestamp":"2026-08-07T10:00:00Z"}
        """
        return try! JSONDecoder().decode(ChatMessage.self, from: Data(json.utf8))
    }

    private func privateMessage(incoming: Bool = true) -> ChatMessage {
        let json = """
        {"channel":"private","direction":"\(incoming ? "incoming" : "outgoing")",
         "peer":"EDDF_TWR","text":"contact me","timestamp":"2026-08-07T10:00:00Z"}
        """
        return try! JSONDecoder().decode(ChatMessage.self, from: Data(json.utf8))
    }

    @Test func aCallNamingUsIsDirected() {
        #expect(radio("DLH123 descend FL100").isDirectedAtUs(ownCallsign: "DLH123"))
        // Case and punctuation shouldn't matter -- controllers type both ways.
        #expect(radio("dlh123, contact Langen 128.950").isDirectedAtUs(ownCallsign: "DLH123"))
        #expect(radio("traffic in sight, DLH123?").isDirectedAtUs(ownCallsign: "DLH123"))
    }

    @Test func chatterAboutOtherTrafficIsNotDirected() {
        #expect(!radio("BAW456 descend FL100").isDirectedAtUs(ownCallsign: "DLH123"))
        #expect(!radio("wind 270 at 12").isDirectedAtUs(ownCallsign: "DLH123"))
    }

    @Test func aLongerCallsignDoesNotMatchOurShorterOne() {
        // The failure a substring match would produce: every call to DLH1234 would
        // light up for DLH123.
        #expect(!radio("DLH1234 descend FL100").isDirectedAtUs(ownCallsign: "DLH123"))
        #expect(!radio("XDLH123 descend").isDirectedAtUs(ownCallsign: "DLH123"))
    }

    @Test func ourOwnTransmissionsAreNeverDirectedAtUs() {
        #expect(!radio("DLH123 request descent", outgoing: true).isDirectedAtUs(ownCallsign: "DLH123"))
        #expect(!privateMessage(incoming: false).isDirectedAtUs(ownCallsign: "DLH123"))
    }

    @Test func everyIncomingPrivateMessageIsDirected() {
        // Private traffic is aimed at us by definition -- no callsign needed.
        #expect(privateMessage().isDirectedAtUs(ownCallsign: "DLH123"))
        #expect(privateMessage().isDirectedAtUs(ownCallsign: nil))
    }

    @Test func withoutAKnownCallsignRadioChatterStaysNeutral() {
        // Before a flight plan exists there is nothing to match, and guessing would
        // highlight arbitrary traffic.
        #expect(!radio("DLH123 descend FL100").isDirectedAtUs(ownCallsign: nil))
        #expect(!radio("DLH123 descend FL100").isDirectedAtUs(ownCallsign: ""))
    }
}

@MainActor
struct OwnCallsignTests {
    private func plan(_ json: String) -> FlightPlanMessage {
        try! JSONDecoder().decode(FlightPlanMessage.self, from: Data(json.utf8))
    }

    @Test func prefersTheFiledVatsimCallsign() {
        TestDefaults.installOnce()
        let store = AppStore()
        store.flightPlan = plan(#"{"simbriefCallsign":"DLH999","vatsimCallsign":"DLH123"}"#)
        // The VATSIM one is what's actually on the network; SimBrief may be stale.
        #expect(store.ownCallsign == "DLH123")
    }

    @Test func fallsBackToSimbriefBeforeConnecting() {
        TestDefaults.installOnce()
        let store = AppStore()
        store.flightPlan = plan(#"{"simbriefCallsign":"DLH999","vatsimCallsign":null}"#)
        #expect(store.ownCallsign == "DLH999")
    }

    @Test func isNilWithNoFlightPlanAtAll() {
        TestDefaults.installOnce()
        let store = AppStore()
        store.flightPlan = nil
        #expect(store.ownCallsign == nil)
    }
}

@MainActor
struct DirectedUnreadTests {
    private func store(callsign: String) -> AppStore {
        TestDefaults.installOnce()
        let store = AppStore()
        store.connect(host: "10.0.0.88", port: 48765)
        store.disconnect()
        store.flightPlan = try! JSONDecoder().decode(
            FlightPlanMessage.self,
            from: Data("{\"vatsimCallsign\":\"\(callsign)\"}".utf8)
        )
        return store
    }

    private func chat(_ texts: [String]) -> ChatMessagePayload {
        let messages = texts.enumerated().map { index, text in
            """
            {"channel":"radio","direction":"incoming","from":"EDDF_TWR","text":"\(text)",
             "frequencies":[19400],"timestamp":"2026-08-07T10:0\(index):00Z"}
            """
        }.joined(separator: ",")
        return try! JSONDecoder().decode(
            ChatMessagePayload.self, from: Data("{\"messages\":[\(messages)]}".utf8)
        )
    }

    @Test func aRadioCallNamingUsCountsAsDirected() {
        let store = store(callsign: "DLH123")
        store.connection.onChat?(chat(["wind 270 at 12"]))
        store.connection.onChat?(chat(["wind 270 at 12", "DLH123 descend FL100"]))
        #expect(store.hasUnreadDirectedMessage)
    }

    @Test func plainChatterDoesNot() {
        let store = store(callsign: "DLH123")
        store.connection.onChat?(chat(["wind 270 at 12"]))
        store.connection.onChat?(chat(["wind 270 at 12", "BAW456 descend FL100"]))
        #expect(store.unreadChatCount == 1)
        #expect(!store.hasUnreadDirectedMessage)
    }

    @Test func theFlagSurvivesLaterChatterBehindIt() {
        let store = store(callsign: "DLH123")
        store.connection.onChat?(chat(["wind 270 at 12"]))
        store.connection.onChat?(chat(["wind 270 at 12", "DLH123 descend FL100"]))
        store.connection.onChat?(chat(["wind 270 at 12", "DLH123 descend FL100", "BAW456 turn left"]))
        // The call is still unread; burying it under chatter must not clear it.
        #expect(store.hasUnreadDirectedMessage)
    }

    @Test func readingTheFrequencyClearsIt() {
        let store = store(callsign: "DLH123")
        store.connection.onChat?(chat(["wind 270 at 12"]))
        store.connection.onChat?(chat(["wind 270 at 12", "DLH123 descend FL100"]))
        store.chatPanelVisible = true
        store.markConversationRead(ChatMessage.radioConversationKey)
        #expect(!store.hasUnreadDirectedMessage)
    }
}
