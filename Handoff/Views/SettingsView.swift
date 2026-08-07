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
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
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
            section("SIMBRIEF") {
                labeledField("SimBrief user ID", text: $simbriefUserId, keyboard: .numberPad)
                labeledField("SimBrief username (fallback)", text: $simbriefUsername, placeholder: "optional")
                Button("Speichern & Aktualisieren") {
                    store.setSimbriefCredentials(
                        userId: simbriefUserId.isEmpty ? nil : simbriefUserId,
                        username: simbriefUsername.isEmpty ? nil : simbriefUsername
                    )
                }
                .buttonStyle(.borderedProminent)
            }

            section("DARSTELLUNG") {
                Picker("Erscheinungsbild", selection: appearanceBinding) {
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
                        Label("Controller-Farben", systemImage: "paintpalette")
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

            section("PLUGIN-VERBINDUNG") {
                labeledField("Manuelle IP (falls die Suche fehlschlägt)", text: $hostText, keyboard: .numbersAndPunctuation)

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
                    Button("Verbinden") {
                        store.connect(host: hostText, port: store.lastPort)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(hostText.isEmpty)

                    if store.connection.state == .connected {
                        Button("Trennen", role: .destructive) { store.disconnect() }
                            .buttonStyle(.bordered)
                    }
                }

                ForEach(discovered, id: \.host) { result in
                    Button("Gefunden: \(result.host):\(result.port)") {
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

            section("STANDARD-KANALRASTER") {
                Picker("Kanalraster", selection: spacingBinding) {
                    Text("25 kHz").tag(false)
                    Text("8.33 kHz").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("Womit das Frequenz-Tastenfeld startet. Dort lässt es sich für eine einzelne Eingabe umschalten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            section("FREQUENZ-TASTENFELD") {
                Picker("Prüfung", selection: blockInvalidBinding) {
                    Text("Ungültige blockieren").tag(true)
                    Text("Alle zulassen").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("Ob Frequenzen abseits des Kanalrasters gesendet werden dürfen. Außerhalb von 118.000–136.990 wird immer blockiert — die verwirft das Plugin ohnehin kommentarlos.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            section("UPDATE-INTERVALL") {
                Picker("Tempo", selection: updateIntervalBinding) {
                    Text("Schnell").tag("fast")
                    Text("Normal").tag("normal")
                    Text("Langsam").tag("slow")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("Wie oft Controller-Liste und Funkstatus aktualisiert werden. \"Langsam\" hilft, wenn die Darstellung träge wirkt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            section("DIAGNOSE") {
                Toggle("Debug-Modus", isOn: debugModeBinding)
                Text("Zeigt die Ranking-Begründung pro Controller und erlaubt einen Diagnose-Schnappschuss für die Plugin-Entwicklung.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if store.debugMode {
                    Toggle("Screenshot anhängen", isOn: attachScreenshotBinding)
                    Text("Hängt ein Bild des Handoff-Fensters an den Schnappschuss. Nur dieses Fenster — iOS erlaubt keiner App, andere Apps mitzufotografieren, anders als die Vollbild-Option der Android-Version.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button("Diagnose-Schnappschuss speichern") {
                        store.saveDebugSnapshot(appVersion: appVersion)
                    }
                    .buttonStyle(.bordered)

                    if let path = store.lastSnapshotPath {
                        Label("Auf dem PC gespeichert", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text(path).font(.caption2.monospaced()).foregroundStyle(.secondary)
                        HStack {
                            TextField("Name für den Schnappschuss", text: $snapshotName)
                                .textFieldStyle(.roundedBorder)
                            Button("Benennen") {
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
            }

            section("PROJEKT") {
                creditRow("iPad-App", "Thomas Kant, Gifhorn")
                creditRow("Entwickelt mit", "Claude (Anthropic)")
                Text("Diese iPad-App ist ein eigenständiger, inoffizieller Client für dasselbe Plugin, gebaut nach dessen öffentlicher Protokoll-Dokumentation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            section("MITWIRKEN") {
                linkRow(
                    "Diese iPad-App",
                    "MANFahrer-GF/vpilot-handoff-ios",
                    url: "https://github.com/MANFahrer-GF/vpilot-handoff-ios"
                )
                linkRow(
                    "Plugin & Android-App",
                    "sushiat/vpilot-handoff",
                    url: "https://github.com/sushiat/vpilot-handoff"
                )
                Text("Fehler in dieser iPad-App bitte im ersten Repository melden, nicht beim Original-Projekt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let status = store.subsystemStatus {
                section("PLUGIN") {
                    LabeledContent("Version", value: status.pluginVersion)
                    if let interval = status.updateInterval {
                        LabeledContent("Intervall", value: interval)
                    }
                }
            }
        }
    }

    // MARK: Building blocks

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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
    private func linkRow(_ label: String, _ value: String, url: String) -> some View {
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
        _ label: String,
        text: Binding<String>,
        placeholder: String = "",
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

    private func creditRow(_ label: String, _ value: String, license: String? = nil) -> some View {
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
                discoveryError = "Nichts gefunden — Firewall auf dem PC prüfen oder IP manuell eingeben."
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

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Hell"
        case .dark: return "Dunkel"
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
