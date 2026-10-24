import Testing
import Foundation
@testable import Handoff

/// The plugin resends full state constantly and adds optional fields between
/// versions (protocol.md's Compatibility section). HandoffConnection decodes with
/// `try?`, so any model that throws on a missing field silently drops the whole
/// message -- which is exactly how the chat panel once ended up permanently empty.
/// These tests pin that behaviour down per message type.
struct ProtocolDecodingTests {
    private func decode<T: Decodable>(_ json: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    // MARK: chat

    @Test func chatDecodesWithoutSelcalAlerts() throws {
        let payload = try decode(
            """
            {"type":"chat","messages":[
              {"channel":"radio","direction":"incoming","from":"EDDF_TWR","text":"hi",
               "frequencies":[19400],"timestamp":"2026-08-07T10:00:00Z"}
            ]}
            """,
            as: ChatMessagePayload.self
        )
        #expect(payload.messages.count == 1)
        #expect(payload.selcalAlerts.isEmpty)
    }

    @Test func chatDecodesWithEmptyObject() throws {
        let payload = try decode(#"{"type":"chat"}"#, as: ChatMessagePayload.self)
        #expect(payload.messages.isEmpty)
        #expect(payload.selcalAlerts.isEmpty)
    }

    @Test func chatMessageIdentityIsContentDerivedNotRandom() throws {
        let json = """
        {"channel":"private","direction":"incoming","peer":"EDDF_TWR","text":"cleared",
         "timestamp":"2026-08-07T10:00:00Z"}
        """
        let first = try decode(json, as: ChatMessage.self)
        let second = try decode(json, as: ChatMessage.self)
        // A per-decode UUID would make every 1s resend look like brand-new rows.
        #expect(first.id == second.id)
    }

    @Test func radioMessageHeaderShowsFrequencyAndSender() throws {
        let message = try decode(
            """
            {"channel":"radio","direction":"incoming","from":"EDDF_TWR","text":"hi",
             "frequencies":[19400],"timestamp":"2026-08-07T10:00:00Z"}
            """,
            as: ChatMessage.self
        )
        #expect(message.headerLabel == "119.400")
        #expect(message.senderLabel == "EDDF_TWR")
    }

    @Test func outgoingRadioMessageHasNoSenderLabel() throws {
        let message = try decode(
            """
            {"channel":"radio","direction":"outgoing","text":"wilco",
             "frequencies":[19400],"timestamp":"2026-08-07T10:00:00Z"}
            """,
            as: ChatMessage.self
        )
        #expect(message.senderLabel == nil)
    }

    @Test func chatMessageFlagsMissingTextField() throws {
        let message = try decode(
            """
            {"channel":"private","direction":"incoming","peer":"EDDF_TWR",
             "timestamp":"2026-08-07T10:00:00Z"}
            """,
            as: ChatMessage.self
        )
        #expect(message.textWasMissing == true)
        #expect(message.text == "")
    }

    @Test func chatMessageFlagsNullTextField() throws {
        let message = try decode(
            """
            {"channel":"private","direction":"incoming","peer":"EDDF_TWR","text":null,
             "timestamp":"2026-08-07T10:00:00Z"}
            """,
            as: ChatMessage.self
        )
        #expect(message.textWasMissing == true)
        #expect(message.text == "")
    }

    @Test func chatMessageWithRealTextIsNotFlagged() throws {
        let message = try decode(
            """
            {"channel":"private","direction":"incoming","peer":"EDDF_TWR","text":"cleared",
             "timestamp":"2026-08-07T10:00:00Z"}
            """,
            as: ChatMessage.self
        )
        #expect(message.textWasMissing == false)
        #expect(message.text == "cleared")
    }

    @Test func timestampParsesWithAndWithoutFractionalSeconds() {
        #expect(Date.fromHandoffTimestamp("2026-08-07T10:00:00Z") != nil)
        #expect(Date.fromHandoffTimestamp("2026-08-07T10:00:00.123Z") != nil)
        #expect(Date.fromHandoffTimestamp("nonsense") == nil)
    }

    // MARK: radioState

    @Test func radioStateDecodesWithAllFrequenciesNull() throws {
        let state = try decode(
            """
            {"type":"radioState","com1Frequency":null,"com2Frequency":null,
             "com1StandbyFrequency":null,"com2StandbyFrequency":null,
             "modeCEnabled":false,"transponderCode":null,
             "com1TransmitEnabled":false,"com2TransmitEnabled":false,
             "com1ReceiveEnabled":false,"com2ReceiveEnabled":false}
            """,
            as: RadioState.self
        )
        #expect(state.com1Frequency == nil)
        #expect(state.modeCEnabled == false)
    }

    @Test func radioStateDecodesWhenBooleanFieldsAreMissing() throws {
        let state = try decode(#"{"type":"radioState","com1Frequency":19400}"#, as: RadioState.self)
        #expect(state.com1Frequency == 19400)
        #expect(state.com1TransmitEnabled == false)
        #expect(state.com2ReceiveEnabled == false)
    }

    // MARK: controllers

    @Test func controllerDecodesWithOnlyRequiredFields() throws {
        let controller = try decode(
            #"{"callsign":"EDDF_TWR","frequency":19400}"#,
            as: Controller.self
        )
        #expect(controller.callsign == "EDDF_TWR")
        #expect(controller.isCurrent == false)
        #expect(controller.debug == nil)
        #expect(controller.stationName == nil)
    }

    @Test func controllersMessageSurvivesUnknownFutureFields() throws {
        let message = try decode(
            """
            {"type":"controllers","etaMinutes":12,"somethingNewFromAFuturePlugin":true,
             "controllers":[{"callsign":"EDDF_TWR","frequency":19400,"brandNewFlag":true}]}
            """,
            as: ControllersMessage.self
        )
        #expect(message.controllers.count == 1)
        #expect(message.etaMinutes == 12)
    }

    /// Plugin v0.6.0 (issue #127) moved the ETA from the message onto each
    /// controller. Both shapes have to decode: the app can meet either plugin.
    @Test func etaDecodesPerControllerAndFromTheOlderMessageLevelField() throws {
        let perController = try decode(
            """
            {"type":"controllers","controllers":[
              {"callsign":"EDMM_CTR","frequency":19400,"isLikelyNext":true,"etaMinutes":7},
              {"callsign":"EDDM_TWR","frequency":19410}]}
            """,
            as: ControllersMessage.self
        )
        #expect(perController.etaMinutes == nil)
        #expect(perController.controllers[0].etaMinutes == 7)
        #expect(perController.controllers[1].etaMinutes == nil)

        let legacy = try decode(
            """
            {"type":"controllers","etaMinutes":12,
             "controllers":[{"callsign":"EDDF_TWR","frequency":19400}]}
            """,
            as: ControllersMessage.self
        )
        #expect(legacy.etaMinutes == 12)
        #expect(legacy.controllers[0].etaMinutes == nil)
    }

    /// Issue #151 upstream moved a known controller's "contact me" out of the chat
    /// log and onto the controller row. If this field went unread, the request would
    /// still flash the row but the pilot could no longer see what was asked.
    @Test func contactMeTextAndChatIdsDecode() throws {
        let controllers = try decode("""
            {"type":"controllers","controllers":[
              {"callsign":"EDDM_TWR","frequency":19400,"isContactMe":true,
               "contactMeText":"DLH4TK contact me on 118.700"},
              {"callsign":"EDDM_APP","frequency":19410}]}
            """, as: ControllersMessage.self)
        #expect(controllers.controllers[0].contactMeText == "DLH4TK contact me on 118.700")
        #expect(controllers.controllers[1].contactMeText == nil)

        let chat = try decode("""
            {"type":"chat","sessionId":"b3f1c2e0","messages":[
              {"id":41,"channel":"radio","direction":"incoming","from":"EDDM_TWR","text":"hi","timestamp":"2026-10-12T10:00:00Z"}]}
            """, as: ChatMessagePayload.self)
        #expect(chat.sessionId == "b3f1c2e0")
        #expect(chat.messages[0].messageId == 41)
        #expect(chat.messages[0].readStateTab == "radio")

        // An older plugin sends neither, and that absence is load-bearing: it selects
        // the app's own local unread tracking.
        let legacy = try decode("""
            {"type":"chat","messages":[
              {"channel":"private","direction":"incoming","peer":"EDDM_APP","text":"hi","timestamp":"2026-10-12T10:00:00Z"}]}
            """, as: ChatMessagePayload.self)
        #expect(legacy.sessionId == nil)
        #expect(legacy.messages[0].messageId == nil)
        #expect(legacy.messages[0].readStateTab == "EDDM_APP")

        let readState = try decode("""
            {"type":"chatReadState","sessionId":"b3f1c2e0","readThrough":{"radio":38,"EGLL_TWR":41}}
            """, as: ChatReadStateMessage.self)
        #expect(readState.readThrough["radio"] == 38)
        #expect(readState.readThrough["EGLL_TWR"] == 41)
    }

    @Test func subsystemStatusDecodesWithoutOptionalDebugBlock() throws {
        let status = try decode(
            """
            {"type":"subsystemStatus","radioHostConnected":true,"simulatorConnected":true,
             "vatsimDataFeedConnected":true,"simbriefFetched":false,"pluginVersion":"0.2.0"}
            """,
            as: SubsystemStatus.self
        )
        #expect(status.pluginVersion == "0.2.0")
        #expect(status.updateInterval == nil)
        #expect(status.systemsDebug == nil)
    }

    @Test func nearbyAircraftDecodesWithoutAircraftKey() throws {
        let message = try decode(#"{"type":"nearbyAircraft"}"#, as: NearbyAircraftMessage.self)
        #expect(message.aircraft.isEmpty)
    }

    // MARK: new-station blink (upstream issue #186, plugin 0.8.0)

    @Test func newStationFlagDecodesAndDefaultsToFalse() throws {
        let message = try decode(
            #"{"type":"controllers","controllers":[{"callsign":"LOWW_GND","frequency":21700,"isNewStation":true},{"callsign":"LOWW_TWR","frequency":19400}]}"#,
            as: ControllersMessage.self
        )
        #expect(message.controllers.first?.isNewStation == true)
        // An older plugin never sends the field: no blink, and no failed decode.
        #expect(message.controllers.last?.isNewStation == false)
    }

    /// Blinks while the plugin holds the flag -- but not once the pilot tapped it away, and not
    /// for the station that is already tuned, as on Android.
    @Test func aNewStationBlinksUntilTappedOrTuned() throws {
        let message = try decode(
            #"{"type":"controllers","controllers":[{"callsign":"LOWW_GND","frequency":21700,"isNewStation":true},{"callsign":"LOWW_DEL","frequency":22200,"isNewStation":true,"isCurrent":true},{"callsign":"LOWW_TWR","frequency":19400}]}"#,
            as: ControllersMessage.self
        )
        let new = message.controllers[0], tuned = message.controllers[1], old = message.controllers[2]
        #expect(new.blinksAsNewStation(dismissed: false))
        #expect(new.blinksAsNewStation(dismissed: true) == false)
        #expect(tuned.blinksAsNewStation(dismissed: false) == false)
        #expect(old.blinksAsNewStation(dismissed: false) == false)
    }
}
