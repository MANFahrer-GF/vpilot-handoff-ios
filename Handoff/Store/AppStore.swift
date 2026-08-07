import Foundation
import Observation

/// The single source of truth SwiftUI views read from. Wires HandoffConnection's
/// callbacks (which fire off the network) into plain published state, and exposes
/// one method per client->server command so views never touch the connection
/// or the wire format directly.
@MainActor
@Observable
final class AppStore {
    let connection = HandoffConnection()

    var controllers: [Controller] = []
    var etaMinutes: Double?
    var chatMessages: [ChatMessage] = []
    var selcalAlerts: [SelcalAlert] = []
    var radioState: RadioState?
    var flightPlan: FlightPlanMessage?
    var subsystemStatus: SubsystemStatus?
    var diversionDestination: String?
    var nearbyAircraft: [NearbyAircraft] = []
    var pairingCodeError: String?
    /// Progress of long-running plugin operations (VatGlasses sync, SimBrief refresh),
    /// keyed by the invocation id so two runs of the same operation can't clobber
    /// each other. protocol.md guarantees no ordering or exclusivity between them.
    var operations: [String: OperationProgressMessage] = [:]
    private var operationTimeouts: [String: Task<Void, Never>] = [:]

    /// protocol.md's prescribed backstop for a dropped `finished` message. Overridable
    /// so the test suite doesn't sit on a real minute-long timer per case.
    static var operationTimeout: Duration = .seconds(60)

    // MARK: View preferences

    var hideTuned = false

    /// Stored, not computed. A computed property backed straight by UserDefaults is
    /// invisible to Observation, so `preferredColorScheme` never re-evaluated and
    /// switching Hell/Dunkel did nothing until the app was relaunched.
    var appearance: AppearanceMode = AppearanceMode.persisted {
        didSet { HandoffDefaults.store.set(appearance.rawValue, forKey: AppearanceMode.storageKey) }
    }

    /// Messages that arrived while the RADIO panel wasn't on screen -- drives the
    /// MSG tile's badge. Reset by `markChatRead()` when the panel is visible.
    var unreadChatCount = 0
    private var seenChatMessageIds: Set<String> = []
    private var hasReceivedChatSnapshot = false

    // MARK: Debug mode

    var debugMode = false
    var controllersDebug: ControllersDebug?
    var pendingSnapshotId: String?
    var lastSnapshotPath: String?
    var lastSnapshotError: String?
    var lastSnapshotName: String?

    // MARK: Settings (mirrors what the plugin currently has persisted)

    /// Persisted locally, not just mirrored from the plugin: protocol.md only echoes
    /// the plugin's copy back on a *pairing-code* success, never on the ordinary
    /// token reconnect, so a client that kept these in memory would show empty
    /// fields on every relaunch. It also makes the reconciliation below possible --
    /// that contract assumes the client has its own stored credentials to compare.
    var simbriefUserId: String? = HandoffDefaults.store.string(forKey: "handoff.simbrief.userId") {
        didSet { HandoffDefaults.store.set(simbriefUserId, forKey: "handoff.simbrief.userId") }
    }

    var simbriefUsername: String? = HandoffDefaults.store.string(forKey: "handoff.simbrief.username") {
        didSet { HandoffDefaults.store.set(simbriefUsername, forKey: "handoff.simbrief.username") }
    }

    /// Stored for the same reason as `appearance` -- the status footer and the
    /// settings sheet both read this and must redraw when it changes.
    var lastHost: String = HandoffDefaults.store.string(forKey: "handoff.lastHost") ?? "" {
        didSet { HandoffDefaults.store.set(lastHost, forKey: "handoff.lastHost") }
    }

    /// Remembered alongside the host: discovery reports the plugin's actual port, and
    /// assuming the default would strand anyone who moved it.
    var lastPort: Int = {
        let stored = HandoffDefaults.store.integer(forKey: "handoff.lastPort")
        return stored == 0 ? HandoffConnection.defaultPort : stored
    }() {
        didSet { HandoffDefaults.store.set(lastPort, forKey: "handoff.lastPort") }
    }

    /// Last command that couldn't be handed to the socket, surfaced in the footer so
    /// a dropped frequency change doesn't pass for a successful one.
    var lastSendError: String?

