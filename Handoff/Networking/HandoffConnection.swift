import Foundation
import Observation
import Security

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case awaitingPairingCode
    /// The presented certificate no longer matches the one pinned for this host.
    /// A terminal state: the socket was refused during the TLS handshake, so nothing
    /// was ever sent to whoever answered. Only the pilot can resolve it, by entering
    /// the code shown on that PC.
    case identityChanged
    case connected
    case failed(String)
}

private struct MessageType: Decodable { let type: String }

private struct PongMessage: Decodable {
    let clientTimestamp: Int64
}

/// Owns one WebSocket connection to the vPilot Handoff plugin.
///
/// Isolated to the main actor, with the URLSession delivering its callbacks on the
/// main queue too, so the connection state has exactly one owner. An earlier version
/// let the delegate queue and the UI write `host`/`wasConnected`/`pendingFingerprint`
/// concurrently.
@MainActor
@Observable
final class HandoffConnection: NSObject {
    static let defaultPort = 48765

    private(set) var state: ConnectionState = .disconnected
    /// Round-trip time of the last ping, shown in the status footer.
    private(set) var latencyMs: Int?

    var onControllers: ((ControllersMessage) -> Void)?
    var onChat: ((ChatMessagePayload) -> Void)?
    var onRadioState: ((RadioState) -> Void)?
    var onFlightPlan: ((FlightPlanMessage) -> Void)?
    var onSubsystemStatus: ((SubsystemStatus) -> Void)?
    var onDiversionPending: ((DiversionPendingMessage) -> Void)?
    var onNearbyAircraft: ((NearbyAircraftMessage) -> Void)?
    var onOperationProgress: ((OperationProgressMessage) -> Void)?
    var onInvalidPairingCode: (() -> Void)?
    var onDebugSnapshotSaved: ((DebugSnapshotSavedMessage) -> Void)?
    var onDebugSnapshotNamed: ((DebugSnapshotNamedMessage) -> Void)?
    var onSimbriefCredentialsReceived: ((String?, String?) -> Void)?
    /// Raised when a command couldn't be handed to the socket, so the UI can say so
    /// instead of leaving the pilot thinking a frequency change went out.
    var onSendFailure: ((String) -> Void)?

    private let pairingStore = PairingStore()
    private var urlSession: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var host = ""
    private var port = HandoffConnection.defaultPort

    /// Incremented on every connect/disconnect. Callbacks from a superseded socket
    /// carry an older generation and are dropped, so a dying connection can't
    /// overwrite the state of the one that replaced it.
    private var generation = 0

    private var wasConnected = false
    private var pendingFingerprint: String?
    /// Set when the pilot has confirmed an identity change; consumed by the next
    /// successful handshake, which then pairs by code instead of by token.
    private var pendingPairingCode: String?

    private var pingTask: Task<Void, Never>?
    private var lastPongAt: Date?

    private static let pingInterval: Duration = .seconds(10)
    /// Three missed pings. Long enough to ride out a brief Wi-Fi stall, short enough
    /// that a frozen controller list doesn't keep claiming to be live on approach.
    private static let pongTimeout: TimeInterval = 32

    // MARK: Lifecycle

    func connect(host: String, port: Int = HandoffConnection.defaultPort) {
        teardownSocket()
        generation += 1

        self.host = host
        self.port = port
        pendingFingerprint = nil
        wasConnected = false
        latencyMs = nil
        lastPongAt = nil
        state = .connecting

        guard let url = URL(string: "wss://\(host):\(port)/") else {
            state = .failed("Ungültige Adresse")
            return
        }

        // .main so every delegate callback lands on the actor this class is isolated to.
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        urlSession = session

        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        receiveNext(generation: generation)

        // Note: no `authenticate` here. It goes out from `didOpenWithProtocol`, once
        // the TLS handshake -- and with it the fingerprint check -- has actually passed.
        // Sending it here would hand the bearer token to whoever answered, before we
        // ever looked at their certificate.
    }

    func disconnect() {
        teardownSocket()
        generation += 1
        wasConnected = false
        pendingPairingCode = nil
        latencyMs = nil
        state = .disconnected
    }

