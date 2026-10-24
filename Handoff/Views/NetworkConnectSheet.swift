import SwiftUI

/// "Connect to VATSIM" (upstream issue #171, plugin 0.8.0). Callsign and aircraft type are
/// prefilled from the latest SimBrief plan and stay editable; Connect stays disabled with the
/// reason shown until they are usable. The sheet stays open while vPilot answers, shows a failure
/// in place, and closes itself on success.
struct NetworkConnectSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var callsign = ""
    @State private var aircraftType = ""
    @State private var selcal = ""
    @State private var observer = false
    @State private var prefilled = false

    private var blockedReason: String? {
        NetworkConnect.blockedReason(callsign: callsign, aircraftType: aircraftType, observer: observer)
    }

    private var request: NetworkRequest? {
        store.networkRequest.flatMap { $0.kind == .connect ? $0 : nil }
    }

    private var waiting: Bool { request.map { !$0.finished } ?? false }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Callsign", text: $callsign)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                    Toggle("Connect as observer", isOn: $observer)
                    if !observer {
                        TextField("Aircraft type (ICAO)", text: $aircraftType)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.body.monospaced())
                        TextField("SELCAL (optional)", text: selcalField)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.body.monospaced())
                    }
                } footer: {
                    if let warning = observer ? nil : NetworkConnect.selcalWarning(selcal) {
                        Text(warning).foregroundStyle(.orange)
                    }
                }

                Section {
                    if let request {
                        HStack(spacing: 8) {
                            if request.finished {
                                Image(systemName: request.failed ? "xmark.circle.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(request.failed ? .red : .green)
                            } else {
                                ProgressView().controlSize(.small)
                            }
                            Text(request.status)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else if let blockedReason {
                        Text(blockedReason).foregroundStyle(.secondary)
                    } else {
                        Text("vPilot has to be running on your sim PC and connected to the simulator.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Connect to VATSIM")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // Verbatim: the cockpit stays English, and "Cancel" is translated for Settings.
                    Button { dismiss() } label: { Text(verbatim: "Cancel") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        store.connectToNetwork(
                            callsign: callsign, aircraftType: aircraftType, selcal: selcal, observer: observer
                        )
                    } label: {
                        Text(verbatim: "Connect")
                    }
                    .disabled(blockedReason != nil || waiting)
                }
            }
        }
        .onAppear(perform: prefill)
        .onChange(of: request?.succeeded) { _, succeeded in
            // Long enough to read "connected", short enough not to feel stuck.
            guard succeeded == true else { return }
            Task {
                try? await Task.sleep(for: .seconds(1))
                dismiss()
            }
        }
        .onDisappear {
            // A request still waiting is left alone: its answer still shows in the footer.
            if request?.finished == true { store.clearNetworkRequest() }
        }
    }

    /// Shows "AB-CD" while typing but keeps only the letters, as the form vPilot wants is built
    /// when sending.
    private var selcalField: Binding<String> {
        Binding(
            get: { NetworkConnect.formatSelcal(selcal) },
            set: { selcal = NetworkConnect.cleanSelcal($0) }
        )
    }

    private func prefill() {
        guard !prefilled else { return }
        prefilled = true
        // A finished request from an earlier attempt would otherwise greet the pilot with its result.
        if request?.finished == true { store.clearNetworkRequest() }
        let plan = store.flightPlan
        callsign = plan?.simbriefCallsign ?? plan?.vatsimCallsign ?? ""
        aircraftType = plan?.simbriefAircraftType ?? ""
        selcal = NetworkConnect.cleanSelcal(plan?.simbriefSelcal ?? "")
    }
}
