import Testing
import Foundation
@testable import Handoff

/// The connection layer carried every serious finding of the first external review
/// and had no tests at all. These cover the parts that can be exercised without a
/// live plugin: the pairing store's persistence rules, the fingerprint pin, and the
/// state machine's refusal behaviour.
@MainActor
struct PairingStoreTests {
    private func store(host: String) -> (PairingStore, String) {
        TestDefaults.installOnce()
        let pairing = PairingStore()
        pairing.clearToken(forHost: host)
        pairing.clearPinnedFingerprint(forHost: host)
        return (pairing, host)
    }

    @Test func deviceIdIsStableAcrossInstances() {
        TestDefaults.installOnce()
        let first = PairingStore().deviceId
        let second = PairingStore().deviceId
        #expect(first == second)
        #expect(!first.isEmpty)
    }

    @Test func tokensRoundTripAndAreScopedPerHost() {
        let (pairing, host) = store(host: "10.0.0.1")
        pairing.clearToken(forHost: "10.0.0.2")

        pairing.setToken("token-a", forHost: host)
        pairing.setToken("token-b", forHost: "10.0.0.2")

        #expect(pairing.token(forHost: host) == "token-a")
        #expect(pairing.token(forHost: "10.0.0.2") == "token-b")

        pairing.clearToken(forHost: host)
        #expect(pairing.token(forHost: host) == nil)
        // Clearing one host must not disturb another paired PC.
        #expect(pairing.token(forHost: "10.0.0.2") == "token-b")
        pairing.clearToken(forHost: "10.0.0.2")
    }

    @Test func pinnedFingerprintRoundTripsAndClears() {
        let (pairing, host) = store(host: "10.0.0.3")
        #expect(pairing.pinnedFingerprint(forHost: host) == nil)
        pairing.setPinnedFingerprint("AA:BB", forHost: host)
        #expect(pairing.pinnedFingerprint(forHost: host) == "AA:BB")
        pairing.clearPinnedFingerprint(forHost: host)
        #expect(pairing.pinnedFingerprint(forHost: host) == nil)
    }
}

@MainActor
struct ConnectionStateTests {
    private func connection() -> HandoffConnection {
        TestDefaults.installOnce()
        return HandoffConnection()
    }

    @Test func startsDisconnected() {
        #expect(connection().state == .disconnected)
    }

    @Test func rejectsAnUnparseableHostWithoutHanging() {
        let connection = self.connection()
        connection.connect(host: "not a host", port: 48765)
        // Anything that can't become a URL must fail immediately rather than sit in
        // .connecting forever with no socket behind it. Asserted on the case, not the
        // message -- pinning the wording made this fail the moment the UI language
        // changed, which says nothing about the behaviour under test.
        guard case .failed = connection.state else {
            Issue.record("expected .failed, got \(connection.state)")
            return
        }
    }

    @Test func disconnectIsTerminalAndDoesNotSelfHeal() async throws {
        let connection = self.connection()
        connection.connect(host: "192.0.2.1", port: 48765) // TEST-NET-1, never routable
        connection.disconnect()
        #expect(connection.state == .disconnected)

        // The reconnect timer was two seconds; an earlier version left `wasConnected`
        // set so an explicit "Trennen" reconnected itself moments later.
        try await Task.sleep(for: .seconds(3))
        #expect(connection.state == .disconnected)
    }

    @Test func defaultPortMatchesTheProtocol() {
        #expect(HandoffConnection.defaultPort == 48765)
    }

    @Test func latencyStartsUnknown() {
        #expect(connection().latencyMs == nil)
    }
}

struct DiscoveryResultTests {
    @Test func carriesThePortSoCallersCanHonourIt() {
        // Regression guard for a finding where discovery reported the port and the
        // caller then connected on the default anyway.
        let result = DiscoveryResult(host: "10.0.0.5", port: 51234, fingerprint: "AA:BB")
        #expect(result.port == 51234)
        #expect(result != DiscoveryResult(host: "10.0.0.5", port: 48765, fingerprint: "AA:BB"))
    }
}

@MainActor
struct StoreConnectionWiringTests {
    @Test func connectRemembersHostAndPort() {
        TestDefaults.installOnce()
        let store = AppStore()
        store.connect(host: "10.0.0.9", port: 51999)
        #expect(store.lastHost == "10.0.0.9")
        #expect(store.lastPort == 51999)
        store.disconnect()
    }

    @Test func reconnectIsSuppressedWhileIdentityIsDisputed() {
        TestDefaults.installOnce()
        let store = AppStore()
        store.lastHost = ""
        // With no host there is nothing to reconnect to; the guard must hold rather
        // than dialling an empty address.
        store.reconnectIfNeeded()
        #expect(store.connection.state == .disconnected)
    }

    @Test func operationProgressIsKeyedByInvocation() async throws {
        TestDefaults.installOnce()
        // Otherwise each unfinished operation parks a real 60-second timer and the
        // whole suite waits on it.
        AppStore.operationTimeout = .milliseconds(50)
        defer { AppStore.operationTimeout = .seconds(60) }
        let store = AppStore()
        let first = try! JSONDecoder().decode(
            OperationProgressMessage.self,
            from: Data(#"{"operationId":"sync-1","status":"12/24","finished":false}"#.utf8)
        )
        let second = try! JSONDecoder().decode(
            OperationProgressMessage.self,
            from: Data(#"{"operationId":"sync-2","status":"3/9","finished":false}"#.utf8)
        )
        store.connection.onOperationProgress?(first)
        store.connection.onOperationProgress?(second)
        // Two runs of the same operation type must not clobber each other.
        #expect(store.operations.count == 2)
        #expect(store.operations["sync-1"]?.status == "12/24")

        // protocol.md's backstop: a run whose `finished` never arrives must stop
        // showing a spinner rather than hanging there for the rest of the flight.
        try await Task.sleep(for: .milliseconds(300))
        #expect(store.operations.isEmpty)
    }

    @Test func sendFailureSurfacesToTheUI() {
        TestDefaults.installOnce()
        let store = AppStore()
        store.connection.onSendFailure?("Nicht verbunden")
        #expect(store.lastSendError == "Nicht verbunden")
    }
}