    /// Cancels the socket without touching `state`, so callers decide what the
    /// connection means next.
    private func teardownSocket() {
        pingTask?.cancel()
        pingTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }

    func submitPairingCode(_ code: String) {
        if state == .identityChanged {
            // The pilot has read the code off that PC's screen, which is what actually
            // proves it's the machine they meant. Drop the stale pin and let the next
            // handshake pin whatever answers.
            pairingStore.clearPinnedFingerprint(forHost: host)
            pairingStore.clearToken(forHost: host)
            pendingPairingCode = code
            connect(host: host, port: port)
            return
        }
        sendAuthenticate(pairingCode: code)
    }

    // MARK: Sending

    func send<T: Encodable>(_ command: T) {
        guard let data = try? JSONEncoder().encode(command),
              let text = String(data: data, encoding: .utf8) else {
            onSendFailure?("Befehl konnte nicht kodiert werden.")
            return
        }
        guard let task = webSocketTask else {
            onSendFailure?("Nicht verbunden — Befehl wurde nicht gesendet.")
            return
        }
        let sentGeneration = generation
        task.send(.string(text)) { [weak self] error in
            guard let error else { return }
            Task { @MainActor in
                guard let self, self.generation == sentGeneration else { return }
                self.onSendFailure?("Senden fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }

    private func sendAuthenticate(pairingCode: String?) {
        let token = pairingCode == nil ? pairingStore.token(forHost: host) : nil
        send(AuthenticateCommand(token: token, pairingCode: pairingCode, deviceId: pairingStore.deviceId))
    }

    // MARK: Receiving

    private func receiveNext(generation: Int) {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self, self.generation == generation else { return }
                switch result {
                case .failure(let error):
                    self.handleDrop(error: error)
                    return
                case .success(.string(let text)):
                    self.handleIncoming(text)
                case .success(.data(let data)):
                    if let text = String(data: data, encoding: .utf8) { self.handleIncoming(text) }
                case .success:
                    break
                }
                self.receiveNext(generation: generation)
            }
        }
    }

    private func handleIncoming(_ text: String) {
        guard let data = text.data(using: .utf8),
              let typed = try? JSONDecoder().decode(MessageType.self, from: data) else { return }

        let decoder = JSONDecoder()
        switch typed.type {
        case "authResult":
            if let result = try? decoder.decode(AuthResult.self, from: data) { handleAuthResult(result) }
        case "controllers":
            if let msg = try? decoder.decode(ControllersMessage.self, from: data) { onControllers?(msg) }
        case "chat":
            if let msg = try? decoder.decode(ChatMessagePayload.self, from: data) { onChat?(msg) }
        case "radioState":
            if let msg = try? decoder.decode(RadioState.self, from: data) { onRadioState?(msg) }
        case "flightPlan":
            if let msg = try? decoder.decode(FlightPlanMessage.self, from: data) { onFlightPlan?(msg) }
        case "subsystemStatus":
            if let msg = try? decoder.decode(SubsystemStatus.self, from: data) { onSubsystemStatus?(msg) }
        case "diversionPending":
            if let msg = try? decoder.decode(DiversionPendingMessage.self, from: data) { onDiversionPending?(msg) }
        case "nearbyAircraft":
            if let msg = try? decoder.decode(NearbyAircraftMessage.self, from: data) { onNearbyAircraft?(msg) }
        case "operationProgress":
            if let msg = try? decoder.decode(OperationProgressMessage.self, from: data) { onOperationProgress?(msg) }
        case "debugSnapshotSaved":
            if let msg = try? decoder.decode(DebugSnapshotSavedMessage.self, from: data) { onDebugSnapshotSaved?(msg) }
        case "debugSnapshotNamed":
            if let msg = try? decoder.decode(DebugSnapshotNamedMessage.self, from: data) { onDebugSnapshotNamed?(msg) }
        case "pong":
            if let msg = try? decoder.decode(PongMessage.self, from: data) { handlePong(msg) }
        default:
            break
        }
    }

    private func handleAuthResult(_ result: AuthResult) {
        if result.success {
            if let token = result.token {
                // Only a pairing-code success carries a fresh token -- and this is the
                // point protocol.md says to commit the certificate pin, because the
                // code proved the machine's identity.
                pairingStore.setToken(token, forHost: host)
                if let pendingFingerprint {
                    pairingStore.setPinnedFingerprint(pendingFingerprint, forHost: host)
                }
                onSimbriefCredentialsReceived?(result.simbriefUserId, result.simbriefUsername)
            }
            wasConnected = true
            state = .connected
            startPinging()
        } else if result.reason == "pairingRequired" {
            state = .awaitingPairingCode
        } else if result.reason == "invalidCode" {
            onInvalidPairingCode?()
        } else {
            state = .failed(result.reason ?? "Anmeldung fehlgeschlagen")
        }
    }

    // MARK: Health

    private func startPinging() {
        pingTask?.cancel()
        lastPongAt = Date()
        let pingGeneration = generation
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.pingInterval)
                guard !Task.isCancelled else { return }
                guard let self, self.generation == pingGeneration else { return }
                self.sendPingAndCheckLiveness()
            }
        }
    }

    /// A socket that has silently died -- sleeping Wi-Fi, a suspended PC -- produces
    /// no error and no data, so without this the footer would keep claiming
    /// "connected" over a frozen controller list.
    private func sendPingAndCheckLiveness() {
        if let lastPongAt, Date().timeIntervalSince(lastPongAt) > Self.pongTimeout {
            handleDrop(error: URLError(.timedOut))
            return
        }
        send(PingCommand(clientTimestamp: Int64(Date().timeIntervalSince1970 * 1000)))
    }

    private func handlePong(_ pong: PongMessage) {
        lastPongAt = Date()
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        latencyMs = max(0, Int(now - pong.clientTimestamp))
    }

    // MARK: Drops

    private func handleDrop(error: Error) {
        teardownSocket()
        guard wasConnected else {
            state = .failed(error.localizedDescription)
            return
        }
        wasConnected = false
        latencyMs = nil
        let retryHost = host
        let retryPort = port
        let retryGeneration = generation
        state = .connecting
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, self.generation == retryGeneration else { return }
            self.connect(host: retryHost, port: retryPort)
        }
    }
}

