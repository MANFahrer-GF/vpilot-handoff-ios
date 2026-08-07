import SwiftUI

struct ControllerListView: View {
    @Environment(AppStore.self) private var store
    @Environment(ThemeStore.self) private var themeStore
    var compact: Bool
    var onOpenChat: (String) -> Void

    @State private var tunePopoverCallsign: String?

    private var visibleControllers: [Controller] {
        store.hideTuned ? store.controllers.filter { !$0.isCurrent } : store.controllers
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if store.debugMode, let debug = store.controllersDebug {
                debugSummary(debug)
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(visibleControllers) { controller in
                        ControllerRowView(
                            controller: controller,
                            theme: themeStore.active,
                            compact: compact,
                            showDebug: store.debugMode,
                            onTap: { tunePopoverCallsign = controller.callsign },
                            onPinTap: {
                                controller.isPinned
                                    ? store.clearPinnedController(controller.callsign)
                                    : store.pinController(controller.callsign)
                            },
                            onChatTap: { onOpenChat(controller.callsign) }
                        )
                        .popover(isPresented: popoverBinding(for: controller.callsign)) {
                            ControllerTunePopover(controller: controller, showDebug: store.debugMode)
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
    }

    private var header: some View {
        HStack {
            // Counts what's on screen, not what arrived -- with "Hide tuned" on,
            // a total would contradict the rows the pilot can actually see.
            Text("CONTROLLERS · \(visibleControllers.count)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Spacer()

            if let eta = store.etaMinutes {
                Text("ETA \(Int(eta))′")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                store.hideTuned.toggle()
            } label: {
                HStack(spacing: 6) {
                    Text("Hide tuned").font(.caption)
                    Image(systemName: store.hideTuned ? "checkmark.square.fill" : "square")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func popoverBinding(for callsign: String) -> Binding<Bool> {
        Binding(
            get: { tunePopoverCallsign == callsign },
            set: { isPresented in
                if !isPresented, tunePopoverCallsign == callsign { tunePopoverCallsign = nil }
            }
        )
    }

    @ViewBuilder
    private func debugSummary(_ debug: ControllersDebug) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let phase = debug.phaseOfFlight {
                Text("Phase: \(phase) · \(debug.ownshipAltitudeTrue.map { "\(Int($0)) ft" } ?? "–")")
                    .font(.caption2)
            }
            if let detail = debug.etaCalculationDetail {
                Text(detail).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }
}
