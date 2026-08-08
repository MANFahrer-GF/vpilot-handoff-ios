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

    /// Unread count per conversation, so each tab carries its own badge the way the
    /// Android client does. The MSG tile shows the sum.
    var unreadByConversation: [String: Int] = [:]
    /// Which conversation the pilot is actually looking at; messages arriving there
    /// while the panel is open are read on arrival.
    var visibleConversation: String?

    var unreadChatCount: Int { unreadByConversation.values.reduce(0, +) }

    /// What ATC would call us on the frequency. The filed VATSIM callsign is the one
    /// actually in use; the SimBrief one is a fallback for before we're connected.
    var ownCallsign: String? {
        flightPlan?.vatsimCallsign ?? flightPlan?.simbriefCallsign
    }

    /// True while something aimed at this pilot is waiting: an unread private
    /// conversation, or a radio call on the frequency that named our callsign.
    /// Ambient chatter alone does not qualify.
    var hasUnreadDirectedMessage: Bool {
        if unreadByConversation.contains(where: { $0.key != ChatMessage.radioConversationKey && $0.value > 0 }) {
            return true
        }
        guard (unreadByConversation[ChatMessage.radioConversationKey] ?? 0) > 0 else { return false }
        return unreadRadioMentionsUs
    }

    /// Set when an unread radio message named us, so the flag survives even after
    /// newer chatter has arrived behind it.
    private(set) var unreadRadioMentionsUs = false

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

    /// Whether a debug snapshot carries a screenshot of this app's window. The
    /// Android client's equivalent opt-in widens the capture to the whole display;
    /// iOS can't do that at all (see AppScreenshotter), so the only real choice is
    /// attach or don't.
    var attachDebugScreenshot: Bool = HandoffDefaults.store.object(forKey: "handoff.attachDebugShot") as? Bool ?? true {
        didSet { HandoffDefaults.store.set(attachDebugScreenshot, forKey: "handoff.attachDebugShot") }
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
                let arrived = msg.messages.filter { !self.seenChatMessageIds.contains($0.id) }
                // The first payload after connecting is the whole existing log, not
                // news -- counting it would greet the pilot with a badge of "37".
                if self.hasReceivedChatSnapshot {
                    for message in arrived where !message.isOutgoing {
                        let key = message.conversationKey
                        // Already on screen in the tab it landed in? Then it's read.
                        let isBeingWatched = self.chatPanelVisible && self.visibleConversation == key
                        guard !isBeingWatched else { continue }
                        self.unreadByConversation[key, default: 0] += 1
                        // A call that names us is directed traffic even though it came
                        // over the shared frequency.
                        if message.isRadio, message.mentions(callsign: self.ownCallsign) {
                            self.unreadRadioMentionsUs = true
                        }
                    }
                }
                self.hasReceivedChatSnapshot = true
                self.seenChatMessageIds.formUnion(arrived.map(\.id))
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
            self?.pairingCodeError = "Wrong code — please try again."
        }
        connection.onDebugSnapshotSaved = { [weak self] msg in
            guard let self, self.pendingSnapshotId == msg.snapshotId else { return }
            self.lastSnapshotPath = msg.path
            self.lastSnapshotError = nil
            self.attachScreenshotIfAvailable(snapshotId: msg.snapshotId)
        }
        connection.onDebugSnapshotNamed = { [weak self] msg in
            guard let self, self.pendingSnapshotId == msg.snapshotId else { return }
            if !msg.success { self.lastSnapshotError = msg.error ?? "Renaming failed." }
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

    // MARK: Demo mode

    /// Fills the app with sample data so it can be looked at without a plugin.
    ///
    /// Deliberately **not** persisted. A pilot who leaves it on and relaunches
    /// mid-flight would otherwise be shown invented controllers next to a real
    /// aircraft; every launch therefore starts in the real mode.
    var demoMode: Bool = false {
        didSet {
            guard demoMode != oldValue else { return }
            if demoMode {
                // A live socket alongside sample data would overwrite it on the next
                // full-state resend, so the link goes first.
                connection.disconnect()
                clearLiveState()
                DemoData.apply(to: self)
            } else {
                clearLiveState()
            }
        }
    }

    private func clearLiveState() {
        controllers = []
        chatMessages = []
        selcalAlerts = []
        nearbyAircraft = []
        radioState = nil
        flightPlan = nil
        subsystemStatus = nil
        etaMinutes = nil
        hasReceivedChatSnapshot = false
        unreadByConversation.removeAll()
        unreadRadioMentionsUs = false
        lastSendError = nil
    }

    /// The single way out of this app. Demo mode is a hard stop here rather than a
    /// check in each of the two dozen command methods, so a command added later
    /// cannot reach a real plugin from a demo session by being forgotten.
    private func send<T: Encodable>(_ command: T) {
        guard !demoMode else { return }
        connection.send(command)
    }

    /// Applies a tap to the sample radio state so the UI answers. Does nothing in a
    /// live session: there, the sim is the authority and the change comes back over
    /// the wire.
    private func demoRadio(_ mutate: (inout RadioState) -> Void) {
        guard demoMode, var state = radioState else { return }
        mutate(&state)
        radioState = state
    }

    private func demoSetPinned(_ callsign: String, _ pinned: Bool) {
        guard demoMode else { return }
        controllers = controllers.map { controller in
            guard controller.callsign == callsign else { return controller }
            var copy = controller
            copy.isPinned = pinned
            return copy
        }
    }

    private func demoAppend(channel: String, peer: String?, text: String) {
        guard demoMode else { return }
        // The same formatter the chat row parses with. Using a fresh one relied on
        // its default options happening to match, which would render an empty time
        // the day that default changed.
        let stamp = ISO8601DateFormatter.handoffPlain.string(from: Date())
        chatMessages.append(
            ChatMessage(
                channel: channel, direction: "outgoing", peer: peer, from: nil,
                text: text, frequencies: nil, timestamp: stamp
            )
        )
    }

    // MARK: Connection lifecycle

    func connect(host: String, port: Int = HandoffConnection.defaultPort) {
        // Connecting for real ends the demo; otherwise sample rows would sit in the
        // list until the plugin's first resend replaced them.
        demoMode = false
        lastHost = host
        lastPort = port
        pairingCodeError = nil
        lastSendError = nil
        controllers = []
        chatMessages = []
        selcalAlerts = []
        radioState = nil
        hasReceivedChatSnapshot = false
        unreadByConversation.removeAll()
        unreadRadioMentionsUs = false
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
        // Coming back to the foreground must not dial a plugin out from under a
        // demo session and silently swap sample controllers for real ones.
        guard !demoMode else { return }
        guard !lastHost.isEmpty else { return }
        // Mid-pairing, already trying, or deliberately refused -- reconnecting would
        // either interrupt the pilot or silently retry a server we just rejected.
        guard !connection.state.awaitsPilot, connection.state != .connecting else { return }
        connect(host: lastHost, port: lastPort)
    }

    // MARK: Chat

    func sendPrivateMessage(to callsign: String, text: String) {
        demoAppend(channel: "private", peer: callsign, text: text)
        send(SendPrivateMessageCommand(to: callsign, message: text))
    }

    func sendRadioMessage(_ text: String) {
        demoAppend(channel: "radio", peer: nil, text: text)
        send(SendRadioMessageCommand(message: text))
    }

    func dismissSelcal(_ callsign: String) {
        if demoMode { selcalAlerts.removeAll { $0.from == callsign } }
        send(DismissSelcalCommand(callsign: callsign))
    }

    // MARK: Radio

    func setCom1Frequency(_ mhz: Double) {
        demoRadio { $0.com1Frequency = VHFFrequency.encode(mhz: mhz) }
        send(SetFrequencyCommand(type: "setCom1Frequency", megahertz: mhz))
    }

    func setCom2Frequency(_ mhz: Double) {
        demoRadio { $0.com2Frequency = VHFFrequency.encode(mhz: mhz) }
        send(SetFrequencyCommand(type: "setCom2Frequency", megahertz: mhz))
    }

    func setCom1StandbyFrequency(_ mhz: Double) {
        demoRadio { $0.com1StandbyFrequency = VHFFrequency.encode(mhz: mhz) }
        send(SetFrequencyCommand(type: "setCom1StandbyFrequency", megahertz: mhz))
    }

    func setCom2StandbyFrequency(_ mhz: Double) {
        demoRadio { $0.com2StandbyFrequency = VHFFrequency.encode(mhz: mhz) }
        send(SetFrequencyCommand(type: "setCom2StandbyFrequency", megahertz: mhz))
    }

    func setCom1ActiveAndStandby(active: Double, standby: Double) {
        demoRadio {
            $0.com1Frequency = VHFFrequency.encode(mhz: active)
            $0.com1StandbyFrequency = VHFFrequency.encode(mhz: standby)
        }
        send(SetActiveAndStandbyCommand(type: "setCom1ActiveAndStandbyFrequency", megahertz: active, standbyMegahertz: standby))
    }

    func setCom2ActiveAndStandby(active: Double, standby: Double) {
        demoRadio {
            $0.com2Frequency = VHFFrequency.encode(mhz: active)
            $0.com2StandbyFrequency = VHFFrequency.encode(mhz: standby)
        }
        send(SetActiveAndStandbyCommand(type: "setCom2ActiveAndStandbyFrequency", megahertz: active, standbyMegahertz: standby))
    }

    func setTransponderCode(_ code: Int) {
        demoRadio { $0.transponderCode = code }
        send(SetTransponderCodeCommand(transponderCode: code))
    }

    func selectCom1Transmitter() {
        demoRadio { $0.com1TransmitEnabled = true; $0.com2TransmitEnabled = false }
        send(SelectTransmitterCommand(type: "selectCom1Transmitter"))
    }

    func selectCom2Transmitter() {
        demoRadio { $0.com2TransmitEnabled = true; $0.com1TransmitEnabled = false }
        send(SelectTransmitterCommand(type: "selectCom2Transmitter"))
    }

    func setCom1ReceiveEnabled(_ enabled: Bool) {
        demoRadio { $0.com1ReceiveEnabled = enabled }
        send(SetReceiveEnabledCommand(type: "setCom1ReceiveEnabled", enabled: enabled))
    }

    func setCom2ReceiveEnabled(_ enabled: Bool) {
        demoRadio { $0.com2ReceiveEnabled = enabled }
        send(SetReceiveEnabledCommand(type: "setCom2ReceiveEnabled", enabled: enabled))
    }

    // MARK: Controllers / flight plan

    func pinController(_ callsign: String) {
        demoSetPinned(callsign, true)
        send(PinControllerCommand(type: "pinController", callsign: callsign))
    }

    func clearPinnedController(_ callsign: String) {
        demoSetPinned(callsign, false)
        send(PinControllerCommand(type: "clearPinnedController", callsign: callsign))
    }

    func confirmDiversion() {
        send(SimpleCommand(type: "confirmDiversion"))
        diversionDestination = nil
    }

    func dismissDiversion() {
        send(SimpleCommand(type: "dismissDiversion"))
        diversionDestination = nil
    }

    func refreshFlightPlan() {
        send(SimpleCommand(type: "refreshFlightPlan"))
    }

    // MARK: Settings

    func setSimbriefCredentials(userId: String?, username: String?) {
        simbriefUserId = userId
        simbriefUsername = username
        send(SetSimbriefCredentialsCommand(simbriefUserId: userId, simbriefUsername: username))
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
        send(SetUpdateIntervalCommand(interval: interval))
    }

    // MARK: Debug mode

    func setDebugMode(_ enabled: Bool) {
        debugMode = enabled
        send(SetDebugModeCommand(enabled: enabled))
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

    /// Clears the badge for the conversation currently on screen -- not all of them,
    /// so an unread private message doesn't disappear just because the pilot glanced
    /// at the frequency.
    func markConversationRead(_ key: String) {
        visibleConversation = key
        unreadByConversation[key] = 0
        if key == ChatMessage.radioConversationKey { unreadRadioMentionsUs = false }
    }

    /// Kicks off the full snapshot round trip: save -> (once acknowledged) attach a
    /// view-scoped screenshot -> the plugin correlates both by `snapshotId`.
    func saveDebugSnapshot(appVersion: String) {
        let id = UUID().uuidString
        pendingSnapshotId = id
        lastSnapshotPath = nil
        lastSnapshotError = nil
        lastSnapshotName = nil
        send(SaveDebugSnapshotCommand(snapshotId: id, appVersion: appVersion))
    }

    func nameLastSnapshot(_ name: String) {
        guard let id = pendingSnapshotId else { return }
        lastSnapshotName = name
        send(NameDebugSnapshotCommand(snapshotId: id, name: name))
    }

    private func attachScreenshotIfAvailable(snapshotId: String) {
        guard attachDebugScreenshot else { return }
        guard let pngData = AppScreenshotter.captureCurrentWindowPNG() else { return }
        let base64 = pngData.base64EncodedString()
        send(AttachDebugSnapshotScreenshotCommand(snapshotId: snapshotId, screenshotPngBase64: base64))
    }
}
