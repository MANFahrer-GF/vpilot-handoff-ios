import SwiftUI

/// The permanent footer plus its expandable status log (gallery/01-fullscreen and
/// the expanded variant): one line while collapsed, per-subsystem detail plus the
/// flight-plan cross-check and the plugin/socket line once opened.
struct StatusFooterView: View {
    @Environment(AppStore.self) private var store
    var onOpenSettings: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryRow

            if isExpanded {
                Divider()
                expandedDetail
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 8) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 9, height: 9)
                    Text(summaryText)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if store.flightPlan?.hasAnyWarning == true {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if !store.operations.isEmpty {
                        ProgressView().controlSize(.mini)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            Button {
                isExpanded.toggle()
            } label: {
                Image(systemName: isExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
            }
            .buttonStyle(.plain)

            Button {
                store.refreshFlightPlan()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var expandedDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if let error = store.lastSendError {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Array(store.operations.values), id: \.operationId) { operation in
                    HStack(spacing: 8) {
                        if operation.finished {
                            Image(systemName: operation.success == false ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(operation.success == false ? .red : .green)
                        } else {
                            ProgressView().controlSize(.mini)
                        }
                        Text(operation.status).font(.caption)
                    }
                }

                statusLine("Connected to Handoff vPilot plugin", store.connection.state == .connected)
                if let status = store.subsystemStatus {
                    statusLine("Connected to RadioHost", status.radioHostConnected)
                    statusLine("Connected to Simulator", status.simulatorConnected)
                    statusLine("Connected to Vatsim Info", status.vatsimDataFeedConnected)
                    statusLine("Fetched Simbrief flight plan", status.simbriefFetched)
                }

                if let plan = store.flightPlan {
                    Divider().padding(.vertical, 2)
                    detailRow("Active callsign", plan.vatsimCallsign ?? "–", warn: plan.vatsimCallsign == nil)
                    detailRow(
                        "SimBrief",
                        routeText(plan.simbriefOrigin, plan.simbriefDestination),
                        warn: false
                    )
                    detailRow(
                        "VATSIM",
                        plan.vatsimPlanMissing ? "MISSING" : routeText(plan.vatsimOrigin, plan.vatsimDestination),
                        warn: plan.vatsimPlanMissing || plan.simbriefVatsimMismatch
                    )
                    if plan.originMismatch == true {
                        warningLine("Position doesn't match the filed departure airport")
                    }
                    if plan.vatsimCidMismatch == true {
                        warningLine("Filed VATSIM plan may not be yours (CID mismatch)")
                    }
                }

                Divider().padding(.vertical, 2)
                Text(pluginLine)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 260)
    }

    private func routeText(_ origin: String?, _ destination: String?) -> String {
        guard let origin, let destination else { return "–" }
        return "\(origin) → \(destination)"
    }

    private func statusLine(_ label: LocalizedStringKey, _ ok: Bool) -> some View {
        HStack(spacing: 8) {
            Circle().fill(ok ? Color.green : Color.red).frame(width: 8, height: 8)
            Text(label).font(.caption)
        }
    }

    private func detailRow(_ label: LocalizedStringKey, _ value: String, warn: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(warn ? .orange : .secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(warn ? .orange : .primary)
        }
    }

    private func warningLine(_ text: LocalizedStringKey) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
    }

    private var pluginLine: String {
        let version = store.subsystemStatus.map { "vPilot plugin v\($0.pluginVersion)" } ?? "vPilot plugin –"
        guard !store.lastHost.isEmpty else { return version }
        let latency = store.connection.latencyMs.map { " · \($0)ms" } ?? ""
        return "\(version)\nwss://\(store.lastHost):\(store.lastPort)\(latency)"
    }

    private var statusColor: Color {
        if store.demoMode { return .orange }
        switch store.connection.state {
        case .connected: return .green
        case .connecting, .awaitingPairingCode: return .orange
        case .disconnected, .failed, .identityChanged: return .red
        }
    }

    private var summaryText: String {
        // Wins over the connection state on purpose: in demo mode there is no
        // connection to describe, and "Disconnected" next to a full controller list
        // would read as a glitch rather than as "none of this is real".
        if store.demoMode { return "DEMO · sample data, no plugin" }
        switch store.connection.state {
        case .disconnected: return "Disconnected"
        case .identityChanged: return "PC identity changed"
        case .connecting: return "Connecting"
        case .awaitingPairingCode: return "Pairing"
        case .failed(let message): return message
        case .connected:
            guard let plan = store.flightPlan else { return "Connected" }
            let callsign = plan.vatsimCallsign ?? plan.simbriefCallsign
            let route = routeText(
                plan.vatsimOrigin ?? plan.simbriefOrigin,
                plan.vatsimDestination ?? plan.simbriefDestination
            )
            guard let callsign else { return route == "–" ? "Connected" : route }
            return route == "–" ? callsign : "\(callsign) · \(route)"
        }
    }
}
