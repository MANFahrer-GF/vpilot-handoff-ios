import Foundation

/// Sample state so the app can be looked at without a plugin: a pilot deciding
/// whether it is worth setting one up, and an App Store reviewer, who has no
/// Windows PC and would otherwise see nothing but "Disconnected".
///
/// This used to be `#if DEBUG` behind a launch argument. It is now reachable from
/// Settings, which is the whole point -- but that makes the marking load-bearing:
/// `AppStore.demoMode` refuses every outbound command and the UI says DEMO in two
/// places, because sample controllers mistaken for real ones is the one failure
/// this feature could cause.
enum DemoData {
    /// Kept for the screenshot tooling, which drives a clean launch straight into
    /// demo mode. Not the route a pilot takes -- that is the Settings switch.
    static var isEnabledAtLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-handoffDemoData")
    }

    #if DEBUG
    /// Extra scenes that need a connection state a demo run can't reach on its own.
    /// `-handoffDemoScene connected|pairing|identity`
    private static var scene: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-handoffDemoScene"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    #endif

    @MainActor
    static func apply(to store: AppStore) {
        store.lastHost = "192.168.1.115"
        #if DEBUG
        // Screenshot tooling only: parks the state machine somewhere a demo run
        // can't reach. Not compiled into a release build.
        switch scene {
        case "connected": store.connection.demoOverride(state: .connected, latencyMs: 12)
        case "pairing": store.connection.demoOverride(state: .awaitingPairingCode)
        case "identity": store.connection.demoOverride(state: .identityChanged)
        default: break
        }
        #endif
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
       "stationName":"Warszawa Radar","isSelcalActive":true},
      {"callsign":"EDDF_DEL","frequency":21750,"cid":10,"name":"J. Muster","facility":2,"rating":2,
       "stationName":"Frankfurt Delivery"},
      {"callsign":"EDDF_GND","frequency":21900,"cid":11,"name":"K. Beispiel","facility":3,"rating":3,
       "stationName":"Frankfurt Ground"},
      {"callsign":"EDDF_TWR","frequency":19900,"cid":12,"name":"L. Muster","facility":4,"rating":5,
       "stationName":"Frankfurt Tower"},
      {"callsign":"EDDF_APP","frequency":20800,"cid":13,"name":"M. Beispiel","facility":5,"rating":5,
       "stationName":"Frankfurt Radar"},
      {"callsign":"EDDM_TWR","frequency":18700,"cid":14,"name":"N. Muster","facility":4,"rating":4,
       "stationName":"Muenchen Tower"},
      {"callsign":"EDDL_TWR","frequency":18300,"cid":15,"name":"O. Beispiel","facility":4,"rating":3,
       "stationName":"Duesseldorf Tower"},
      {"callsign":"EHAM_TWR","frequency":19225,"cid":16,"name":"P. Muster","facility":4,"rating":5,
       "stationName":"Schiphol Tower"},
      {"callsign":"LSZH_TWR","frequency":18100,"cid":17,"name":"Q. Beispiel","facility":4,"rating":4,
       "stationName":"Zurich Tower"},
      {"callsign":"EBBR_APP","frequency":28250,"cid":18,"name":"R. Muster","facility":5,"rating":5,
       "stationName":"Brussels Approach"},
      {"callsign":"EDGG_KTG_CTR","frequency":35925,"cid":19,"name":"S. Beispiel","facility":6,"rating":5,
       "stationName":"Langen Radar"},
      {"callsign":"EDUU_HOF_CTR","frequency":32190,"cid":20,"name":"T. Muster","facility":6,"rating":11,
       "stationName":"Rhein Radar"},
      {"callsign":"LOVV_CTR","frequency":34350,"cid":21,"name":"U. Beispiel","facility":6,"rating":12,
       "stationName":"Wien Radar"}
    ]}
    """

    private static let chatJSON = """
    {"type":"chat","messages":[
      {"channel":"radio","direction":"incoming","from":"LOWW_TWR","text":"out of cockpit 10 min",
       "frequencies":[22800],"timestamp":"2026-08-07T16:59:00Z"},
      {"channel":"radio","direction":"incoming","from":"LKAA_CTR",
       "text":"LKPR TFC descending to 4000ft via VLM6P for ILS 12","frequencies":[22800],
       "timestamp":"2026-08-07T17:08:00Z"},
      {"channel":"radio","direction":"incoming","from":"LOWW_APP",
       "text":"EIDGX descend FL100, direct KONAN","frequencies":[22800],
       "timestamp":"2026-08-07T17:08:40Z"},
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
