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
}