// MARK: - URLSession delegates

extension HandoffConnection: URLSessionWebSocketDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        // delegateQueue is .main, so this genuinely runs on the main actor.
        MainActor.assumeIsolated {
            guard webSocketTask === self.webSocketTask else { return }
            // The handshake is through, which means the fingerprint check below
            // accepted this server. Only now is it safe to present our token.
            let code = pendingPairingCode
            pendingPairingCode = nil
            sendAuthenticate(pairingCode: code)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Fingerprinting is pure, so it stays out here; only the pin comparison needs
        // actor state, and only a String crosses into it. The completion handler is
        // deliberately never captured by the isolated closure -- it isn't Sendable.
        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let leaf = chain.first,
              let fingerprint = CertificateFingerprint.sha256PublicKeyFingerprint(of: leaf) else {
            MainActor.assumeIsolated { self.rejectUnreadableCertificate() }
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let accepted = MainActor.assumeIsolated { self.acceptFingerprint(fingerprint) }
        if accepted {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

private extension HandoffConnection {
    func rejectUnreadableCertificate() {
        teardownSocket()
        state = .failed("Zertifikat des Servers ist unlesbar.")
    }

    /// Self-signed certificate with no CA -- protocol.md's model is trust-on-first-use,
    /// not a certificate-authority chain, so there is deliberately no SecTrustEvaluate.
    ///
    /// Returns false to refuse the handshake outright when the pin no longer matches.
    /// Completing it and merely warning afterwards would already have handed over the
    /// bearer token, and would leave a hostile server free to answer `{"success":true}`
    /// and drive a fabricated controller list past a warning the pilot never sees.
    func acceptFingerprint(_ fingerprint: String) -> Bool {
        if let pinned = pairingStore.pinnedFingerprint(forHost: host), pinned != fingerprint {
            pairingStore.clearToken(forHost: host)
            teardownSocket()
            wasConnected = false
            state = .identityChanged
            return false
        }
        pendingFingerprint = fingerprint
        return true
    }
}
