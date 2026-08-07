#if DEBUG
import Foundation

/// Sample state for verifying layout without a running plugin. Gated behind an
/// explicit `-handoffDemoData` launch argument, so it can never appear during
/// normal use -- not even in a Debug build installed on a real iPad.
enum DemoData {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-handoffDemoData")
    }

    @MainActor
    static func apply(to store: AppStore) {
        guard isEnabled else { return }
        store.controllers = decode(controllersJSON, as: ControllersMessage.self)?.controllers ?? []
        store.etaMinutes = 14
        if let chat = decode(chatJSON, as: ChatMessagePayload.self) {
            store.chatMessages = chat.messages
            store.selcalAlerts = chat.selcalAlerts
        }
        store.radioState = decode(radioJSON, as: RadioState.self)
        store.flightPlan = decode(flightPlanJSON, as: FlightPlanMessage.self)
        store.subsystemStatus = decode(subsystemJSON, as: SubsystemStatus.self)
        store.nearbyAircraft = decode(nearbyJSON, as: NearbyAircraftMessage.self)?.aircraft ?? []
        store.unreadByConversation = [ChatMessage.radioConversationKey: 1, "LOWW_TWR": 2]
    }

    private static func decode<T: Decodable>(_ json: String, as type: T.Type) -> T? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static let controllersJSON = """
    {"type":"controllers","etaMinutes":14,"controllers":[
      {"callsign":"LOWW_TWR","frequency":19400,"cid":1,"name":"A. Muster","facility":4,"rating":3,
       "stationName":"Wien Tower","textAtis":["Wien Tower DCL LOWW","My active sector vats.im/lovv"],
       "isContactMe":true,"isHighlighted":true},
      {"callsign":"LOWW_APP","frequency":34675,"cid":2,"name":"B. Beispiel","facility":5,"rating":4,
       "stationName":"Wien Radar","isNext":true,"isHighlighted":true},
      {"callsign":"LOWW_D_ATIS","frequency":21730,"facility":0,
       "stationName":"Wien Departure ATIS","isHighlighted":true},
      {"callsign":"LOWW_A_ATIS","frequency":22955,"facility":0,
       "stationName":"Wien Arrival ATIS","isHighlighted":true},
      {"callsign":"LOWW_GND","frequency":21600,"cid":6,"name":"C. Muster","facility":3,"rating":5,
       "stationName":"Wien Ground","isHighlighted":true},
      {"callsign":"LOWW_DEL","frequency":22125,"cid":7,"name":"D. Beispiel","facility":2,"rating":3,
       "stationName":"Wien Delivery","isCurrent":true,"isHighlighted":true},
      {"callsign":"LKAA_CTR","frequency":27125,"cid":3,"name":"E. Muster","facility":6,"rating":5,
       "stationName":"Praha Radar"},
      {"callsign":"LHCC_CTR","frequency":20380,"cid":4,"name":"F. Beispiel","facility":6,"rating":5,
       "stationName":"Budapest Control","isStandbyTuned":true},
      {"callsign":"EDMM_BBG_CTR","frequency":33615,"cid":5,"name":"G. Muster","facility":6,"rating":5,
       "stationName":"Muenchen Radar","isPinned":true},
      {"callsign":"EDWW_MAR_CTR","frequency":36050,"cid":8,"name":"H. Beispiel","facility":6,"rating":5,
       "stationName":"Bremen Radar"},
      {"callsign":"EPWW_ST_CTR","frequency":23625,"cid":9,"name":"I. Muster","facility":6,"rating":4,
       "stationName":"Warszawa Radar","isSelcalActive":true}
    ]}
    """

    private static let chatJSON = """
    {"type":"chat","messages":[
      {"channel":"radio","direction":"incoming","from":"LOWW_TWR","text":"out of cockpit 10 min",
       "frequencies":[22800],"timestamp":"2026-08-07T16:59:00Z"},
      {"channel":"radio","direction":"incoming","from":"LKAA_CTR",
       "text":"LKPR TFC descending to 4000ft via VLM6P for ILS 12","frequencies":[22800],
       "timestamp":"2026-08-07T17:08:00Z"},
      {"channel":"private","direction":"outgoing","peer":"LOWW_TWR","text":"wilco, holding short 34",
       "timestamp":"2026-08-07T17:09:10Z"},
      {"channel":"private","direction":"incoming","peer":"LOWW_TWR","text":"line up and wait runway 34",
       "timestamp":"2026-08-07T17:09:40Z"}
    ],"selcalAlerts":[{"from":"EPWW_ST_CTR","frequencies":[23625],"timestamp":"2026-08-07T17:05:00Z"}]}
    """

    private static let radioJSON = """
    {"type":"radioState","com1Frequency":22800,"com2Frequency":21500,
     "com1StandbyFrequency":22800,"com2StandbyFrequency":24850,"modeCEnabled":true,
     "transponderCode":2000,"com1TransmitEnabled":true,"com2TransmitEnabled":false,
     "com1ReceiveEnabled":true,"com2ReceiveEnabled":true}
    """

    private static let flightPlanJSON = """
    {"type":"flightPlan","simbriefCallsign":"EIDGX","simbriefOrigin":"LOWW",
     "simbriefDestination":"EDDF","simbriefAlternate":"EDDL","vatsimCallsign":"EIDGX",
     "vatsimOrigin":null,"vatsimDestination":null,"originMismatch":false,"vatsimCidMismatch":false}
    """

    private static let subsystemJSON = """
    {"type":"subsystemStatus","radioHostConnected":true,"simulatorConnected":true,
     "vatsimDataFeedConnected":true,"simbriefFetched":true,"pluginVersion":"0.2.0",
     "updateInterval":"normal"}
    """

    private static let nearbyJSON = """
    {"type":"nearbyAircraft","aircraft":[
      {"callsign":"AUA270A","aircraftType":"A320","distanceNm":1.3},
      {"callsign":"ENT4TF","aircraftType":"B738","distanceNm":9.6},
      {"callsign":"AUA82","aircraftType":"A320","distanceNm":10.2},
      {"callsign":"OKI1035","aircraftType":"A21N","distanceNm":15.9}
    ]}
    """
}
#endif
