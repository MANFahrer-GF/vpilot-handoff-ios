import Testing
import Foundation
@testable import Handoff

/// Connecting to and disconnecting from VATSIM from the tablet (upstream issue #171, plugin
/// 0.8.0). The input rules are ported from the Android client; the store part proves what goes on
/// the wire and that only this device's own answer is followed.
@MainActor
@Suite(.serialized)
struct NetworkConnectTests {
    private func store() -> AppStore {
        TestDefaults.installOnce()
        let store = AppStore()
        store.connect(host: "127.0.0.1", port: 48765)
        store.disconnect()
        return store
    }

    private func progress(_ id: String, _ status: String, finished: Bool, success: Bool? = nil) -> String {
        let successPart = success.map { ",\"success\":\($0)" } ?? ""
        return #"{"type":"operationProgress","operationId":"\#(id)","status":"\#(status)","finished":\#(finished)\#(successPart)}"#
    }

    // MARK: Rules

    /// An older plugin ignores the commands and never answers, so the controls must stay hidden
    /// there -- compared as numbers, so 0.10 counts as newer than 0.9.
    @Test func theControlsNeedPlugin080OrNewer() {
        #expect(NetworkConnect.isSupported(pluginVersion: "0.8.0"))
        #expect(NetworkConnect.isSupported(pluginVersion: "0.8.1"))
        #expect(NetworkConnect.isSupported(pluginVersion: "0.10.0"))
        #expect(NetworkConnect.isSupported(pluginVersion: "1.0"))
        // A pre-release of 0.8.0 may predate the finished commands; one of a later version doesn't.
        #expect(NetworkConnect.isSupported(pluginVersion: "0.8.0-beta") == false)
        #expect(NetworkConnect.isSupported(pluginVersion: "0.9.0-rc1"))
        #expect(NetworkConnect.isSupported(pluginVersion: "0.7.0") == false)
        #expect(NetworkConnect.isSupported(pluginVersion: "0.7.9") == false)
        #expect(NetworkConnect.isSupported(pluginVersion: "0.8") )
        #expect(NetworkConnect.isSupported(pluginVersion: "?") == false)
        #expect(NetworkConnect.isSupported(pluginVersion: nil) == false)
    }

