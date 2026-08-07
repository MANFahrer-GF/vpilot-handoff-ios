import Foundation
import Observation
import Security

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case awaitingPairingCode
    case connected
    case failed(String)
}

private struct MessageType: Decodable { let type: String }

/// Owns one WebSocket connection to the vPilot Handoff plugin: TLS trust-on-first-use
/// pinning, the authenticate/authResult pairing handshake, and dispatch of every
/// server->client message type from docs/protocol.md to the AppStore's callbacks.
@Observable
final class HandoffConnection: NSObject {
    private(set) var state: ConnectionState = .disconnected

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
    /// Fired when the presented certificate no longer matches the pinned one, so the
    /// pairing prompt can say why it's asking again instead of looking like a glitch.
    var onPinnedIdentityChanged: (() -> Void)?

    private let pairingStore = PairingStore()
    private var urlSession: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?
    private var host = ""
    private var port = 48765

    /// Fingerprint seen during the TLS handshake in progress, committed as the
    /// pinned fingerprint only once pairing actually succeeds (see urlSession(_:didReceive:) ).
    private var pendingFingerprint: String?

    /// Set once a connection reaches .connected; gates the one automatic reconnect
    /// attempt below. An initial connect failure (bad IP, plugin not running) should
    /// surface immediately instead of retrying blindly -- only a session that was
    /// genuinely live and then dropped (Wi-Fi blip) gets the silent retry.
    private var wasConnected = false

    func connect(host: String, port: Int = 48765) {
        self.host = host
        self.port = port
        pendingFingerprint = nil
        wasConnected = false
        state = .connecting

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        urlSession = session

        guard let url = URL(string: "wss://\(host):\(port)/") else {
            state = .failed("Ungültige Adresse")
            return
        }

        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        receiveNext()
        sendAuthenticate(pairingCode: nil)
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession = nil
        state = .disconnected
    }

    func submitPairingCode(_ code: String) {
        sendAuthenticate(pairingCode: code)
    }

    func send<T: Encodable>(_ command: T) {
        guard let data = try? JSONEncoder().encode(command),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(text)) { _ in }
    }

    private func sendAuthenticate(pairingCode: String?) {
        let token = pairingCode == nil ? pairingStore.token(forHost: host) : nil
        send(AuthenticateCommand(token: token, pairingCode: pairingCode, deviceId: pairingStore.deviceId))
    }

    private func receiveNext() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
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
            self.receiveNext()
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
            if let msg = try? decoder.decode(ControllersMessage.self, from: data) {
                dispatch { self.onControllers?(msg) }
            }
        case "chat":
            if let msg = try? decoder.decode(ChatMessagePayload.self, from: data) {
                dispatch { self.onChat?(msg) }
            }
        case "radioState":
            if let msg = try? decoder.decode(RadioState.self, from: data) {
                dispatch { self.onRadioState?(msg) }
            }
        case "flightPlan":
            if let msg = try? decoder.decode(FlightPlanMessage.self, from: data) {
                dispatch { self.onFlightPlan?(msg) }
            }
        case "subsystemStatus":
            if let msg = try? decoder.decode(SubsystemStatus.self, from: data) {
                dispatch { self.onSubsystemStatus?(msg) }
            }
        case "diversionPending":
            if let msg = try? decoder.decode(DiversionPendingMessage.self, from: data) {
                dispatch { self.onDiversionPending?(msg) }
            }
        case "nearbyAircraft":
            if let msg = try? decoder.decode(NearbyAircraftMessage.self, from: data) {
                dispatch { self.onNearbyAircraft?(msg) }
            }
        case "operationProgress":
            if let msg = try? decoder.decode(OperationProgressMessage.self, from: data) {
                dispatch { self.onOperationProgress?(msg) }
            }
        case "debugSnapshotSaved":
            if let msg = try? decoder.decode(DebugSnapshotSavedMessage.self, from: data) {
                dispatch { self.onDebugSnapshotSaved?(msg) }
            }
        case "debugSnapshotNamed":
            if let msg = try? decoder.decode(DebugSnapshotNamedMessage.self, from: data) {
                dispatch { self.onDebugSnapshotNamed?(msg) }
            }
        default:
            break // pong not needed for the MVP feature set
        }
    }

    private func handleAuthResult(_ result: AuthResult) {
        if result.success {
            if let token = result.token {
                // Only a pairing-code success carries a fresh token -- this is also
                // the moment protocol.md says the certificate pin should be committed.
                pairingStore.setToken(token, forHost: host)
                if let pendingFingerprint {
                    pairingStore.setPinnedFingerprint(pendingFingerprint, forHost: host)
                }
                dispatch { self.onSimbriefCredentialsReceived?(result.simbriefUserId, result.simbriefUsername) }
            }
            wasConnected = true
            setState(.connected)
        } else if result.reason == "pairingRequired" {
            setState(.awaitingPairingCode)
        } else if result.reason == "invalidCode" {
            dispatch { self.onInvalidPairingCode?() }
        } else {
            setState(.failed(result.reason ?? "Anmeldung fehlgeschlagen"))
        }
    }

    private func handleDrop(error: Error) {
        guard wasConnected else {
            setState(.failed(error.localizedDescription))
            return
        }
        wasConnected = false
        let retryHost = host
        let retryPort = port
        setState(.connecting)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.connect(host: retryHost, port: retryPort)
        }
    }

    private func setState(_ newState: ConnectionState) {
        dispatch { self.state = newState }
    }

    private func dispatch(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}

extension HandoffConnection: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let leaf = chain.first,
              let fingerprint = CertificateFingerprint.sha256PublicKeyFingerprint(of: leaf) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Self-signed certificate with no CA -- protocol.md's model is TOFU, not a
        // certificate-authority chain, so we deliberately don't call SecTrustEvaluate.
        if let pinned = pairingStore.pinnedFingerprint(forHost: host), pinned != fingerprint {
            // Server identity changed since our last successful pairing (reinstalled
            // plugin, or a different machine answering the same IP/hostname) --
            // the stored token can no longer be assumed valid for this new identity.
            pairingStore.clearToken(forHost: host)
            dispatch { self.onPinnedIdentityChanged?() }
        }
        pendingFingerprint = fingerprint

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}