    // MARK: Frequency entry preferences (gallery/05-settings.png)

    /// Which channel grid the tune keypad starts on. 8.33 kHz is the European
    /// default; a pilot flying 25 kHz-only regions can flip it once here instead of
    /// on every entry.
    var channelSpacing833: Bool = HandoffDefaults.store.object(forKey: "handoff.spacing833") as? Bool ?? true {
        didSet { HandoffDefaults.store.set(channelSpacing833, forKey: "handoff.spacing833") }
    }

    /// "Block invalid" refuses off-grid entries; "Allow all" lets them through to the
    /// plugin, which drops out-of-range values silently. Off-grid but in-band values
    /// are the interesting case -- some add-ons accept them.
    var blockInvalidFrequencies: Bool = HandoffDefaults.store.object(forKey: "handoff.blockInvalidFreq") as? Bool ?? true {
        didSet { HandoffDefaults.store.set(blockInvalidFrequencies, forKey: "handoff.blockInvalidFreq") }
    }

    init() {
        connection.onControllers = { [weak self] msg in
            guard let self else { return }
            // The plugin resends the full list on a fixed ~1s cadence regardless of
            // whether anything changed (see protocol.md) -- skip the write when the
            // content is identical so SwiftUI doesn't re-diff/re-render the list and
            // every row's swipeActions every single second for no reason.
            if self.controllers != msg.controllers { self.controllers = msg.controllers }
            if self.etaMinutes != msg.etaMinutes { self.etaMinutes = msg.etaMinutes }
            self.controllersDebug = msg.debug
        }
        connection.onChat = { [weak self] msg in
            guard let self else { return }
            // Full-state resend on every change (protocol.md) -- skip the write when
            // nothing actually changed so the list doesn't rebuild needlessly.
            if self.chatMessages != msg.messages {
                let newIds = msg.messages.map(\.id).filter { !self.seenChatMessageIds.contains($0) }
                // The first payload after connecting is the whole existing log, not
                // news -- counting it would greet the pilot with a badge of "37".
                if self.hasReceivedChatSnapshot && !self.chatPanelVisible {
                    self.unreadChatCount += newIds.count
                }
                self.hasReceivedChatSnapshot = true
                self.seenChatMessageIds.formUnion(newIds)
                self.chatMessages = msg.messages
            }
            if self.selcalAlerts != msg.selcalAlerts { self.selcalAlerts = msg.selcalAlerts }
        }
        connection.onRadioState = { [weak self] msg in self?.radioState = msg }
        connection.onFlightPlan = { [weak self] msg in self?.flightPlan = msg }
        connection.onSubsystemStatus = { [weak self] msg in self?.subsystemStatus = msg }
        connection.onDiversionPending = { [weak self] msg in self?.diversionDestination = msg.destination }
        connection.onNearbyAircraft = { [weak self] msg in self?.nearbyAircraft = msg.aircraft }
        connection.onInvalidPairingCode = { [weak self] in
            self?.pairingCodeError = "Falscher Code -- bitte erneut versuchen."
        }
        connection.onDebugSnapshotSaved = { [weak self] msg in
            guard let self, self.pendingSnapshotId == msg.snapshotId else { return }
            self.lastSnapshotPath = msg.path
            self.lastSnapshotError = nil
            self.attachScreenshotIfAvailable(snapshotId: msg.snapshotId)
        }
        connection.onDebugSnapshotNamed = { [weak self] msg in
            guard let self, self.pendingSnapshotId == msg.snapshotId else { return }
            if !msg.success { self.lastSnapshotError = msg.error ?? "Benennung fehlgeschlagen." }
        }
        connection.onSimbriefCredentialsReceived = { [weak self] userId, username in
            self?.reconcileSimbriefCredentials(pluginUserId: userId, pluginUsername: username)
        }
        connection.onOperationProgress = { [weak self] msg in
            self?.applyOperationProgress(msg)
        }
        connection.onSendFailure = { [weak self] message in
            self?.lastSendError = message
        }
    }

    // MARK: Connection lifecycle

