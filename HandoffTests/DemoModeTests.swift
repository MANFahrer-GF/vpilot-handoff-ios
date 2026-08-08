import Testing
import Foundation
@testable import Handoff

/// Demo mode exists so the app can be judged without a plugin -- by a pilot
/// deciding whether to set one up, and by an App Store reviewer who has no Windows
/// PC. That makes two properties load-bearing, and neither is visible by looking at
/// the screen:
///
///   1. nothing leaves the device while it is on, and
///   2. leaving it takes the sample data with it.
///
/// The first matters because the sample callsigns are invented. A command escaping
/// to a real plugin from a demo session would tune a real radio to a frequency the
/// pilot never chose.
@MainActor
struct DemoModeTests {
    private func store() -> AppStore {
        TestDefaults.installOnce()
        return AppStore()
    }

    @Test func startsOff() {
        #expect(store().demoMode == false)
    }

    @Test func fillsTheAppWithSampleState() {
        let store = self.store()
        store.demoMode = true
        #expect(!store.controllers.isEmpty)
        #expect(!store.chatMessages.isEmpty)
        #expect(store.radioState != nil)
        #expect(store.flightPlan != nil)
    }

    @Test func leavingClearsEverySampleField() {
        let store = self.store()
        store.demoMode = true
        store.demoMode = false
        #expect(store.controllers.isEmpty)
        #expect(store.chatMessages.isEmpty)
        #expect(store.selcalAlerts.isEmpty)
        #expect(store.nearbyAircraft.isEmpty)
        #expect(store.radioState == nil)
        #expect(store.flightPlan == nil)
        #expect(store.subsystemStatus == nil)
        #expect(store.etaMinutes == nil)
        #expect(store.unreadChatCount == 0)
    }

    /// The state machine never leaves `.disconnected`, so `send` has no socket to
    /// hand anything to -- but that is a coincidence of there being no plugin, not a
    /// guarantee. The guarantee is the `demoMode` check in `AppStore.send`, and what
    /// this pins is that every command still routes through it: a failed send raises
    /// `onSendFailure`, so a command that reached the connection would set
    /// `lastSendError`. Nothing here may.
    @Test func noCommandReachesTheConnection() {
        let store = self.store()
        store.demoMode = true
        store.lastSendError = nil

        store.setCom1Frequency(121.5)
        store.setCom2Frequency(122.8)
        store.setCom1StandbyFrequency(118.7)
        store.setCom2StandbyFrequency(119.9)
        store.setCom1ActiveAndStandby(active: 120.5, standby: 121.5)
        store.setCom2ActiveAndStandby(active: 123.45, standby: 124.85)
        store.setTransponderCode(7000)
        store.selectCom1Transmitter()
        store.selectCom2Transmitter()
        store.setCom1ReceiveEnabled(false)
        store.setCom2ReceiveEnabled(true)
        store.sendRadioMessage("test")
        store.sendPrivateMessage(to: "LOWW_TWR", text: "test")
        store.dismissSelcal("EPWW_ST_CTR")
        store.pinController("LKAA_CTR")
        store.clearPinnedController("LKAA_CTR")
        store.refreshFlightPlan()
        store.setUpdateInterval("slow")
        store.setDebugMode(true)

        #expect(store.lastSendError == nil)
        #expect(store.connection.state == .disconnected)
    }

    @Test func tuningAnswersLocallySoTheAppDoesNotLookBroken() {
        let store = self.store()
        store.demoMode = true

        store.setCom1Frequency(121.500)
        #expect(store.radioState?.com1Frequency == VHFFrequency.encode(mhz: 121.5))

        store.setTransponderCode(7000)
        #expect(store.radioState?.transponderCode == 7000)

        store.selectCom2Transmitter()
        #expect(store.radioState?.com2TransmitEnabled == true)
        // Transmitting on both at once isn't a thing the radio panel can express.
        #expect(store.radioState?.com1TransmitEnabled == false)
    }

    @Test func aSentMessageAppearsInItsOwnConversation() {
        let store = self.store()
        store.demoMode = true
        let before = store.chatMessages.count

        store.sendPrivateMessage(to: "LOWW_APP", text: "requesting descent")
        #expect(store.chatMessages.count == before + 1)
        let last = store.chatMessages.last
        #expect(last?.text == "requesting descent")
        #expect(last?.peer == "LOWW_APP")
        #expect(last?.isOutgoing == true)
    }

    @Test func pinningWorksOnTheSampleList() {
        let store = self.store()
        store.demoMode = true
        guard let target = store.controllers.first(where: { !$0.isPinned })?.callsign else {
            Issue.record("sample data has no unpinned controller to pin")
            return
        }
        store.pinController(target)
        #expect(store.controllers.first { $0.callsign == target }?.isPinned == true)
        store.clearPinnedController(target)
        #expect(store.controllers.first { $0.callsign == target }?.isPinned == false)
    }

    /// Foregrounding used to re-dial the last host unconditionally. From a demo
    /// session that would swap invented controllers for real ones underneath the
    /// pilot, with no visible transition.
    @Test func foregroundingDoesNotDialOutOfADemoSession() {
        let store = self.store()
        store.lastHost = "10.0.0.5"
        store.demoMode = true
        store.reconnectIfNeeded()
        #expect(store.connection.state == .disconnected)
        #expect(store.demoMode)
        store.lastHost = ""
    }

    /// The opposite direction: asking for a real connection has to end the demo, or
    /// sample rows would sit in the list until the plugin's first resend.
    @Test func connectingForRealEndsTheDemo() {
        let store = self.store()
        store.demoMode = true
        store.connect(host: "192.0.2.1", port: 48765) // TEST-NET-1, never routable
        #expect(store.demoMode == false)
        #expect(store.controllers.isEmpty)
        store.disconnect()
    }
}
