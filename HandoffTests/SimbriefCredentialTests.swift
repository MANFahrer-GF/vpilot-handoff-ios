import Testing
import Foundation
@testable import Handoff

/// The plugin echoes its stored SimBrief credentials back only on a pairing-code
/// success, never on the ordinary token reconnect (protocol.md). A client that
/// treated them as purely remote state therefore showed empty fields after every
/// relaunch -- these tests pin down that the app keeps its own copy and reconciles
/// the two sides the way the contract describes.
@MainActor
struct SimbriefCredentialTests {
    private func freshStore() -> AppStore {
        let store = AppStore()
        store.simbriefUserId = nil
        store.simbriefUsername = nil
        return store
    }

    @Test func credentialsSurviveARelaunch() {
        let store = freshStore()
        store.setSimbriefCredentials(userId: "123456", username: "thomas")

        // A second instance stands in for the next launch of the app.
        let relaunched = AppStore()
        #expect(relaunched.simbriefUserId == "123456")
        #expect(relaunched.simbriefUsername == "thomas")

        relaunched.simbriefUserId = nil
        relaunched.simbriefUsername = nil
    }

    @Test func clearingCredentialsAlsoPersists() {
        let store = freshStore()
        store.setSimbriefCredentials(userId: "123456", username: nil)
        store.setSimbriefCredentials(userId: nil, username: nil)
        #expect(AppStore().simbriefUserId == nil)
    }

    @Test func adoptsPluginCredentialsWhenTheClientHasNone() {
        let store = freshStore()
        store.reconcileSimbriefCredentials(pluginUserId: "999", pluginUsername: "fromPC")
        #expect(store.simbriefUserId == "999")
        #expect(store.simbriefUsername == "fromPC")
        store.simbriefUserId = nil
        store.simbriefUsername = nil
    }

    @Test func keepsItsOwnCredentialsWhenTheyDiffer() {
        let store = freshStore()
        store.simbriefUserId = "111"
        store.simbriefUsername = "tablet"
        // The tablet's values win -- protocol.md has both sides converge on them.
        store.reconcileSimbriefCredentials(pluginUserId: "999", pluginUsername: "fromPC")
        #expect(store.simbriefUserId == "111")
        #expect(store.simbriefUsername == "tablet")
        store.simbriefUserId = nil
        store.simbriefUsername = nil
    }

    @Test func leavesMatchingCredentialsUntouched() {
        let store = freshStore()
        store.simbriefUserId = "555"
        store.simbriefUsername = nil
        store.reconcileSimbriefCredentials(pluginUserId: "555", pluginUsername: nil)
        #expect(store.simbriefUserId == "555")
        store.simbriefUserId = nil
    }

    @Test func treatsEmptyStringsAsNoCredentials() {
        let store = freshStore()
        store.simbriefUserId = ""
        store.simbriefUsername = ""
        store.reconcileSimbriefCredentials(pluginUserId: "777", pluginUsername: nil)
        #expect(store.simbriefUserId == "777")
        store.simbriefUserId = nil
        store.simbriefUsername = nil
    }

    @Test func credentialChangesAreObservable() {
        final class Flag: @unchecked Sendable { var fired = false }
        let store = freshStore()
        let flag = Flag()
        withObservationTracking { _ = store.simbriefUserId } onChange: { flag.fired = true }
        store.simbriefUserId = "424242"
        #expect(flag.fired, "the settings field won't redraw when the credential isn't tracked")
        store.simbriefUserId = nil
    }
}