    func connect(host: String, port: Int = HandoffConnection.defaultPort) {
        lastHost = host
        lastPort = port
        pairingCodeError = nil
        lastSendError = nil
        controllers = []
        chatMessages = []
        selcalAlerts = []
        radioState = nil
        hasReceivedChatSnapshot = false
        unreadChatCount = 0
        connection.connect(host: host, port: port)
    }

    func submitPairingCode(_ code: String) {
        pairingCodeError = nil
        connection.submitPairingCode(code)
    }

    func disconnect() {
        connection.disconnect()
    }

    /// Called when the app returns to the foreground. The socket may be dead even
    /// though `connection.state` still reads `.connected` from before the app was
    /// suspended, so this unconditionally re-establishes rather than trusting the
    /// stale in-memory state -- the stored bearer token makes this silent (no
    /// pairing code needed again) as long as the plugin is still reachable.
    func reconnectIfNeeded() {
        #if DEBUG
        if DemoData.isEnabled { return }
        #endif
        guard !lastHost.isEmpty else { return }
        switch connection.state {
        case .awaitingPairingCode, .connecting, .identityChanged:
            // Mid-pairing, already trying, or deliberately refused -- reconnecting
            // would either interrupt the pilot or silently retry a server we just
            // rejected.
            return
        default:
            connect(host: lastHost, port: lastPort)
        }
    }

    // MARK: Chat

    func sendPrivateMessage(to callsign: String, text: String) {
        connection.send(SendPrivateMessageCommand(to: callsign, message: text))
    }

    func sendRadioMessage(_ text: String) {
        connection.send(SendRadioMessageCommand(message: text))
    }

    func dismissSelcal(_ callsign: String) {
        connection.send(DismissSelcalCommand(callsign: callsign))
    }

    // MARK: Radio

    func setCom1Frequency(_ mhz: Double) {
        connection.send(SetFrequencyCommand(type: "setCom1Frequency", megahertz: mhz))
    }

    func setCom2Frequency(_ mhz: Double) {
        connection.send(SetFrequencyCommand(type: "setCom2Frequency", megahertz: mhz))
    }

    func setCom1StandbyFrequency(_ mhz: Double) {
        connection.send(SetFrequencyCommand(type: "setCom1StandbyFrequency", megahertz: mhz))
    }

    func setCom2StandbyFrequency(_ mhz: Double) {
        connection.send(SetFrequencyCommand(type: "setCom2StandbyFrequency", megahertz: mhz))
    }

    func setCom1ActiveAndStandby(active: Double, standby: Double) {
        connection.send(SetActiveAndStandbyCommand(type: "setCom1ActiveAndStandbyFrequency", megahertz: active, standbyMegahertz: standby))
    }

    func setCom2ActiveAndStandby(active: Double, standby: Double) {
        connection.send(SetActiveAndStandbyCommand(type: "setCom2ActiveAndStandbyFrequency", megahertz: active, standbyMegahertz: standby))
    }

    func setTransponderCode(_ code: Int) {
        connection.send(SetTransponderCodeCommand(transponderCode: code))
    }

    func selectCom1Transmitter() {
        connection.send(SelectTransmitterCommand(type: "selectCom1Transmitter"))
    }

    func selectCom2Transmitter() {
        connection.send(SelectTransmitterCommand(type: "selectCom2Transmitter"))
    }

    func setCom1ReceiveEnabled(_ enabled: Bool) {
        connection.send(SetReceiveEnabledCommand(type: "setCom1ReceiveEnabled", enabled: enabled))
    }

    func setCom2ReceiveEnabled(_ enabled: Bool) {
        connection.send(SetReceiveEnabledCommand(type: "setCom2ReceiveEnabled", enabled: enabled))
    }

    // MARK: Controllers / flight plan

    func pinController(_ callsign: String) {
        connection.send(PinControllerCommand(type: "pinController", callsign: callsign))
    }

    func clearPinnedController(_ callsign: String) {
        connection.send(PinControllerCommand(type: "clearPinnedController", callsign: callsign))
    }

    func confirmDiversion() {
        connection.send(SimpleCommand(type: "confirmDiversion"))
        diversionDestination = nil
    }

    func dismissDiversion() {
        connection.send(SimpleCommand(type: "dismissDiversion"))
        diversionDestination = nil
    }

