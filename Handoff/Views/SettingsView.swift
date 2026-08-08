import SwiftUI

/// gallery/05-settings.png: two columns on a wide sheet -- settings left, credits
/// and contribute links right -- collapsing to one column when there isn't room.
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.dismiss) private var dismiss

    @State private var showThemeEditor = false

    @State private var simbriefUserId = ""
    @State private var simbriefUsername = ""
    @State private var hostText = ""
    @State private var isDiscovering = false
    @State private var discovered: [DiscoveryResult] = []
    @State private var discoveryError: String?
    @State private var snapshotName = ""

    private let discovery = DiscoveryService()

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    let twoColumn = geometry.size.width >= 700
                    Group {
                        if twoColumn {
                            HStack(alignment: .top, spacing: 40) {
                                settingsColumn.frame(maxWidth: .infinity, alignment: .leading)
                                creditsColumn.frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 28) {
                                settingsColumn
                                creditsColumn
                            }
                        }
                    }
                    .padding(24)
                    // Keeps the dialog readable on a full-screen iPad instead of
                    // stretching each field the whole way across.
                    .frame(maxWidth: 1000)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showThemeEditor) {
                ThemeEditorView()
            }
            // Seeded once per presentation from the store rather than only when the
            // local field is blank -- otherwise clearing a field and reopening would
            // silently refill it.
            .task {
                simbriefUserId = store.simbriefUserId ?? ""
                simbriefUsername = store.simbriefUsername ?? ""
                hostText = store.lastHost
            }
        }
    }

    // MARK: Left column

    private var settingsColumn: some View {
        VStack(alignment: .leading, spacing: 26) {
            // First in the column deliberately. This screen opens by itself on a
            // first launch with no host configured, so it is what someone sees who
            // has no plugin yet -- a pilot deciding whether to set one up, or an App
            // Store reviewer who has no Windows PC at all.
            section("TRY IT WITHOUT A PLUGIN") {
                Toggle(isOn: demoBinding) {
                    Label("Demo mode", systemImage: "theatermasks")
                }
                Text("Fills the app with made-up controllers, messages and radio state so you can see what it does. Nothing is sent anywhere, and the header and status line both read DEMO while it is on. Switching it off, or connecting to a plugin, clears the sample data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if store.demoMode {
                    Label("Demo mode is on. Nothing you see is real traffic.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            section("SIMBRIEF") {
                labeledField("SimBrief user ID", text: $simbriefUserId, keyboard: .numberPad)
                labeledField("SimBrief username (fallback)", text: $simbriefUsername, placeholder: "optional")
                Button("Save & refresh") {
                    store.setSimbriefCredentials(
                        userId: simbriefUserId.isEmpty ? nil : simbriefUserId,
                        username: simbriefUsername.isEmpty ? nil : simbriefUsername
                    )
                }
                .buttonStyle(.borderedProminent)
            }

            section("APPEARANCE") {
                Picker("Appearance", selection: appearanceBinding) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Button {
                    showThemeEditor = true
                } label: {
                    HStack {
                        Label("Controller colours", systemImage: "paintpalette")
                        Spacer()
                        Text(themeStore.active.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            section("PLUGIN CONNECTION") {
                labeledField("Manual IP (if discovery fails)", text: $hostText, keyboard: .numbersAndPunctuation)

                HStack {
                    Text("Status:").font(.callout).foregroundStyle(.secondary)
                    Text(connectionStatusText)
                        .font(.callout.bold())
                        .foregroundStyle(connectionStatusColor)
                    Spacer()
                    Button {
                        Task { await runDiscovery() }
                    } label: {
                        if isDiscovering { ProgressView() } else { Text("Auto-detect") }
                    }
                }

                HStack(spacing: 10) {
                    Button("Connect") {
                        store.connect(host: hostText, port: store.lastPort)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(hostText.isEmpty)

                    if store.connection.state == .connected {
                        Button("Disconnect", role: .destructive) { store.disconnect() }
                            .buttonStyle(.bordered)
                    }
                }

                ForEach(discovered, id: \.host) { result in
                    Button("Found: \(result.host):\(result.port)") {
                        hostText = result.host
                        // Discovery reports the port the plugin actually listens on;
                        // assuming the default would strand a moved installation.
                        store.connect(host: result.host, port: result.port)
                        dismiss()
                    }
                }

                if let discoveryError {
                    Text(discoveryError).font(.caption).foregroundStyle(.secondary)
                }
            }

            section("DEFAULT CHANNEL SPACING") {
                Picker("Channel spacing", selection: spacingBinding) {
                    Text("25 kHz").tag(false)
                    Text("8.33 kHz").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("What the frequency keypad starts on. It can be switched there for a single entry.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            section("FREQUENCY KEYPAD") {
                Picker("Validation", selection: blockInvalidBinding) {
                    Text("Block invalid").tag(true)
                    Text("Allow all").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("Whether frequencies off the channel grid may be sent. Anything outside 118.000–136.990 is always blocked — the plugin discards those silently anyway.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            section("UPDATE INTERVAL") {
                Picker("Rate", selection: updateIntervalBinding) {
                    Text("Fast").tag("fast")
                    Text("Normal").tag("normal")
                    Text("Slow").tag("slow")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("How often the controller list and radio state refresh. \"Slow\" helps if the display feels sluggish.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            section("DIAGNOSTICS") {
                Toggle("Debug mode", isOn: debugModeBinding)
                Text("Shows the ranking rationale per controller and allows a diagnostic snapshot for plugin development.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if store.debugMode {
                    Toggle("Attach screenshot", isOn: attachScreenshotBinding)
                    Text("Attaches an image of the Handoff window to the snapshot. That window only — iOS never lets an app photograph other apps, unlike the Android version's full-screen option.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Save diagnostic snapshot") {
                        store.saveDebugSnapshot(appVersion: appVersion)
                    }
                    .buttonStyle(.bordered)

                    if let path = store.lastSnapshotPath {
                        Label("Saved on the PC", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text(path).font(.caption2.monospaced()).foregroundStyle(.secondary)
                        HStack {
                            TextField("Name for the snapshot", text: $snapshotName)
                                .textFieldStyle(.roundedBorder)
                            Button("Name it") {
                                store.nameLastSnapshot(snapshotName)
                                snapshotName = ""
                            }
                            .disabled(snapshotName.isEmpty)
                        }
                    }
                    if let error = store.lastSnapshotError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
            }
        }
    }

    // MARK: Right column

    private var creditsColumn: some View {
        VStack(alignment: .leading, spacing: 26) {
            section("CREDITS") {
                creditRow("Airport & FIR data", "VATSpy", license: "CC BY-SA 4.0")
                creditRow("Sector boundaries", "VatGlasses", license: "CC BY-NC-SA 4.0")
                creditRow("Live network data", "VATSIM Data Feed")
                creditRow("Flight plan data", "SimBrief by Navigraph")
                creditRow("Pilot client", "vPilot")
                // The mark is sushi.at's, reused with permission so the iPad app
                // isn't visually a stranger to the plugin it talks to.
                creditRow("App icon", "sushi.at")
            }

            section("PROJECT") {
                creditRow("iPad app", "Thomas Kant, Gifhorn")
                creditRow("Built with", "Claude (Anthropic)")
                Text("This iPad app is an independent, unofficial client for the same plugin, built from its public protocol documentation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            section("CONTRIBUTE") {
                linkRow(
                    "This iPad app",
                    "MANFahrer-GF/vpilot-handoff-ios",
                    url: "https://github.com/MANFahrer-GF/vpilot-handoff-ios"
                )
                linkRow(
                    "Plugin & Android app",
                    "sushiat/vpilot-handoff",
                    url: "https://github.com/sushiat/vpilot-handoff"
                )
                Text("Please report bugs in this iPad app in the first repository, not to the upstream project.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let status = store.subsystemStatus {
                section("PLUGIN") {
                    LabeledContent("Version", value: status.pluginVersion)
                    if let interval = status.updateInterval {
                        LabeledContent("Interval", value: interval)
                    }
                }
            }
        }
    }

    // MARK: Building blocks

    @ViewBuilder
    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption.bold()).foregroundStyle(.secondary)
                Divider()
            }
            content()
        }
    }

    /// Same shape as `creditRow`, but the value opens the repository. Only ever
    /// built from the two literal URLs above -- nothing here is composed from data
    /// the plugin sends.
    @ViewBuilder
    private func linkRow(_ label: LocalizedStringKey, _ value: String, url: String) -> some View {
        if let destination = URL(string: url) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Link(destination: destination) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.caption)
                        Text(value).font(.callout.bold())
                        Image(systemName: "arrow.up.forward.square")
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                }
            }
        }
    }

    private func labeledField(
        _ label: LocalizedStringKey,
        text: Binding<String>,
        placeholder: LocalizedStringKey = "",
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.callout).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
    }

    private func creditRow(_ label: LocalizedStringKey, _ value: String, license: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(value).font(.callout.bold())
                Spacer()
                if let license {
                    Text(license)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    // MARK: Bindings

    private var demoBinding: Binding<Bool> {
        Binding(get: { store.demoMode }, set: { store.demoMode = $0 })
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(get: { store.appearance }, set: { store.appearance = $0 })
    }

    private var attachScreenshotBinding: Binding<Bool> {
        Binding(get: { store.attachDebugScreenshot }, set: { store.attachDebugScreenshot = $0 })
    }

    private var spacingBinding: Binding<Bool> {
        Binding(get: { store.channelSpacing833 }, set: { store.channelSpacing833 = $0 })
    }

    private var blockInvalidBinding: Binding<Bool> {
        Binding(get: { store.blockInvalidFrequencies }, set: { store.blockInvalidFrequencies = $0 })
    }

    private var updateIntervalBinding: Binding<String> {
        Binding(
            get: { store.subsystemStatus?.updateInterval ?? "normal" },
            set: { store.setUpdateInterval($0) }
        )
    }

    private var debugModeBinding: Binding<Bool> {
        Binding(get: { store.debugMode }, set: { store.setDebugMode($0) })
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var connectionStatusText: String {
        switch store.connection.state {
        case .connected: return "CONNECTED"
        case .connecting: return "CONNECTING"
        case .awaitingPairingCode: return "PAIRING"
        case .failed: return "FAILED"
        case .identityChanged: return "IDENTITY CHANGED"
        case .disconnected: return "DISCONNECTED"
        }
    }

    private var connectionStatusColor: Color {
        switch store.connection.state {
        case .connected: return .green
        case .connecting, .awaitingPairingCode: return .orange
        case .disconnected, .failed, .identityChanged: return .red
        }
    }

    private func runDiscovery() async {
        isDiscovering = true
        discoveryError = nil
        defer { isDiscovering = false }
        do {
            discovered = try await discovery.discover()
            if discovered.isEmpty {
                discoveryError = "Nothing found — check the firewall on the PC or enter the IP manually."
            }
        } catch {
            discoveryError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    static let storageKey = "handoff.appearance"

    static var persisted: AppearanceMode {
        HandoffDefaults.store.string(forKey: storageKey)
            .flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }

    /// LocalizedStringKey, not String: a picker built from plain Strings renders
    /// untranslated no matter what the catalog says.
    var label: LocalizedStringKey {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
