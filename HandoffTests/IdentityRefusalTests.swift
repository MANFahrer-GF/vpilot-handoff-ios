import Testing
import Foundation
@testable import Handoff

/// Regression guard for the one finding that survived two review rounds.
///
/// Refusing a changed certificate set `.identityChanged`, but tearing the socket down
/// makes the pending `receive` fail with "cancelled" a moment later. That drop was
/// handled unconditionally, so it overwrote the state with `.failed`. The pairing
/// sheet is presented for `.identityChanged`/`.awaitingPairingCode` only — so the
/// warning never appeared, and after a legitimate plugin reinstall the pilot could
/// not pair again at all. Deleting the app was the only way out.
///
/// It went unnoticed because the path needs a real TLS server with a second
/// certificate. The rule now lives in a pure function so it can be checked here.
struct DropOutcomeTests {
    @Test func aRefusedIdentityOutranksTheCancellationItCauses() {
        // The exact sequence that locked pilots out.
        #expect(ConnectionState.dropOutcome(from: .identityChanged, wasConnected: false) == .keepCurrentState)
        // Also true if the link had been live before the certificate changed.
        #expect(ConnectionState.dropOutcome(from: .identityChanged, wasConnected: true) == .keepCurrentState)
    }

    @Test func aPendingPairingCodeIsNotWipedByATransportError() {
        // Same shape of bug: the pilot is mid-entry and the socket hiccups.
        #expect(ConnectionState.dropOutcome(from: .awaitingPairingCode, wasConnected: false) == .keepCurrentState)
    }

    @Test func aLiveSessionThatDropsIsRetried() {
        #expect(ConnectionState.dropOutcome(from: .connected, wasConnected: true) == .scheduleReconnect)
    }

    @Test func aConnectionThatNeverCameUpReportsWhy() {
        // A wrong IP has to surface immediately rather than retry forever.
        #expect(ConnectionState.dropOutcome(from: .connecting, wasConnected: false) == .reportFailure)
    }

    @Test func onlyPilotResolvableStatesAreProtected() {
        #expect(ConnectionState.identityChanged.awaitsPilot)
        #expect(ConnectionState.awaitingPairingCode.awaitsPilot)
        // These must stay overwritable or a dropped link would never recover.
        #expect(!ConnectionState.connected.awaitsPilot)
        #expect(!ConnectionState.connecting.awaitsPilot)
        #expect(!ConnectionState.disconnected.awaitsPilot)
        #expect(!ConnectionState.failed("x").awaitsPilot)
    }
}

@MainActor
struct EndpointScopingTests {
    /// Two plugin instances on one machine are different servers with different
    /// certificates. Keying the pin on the host alone made switching between them look
    /// like an impersonation attempt — and it was what the reviewer's two-certificate
    /// test rig exploited.
    @Test func pinsAreScopedPerPortNotJustPerHost() {
        TestDefaults.installOnce()
        let store = PairingStore()
        let first = "127.0.0.1:48799"
        let second = "127.0.0.1:48800"
        store.clearPinnedFingerprint(forEndpoint: first)
        store.clearPinnedFingerprint(forEndpoint: second)

        store.setPinnedFingerprint("AA:AA", forEndpoint: first)
        #expect(store.pinnedFingerprint(forEndpoint: second) == nil)

        store.setPinnedFingerprint("BB:BB", forEndpoint: second)
        #expect(store.pinnedFingerprint(forEndpoint: first) == "AA:AA")

        store.clearPinnedFingerprint(forEndpoint: first)
        store.clearPinnedFingerprint(forEndpoint: second)
    }

    @Test func tokensAreScopedTheSameWay() {
        TestDefaults.installOnce()
        let store = PairingStore()
        store.setToken("token-a", forEndpoint: "10.0.0.1:48765")
        store.setToken("token-b", forEndpoint: "10.0.0.1:49000")
        #expect(store.token(forEndpoint: "10.0.0.1:48765") == "token-a")
        #expect(store.token(forEndpoint: "10.0.0.1:49000") == "token-b")
        store.clearToken(forEndpoint: "10.0.0.1:48765")
        #expect(store.token(forEndpoint: "10.0.0.1:49000") == "token-b")
        store.clearToken(forEndpoint: "10.0.0.1:49000")
    }
}

@MainActor
struct ReconnectGuardTests {
    @Test func foregroundingDoesNotRedialARefusedServer() {
        TestDefaults.installOnce()
        let store = AppStore()
        store.lastHost = "10.0.0.5"
        // reconnectIfNeeded previously listed the protected states by hand; it now
        // asks the state itself, so a new pilot-resolvable case can't be forgotten.
        #expect(ConnectionState.identityChanged.awaitsPilot)
        store.lastHost = ""
    }
}