    func refreshFlightPlan() {
        connection.send(SimpleCommand(type: "refreshFlightPlan"))
    }

    // MARK: Settings

    func setSimbriefCredentials(userId: String?, username: String?) {
        simbriefUserId = userId
        simbriefUsername = username
        connection.send(SetSimbriefCredentialsCommand(simbriefUserId: userId, simbriefUsername: username))
        refreshFlightPlan()
    }

    /// The three-way reconciliation protocol.md prescribes when the plugin echoes its
    /// stored credentials back on a pairing-code success: adopt the plugin's when we
    /// have none, do nothing when they already agree, and otherwise push ours back up
    /// so both sides converge on the tablet's values rather than silently diverging.
    func reconcileSimbriefCredentials(pluginUserId: String?, pluginUsername: String?) {
        let ownIsEmpty = (simbriefUserId?.isEmpty ?? true) && (simbriefUsername?.isEmpty ?? true)
        if ownIsEmpty {
            simbriefUserId = pluginUserId
            simbriefUsername = pluginUsername
            return
        }
        if simbriefUserId == pluginUserId && simbriefUsername == pluginUsername { return }
        setSimbriefCredentials(userId: simbriefUserId, username: simbriefUsername)
    }

    func setUpdateInterval(_ interval: String) {
        connection.send(SetUpdateIntervalCommand(interval: interval))
    }

    // MARK: Debug mode

    func setDebugMode(_ enabled: Bool) {
        debugMode = enabled
        connection.send(SetDebugModeCommand(enabled: enabled))
        if !enabled {
            controllersDebug = nil
        }
    }

    // MARK: Operations

    /// Finished operations linger briefly so the pilot actually sees the outcome --
    /// failures longer, since that's the actionable case. protocol.md leaves the
    /// duration to the client but is explicit that clearing on arrival is too fast.
    private func applyOperationProgress(_ msg: OperationProgressMessage) {
        operations[msg.operationId] = msg
        operationTimeouts[msg.operationId]?.cancel()

        guard msg.finished else {
            // protocol.md requires the client's own 60s backstop: a dropped
            // `finished` message (a disconnect mid-sync) would otherwise leave a
            // spinner running forever.
            operationTimeouts[msg.operationId] = Task { [weak self] in
                try? await Task.sleep(for: AppStore.operationTimeout)
                guard !Task.isCancelled else { return }
                self?.operations.removeValue(forKey: msg.operationId)
                self?.operationTimeouts.removeValue(forKey: msg.operationId)
            }
            return
        }

        let linger: Duration = (msg.success == false) ? .seconds(12) : .seconds(4)
        operationTimeouts[msg.operationId] = Task { [weak self] in
            try? await Task.sleep(for: linger)
            guard !Task.isCancelled else { return }
            self?.operations.removeValue(forKey: msg.operationId)
            self?.operationTimeouts.removeValue(forKey: msg.operationId)
        }
    }

    // MARK: Chat panel bookkeeping

    /// Set by the dashboard so incoming messages know whether they're being seen.
    var chatPanelVisible = false

    func markChatRead() {
        unreadChatCount = 0
        seenChatMessageIds.formUnion(chatMessages.map(\.id))
    }

    /// Kicks off the full snapshot round trip: save -> (once acknowledged) attach a
    /// view-scoped screenshot -> the plugin correlates both by `snapshotId`.
    func saveDebugSnapshot(appVersion: String) {
        let id = UUID().uuidString
        pendingSnapshotId = id
        lastSnapshotPath = nil
        lastSnapshotError = nil
        lastSnapshotName = nil
        connection.send(SaveDebugSnapshotCommand(snapshotId: id, appVersion: appVersion))
    }

    func nameLastSnapshot(_ name: String) {
        guard let id = pendingSnapshotId else { return }
        lastSnapshotName = name
        connection.send(NameDebugSnapshotCommand(snapshotId: id, name: name))
    }

    private func attachScreenshotIfAvailable(snapshotId: String) {
        guard let pngData = AppScreenshotter.captureCurrentWindowPNG() else { return }
        let base64 = pngData.base64EncodedString()
        connection.send(AttachDebugSnapshotScreenshotCommand(snapshotId: snapshotId, screenshotPngBase64: base64))
    }
}
