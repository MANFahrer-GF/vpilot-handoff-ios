import SwiftUI

/// The whole app is this one screen. Layout follows the Android client's own
/// breakpoints: a wide window puts the RADIO panel permanently beside the
/// dashboard column; below that the dashboard takes the full width and the panel
/// becomes an overlay toggled from the MSG tile.
struct DashboardView: View {
    @Environment(AppStore.self) private var store

    @State private var activeSheet: DashboardSheet?
    @State private var showSettings = false
    @State private var chatOverlayShown = false
    @State private var chatTarget: String?

    /// Below this the dashboard alone owns the width and chat overlays on demand.
    private static let sideBySideMinWidth: CGFloat = 900
    /// Below this the radio tiles reflow and controller rows drop their detail column.
    private static let compactMaxWidth: CGFloat = 460
    private static let dashboardWidth: CGFloat = 560

    var body: some View {
        GeometryReader { geometry in
            let sideBySide = geometry.size.width >= Self.sideBySideMinWidth
            let dashboardWidth = sideBySide ? Self.dashboardWidth : geometry.size.width
            let compact = dashboardWidth < Self.compactMaxWidth

            HStack(spacing: 0) {
                dashboardColumn(compact: compact)
                    .frame(width: sideBySide ? Self.dashboardWidth : nil)

                if sideBySide {
                    Divider()
                    ChatPanelView(
                        privateTarget: $chatTarget,
                        showsCloseButton: false,
                        onClose: {}
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .overlay(alignment: .trailing) {
                if !sideBySide && chatOverlayShown {
                    chatOverlay(width: min(geometry.size.width, 520))
                }
            }
            .onChange(of: sideBySide) { _, isSideBySide in
                store.chatPanelVisible = isSideBySide || chatOverlayShown
                if isSideBySide { chatOverlayShown = false }
            }
            .onAppear { store.chatPanelVisible = sideBySide }
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .frequency(let target):
                FrequencyTuneSheet(target: target)
            case .transponder:
                TransponderEntrySheet()
            }
        }
        // Settings gets a full-screen cover rather than a sheet: iPadOS pins sheets
        // to a ~540pt form sheet, which is too narrow for the two-column
        // settings/credits layout the Android dialog uses.
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: pairingSheetShown) {
            PairingCodeView()
                .interactiveDismissDisabled()
        }
        .alert(
            "Diversion erkannt",
            isPresented: diversionAlertShown,
            presenting: store.diversionDestination
        ) { _ in
            Button("Bestätigen") { store.confirmDiversion() }
            Button("Verwerfen", role: .cancel) { store.dismissDiversion() }
        } message: { destination in
            Text("Neues Ziel laut VATSIM-Feed: \(destination)")
        }
        .onAppear {
            #if DEBUG
            if DemoData.isEnabled {
                DemoData.apply(to: store)
                return
            }
            #endif
            if store.lastHost.isEmpty { showSettings = true }
        }
    }

    private func dashboardColumn(compact: Bool) -> some View {
        VStack(spacing: 0) {
            appHeader
            RadioTileGridView(
                compact: compact,
                onOpenChat: openChat,
                activeSheet: $activeSheet
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 12)

            Divider()

            ControllerListView(compact: compact) { callsign in
                chatTarget = callsign
                openChat()
            }

            Divider()

            StatusFooterView { showSettings = true }
        }
        .background(.background)
    }

    private var appHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.caption)
                .foregroundStyle(.primary)
            Text("Handoff").font(.title3.bold())
            // Not "by sushi.at": that's the plugin and Android client this talks to,
            // credited in Settings. This app is a separate, unofficial iPad client.
            Text("iPad · inoffiziell").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("v\(appVersion)").font(.caption.monospaced()).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func chatOverlay(width: CGFloat) -> some View {
        ChatPanelView(
            privateTarget: $chatTarget,
            showsCloseButton: true,
            onClose: closeChat
        )
        .frame(width: width)
        .background(.background)
        .overlay(alignment: .leading) { Divider() }
        .shadow(radius: 12, x: -2)
        .transition(.move(edge: .trailing))
    }

    private func openChat() {
        withAnimation(.snappy) { chatOverlayShown = true }
        store.chatPanelVisible = true
        store.markChatRead()
    }

    private func closeChat() {
        withAnimation(.snappy) { chatOverlayShown = false }
        store.chatPanelVisible = false
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var pairingSheetShown: Binding<Bool> {
        Binding(
            get: { store.connection.state == .awaitingPairingCode },
            set: { _ in }
        )
    }

    private var diversionAlertShown: Binding<Bool> {
        Binding(
            get: { store.diversionDestination != nil },
            set: { _ in }
        )
    }
}