    @Test func theFormSaysWhatIsMissingFirst() {
        #expect(NetworkConnect.blockedReason(callsign: "", aircraftType: "A320", observer: false) == "Enter a callsign.")
        #expect(NetworkConnect.blockedReason(callsign: "DLH 12", aircraftType: "A320", observer: false)
            == "Callsign can only use letters, digits, - and _ (max 10).")
        #expect(NetworkConnect.blockedReason(callsign: "dlh12", aircraftType: "", observer: false) == "Enter the aircraft type.")
        #expect(NetworkConnect.blockedReason(callsign: "DLH12", aircraftType: "A3200", observer: false)
            == "Aircraft type is the 2-4 character ICAO code, e.g. A320.")
        #expect(NetworkConnect.blockedReason(callsign: " dlh12 ", aircraftType: "a20n", observer: false) == nil)
        // An observer needs nothing but a callsign.
        #expect(NetworkConnect.blockedReason(callsign: "LOWW_OBS", aircraftType: "", observer: true) == nil)
    }

    /// SELCAL only ever warns: vPilot decides itself, and refuses with its own message.
    @Test func selcalIsFormattedAndOnlyWarnedAbout() {
        #expect(NetworkConnect.formatSelcal("abcd") == "AB-CD")
        #expect(NetworkConnect.formatSelcal("AB-CD") == "AB-CD")
        #expect(NetworkConnect.formatSelcal("ab c") == "AB-C")
        #expect(NetworkConnect.formatSelcal("ab") == "AB")
        #expect(NetworkConnect.cleanSelcal("ab-cd-ef") == "ABCD")
        #expect(NetworkConnect.selcalWarning("") == nil)
        #expect(NetworkConnect.selcalWarning("BCFH") == nil)
        #expect(NetworkConnect.selcalWarning("ABC") == "SELCAL is normally 4 characters, e.g. AB-CD.")
        #expect(NetworkConnect.selcalWarning("IAZ9") == "vPilot currently doesn't support SELCAL with digits (SELCAL32).")
        #expect(NetworkConnect.selcalWarning("ABXZ") == "Unusual SELCAL: standard codes use the letters A-S without I, N and O.")
        #expect(NetworkConnect.selcalWarning("AABC") == "Unusual SELCAL: standard codes don't repeat a letter.")
        #expect(NetworkConnect.selcalWarning("BADC") == "Unusual SELCAL: standard codes have each pair in alphabetical order, e.g. AB-CD.")
        // A warning never blocks sending.
        #expect(NetworkConnect.command(operationId: "x", callsign: "DLH12", aircraftType: "A320", selcal: "IAZ9", observer: false) != nil)
    }

    @Test func theFlightPlanCarriesWhatPrefillsTheForm() throws {
        let plan = try JSONDecoder().decode(FlightPlanMessage.self, from: Data(#"""
            {"type":"flightPlan","simbriefCallsign":"EIDGX","simbriefAircraftType":"A320","simbriefSelcal":"ABCD","vatsimCallsign":null}
            """#.utf8))
        #expect(plan.simbriefAircraftType == "A320")
        #expect(plan.simbriefSelcal == "ABCD")
        // An older plugin sends neither, and the plan must still decode.
        let old = try JSONDecoder().decode(FlightPlanMessage.self, from: Data(#"{"type":"flightPlan"}"#.utf8))
        #expect(old.simbriefAircraftType == nil)
    }

    // MARK: Store and wire

    /// The exact shape protocol.md asks for, as it leaves the app: normalised fields, a dashed
    /// SELCAL, an id this device minted -- and nothing beyond the callsign for an observer.
    @Test func connectAndDisconnectGoOnTheWire() throws {
        let store = store()
        var sent: [String] = []
        store.connection.onDidEncodeCommand = { sent.append($0) }

        #expect(store.connectToNetwork(callsign: " eidgx", aircraftType: "a320", selcal: "abcd", observer: false))
        let connect = try #require(sent.last)
        let fields = try #require(try JSONSerialization.jsonObject(with: Data(connect.utf8)) as? [String: Any])
        #expect(fields["type"] as? String == "connectNetwork")
        #expect(fields["callsign"] as? String == "EIDGX")
        #expect(fields["aircraftType"] as? String == "A320")
        #expect(fields["selcalCode"] as? String == "AB-CD")
        #expect(fields["observer"] as? Bool == false)
        #expect(fields["operationId"] as? String == store.networkRequest?.id)
        #expect(store.networkRequest?.kind == .connect)
        #expect(store.networkRequest?.finished == false)

        // A second tap while waiting sends nothing.
        #expect(store.connectToNetwork(callsign: "EIDGX", aircraftType: "A320", selcal: "", observer: false) == false)
        #expect(sent.count == 1)

        store.clearNetworkRequest()
        store.connectToNetwork(callsign: "LOWW_OBS", aircraftType: "", selcal: "ABCD", observer: true)
        let observer = try #require(try JSONSerialization.jsonObject(with: Data(sent.last!.utf8)) as? [String: Any])
        #expect(observer["observer"] as? Bool == true)
        #expect(observer["aircraftType"] == nil)
        #expect(observer["selcalCode"] == nil)

        store.clearNetworkRequest()
        store.disconnectFromNetwork()
        let disconnect = try #require(try JSONSerialization.jsonObject(with: Data(sent.last!.utf8)) as? [String: Any])
        #expect(disconnect["type"] as? String == "disconnectNetwork")
        #expect(disconnect["operationId"] as? String == store.networkRequest?.id)
    }

    /// `operationProgress` goes to every paired client: another device's connect must not finish
    /// ours, and our own answer arrives through the real message dispatch.
    @Test func onlyThisDevicesOwnAnswerCounts() throws {
        let store = store()
        store.connectToNetwork(callsign: "EIDGX", aircraftType: "A320", selcal: "", observer: false)
        let id = try #require(store.networkRequest?.id)

        store.connection.receiveForTesting(progress("someone-else", "Connected", finished: true, success: true))
        #expect(store.networkRequest?.finished == false)

        store.connection.receiveForTesting(progress(id, "Connecting to VATSIM...", finished: false))
        #expect(store.networkRequest?.status == "Connecting to VATSIM...")
        #expect(store.networkRequest?.finished == false)

        store.connection.receiveForTesting(progress(id, "vPilot isn't connected to the simulator yet.", finished: true, success: false))
        #expect(store.networkRequest?.failed == true)
        #expect(store.networkRequest?.status == "vPilot isn't connected to the simulator yet.")
        // Failed, so a new attempt is allowed.
        #expect(store.connectToNetwork(callsign: "EIDGX", aircraftType: "A320", selcal: "", observer: false))
    }

    /// The shared operation backstop only starts once the plugin has said something. A request it
    /// never answers at all -- an old plugin, a dropped send -- must still end, as a failure.
    @Test func anUnansweredRequestFailsByItself() async throws {
        AppStore.networkRequestTimeoutInterval = .milliseconds(50)
        defer { AppStore.networkRequestTimeoutInterval = .seconds(60) }
        let store = store()
        store.connectToNetwork(callsign: "EIDGX", aircraftType: "A320", selcal: "", observer: false)
        try await Task.sleep(for: .milliseconds(300))
        #expect(store.networkRequest?.failed == true)
        #expect(store.networkRequest?.status.hasPrefix("No answer from vPilot") == true)
    }

    /// Demo mode never reaches a plugin, so it answers its own request -- otherwise a reviewer
    /// tapping Connect would watch a spinner time out.
    @Test func theDemoAnswersItsOwnRequest() async throws {
        let store = store()
        store.demoMode = true
        var sent: [String] = []
        store.connection.onDidEncodeCommand = { sent.append($0) }
        #expect(store.networkControlsSupported)
        #expect(store.isOnNetwork)

        store.disconnectFromNetwork()
        try await Task.sleep(for: .milliseconds(1500))
        #expect(sent.isEmpty)
        #expect(store.networkRequest?.succeeded == true)
        #expect(store.isOnNetwork == false)
    }

    /// The VATSIM refresh is its own command, not the SimBrief one.
    @Test func refreshingTheVatsimFeedSendsItsOwnCommand() {
        let store = store()
        var sent: [String] = []
        store.connection.onDidEncodeCommand = { sent.append($0) }
        store.refreshVatsimFeed()
        #expect(sent == [#"{"type":"refreshVatsimFeed"}"#])
    }
}
