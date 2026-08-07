import SwiftUI

/// The radio tile block. Two layouts, chosen by available width, mirroring how the
/// Android client reflows between a generous split and a narrow one: wide keeps the
/// documented 4x2 grid (COM1/MIC/COM2/XPDR over STBY/MON/STBY/MSG); narrow stacks
/// the two COM pairs and drops XPDR/MIC/MON/MSG onto their own row.
struct RadioTileGridView: View {
    @Environment(AppStore.self) private var store
    var compact: Bool
    var onOpenChat: () -> Void
    @Binding var activeSheet: DashboardSheet?

    var body: some View {
        if compact { narrowLayout } else { wideLayout }
    }

    // MARK: Layouts

    private var wideLayout: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                frequencyTile("COM1", store.radioState?.com1Frequency, .frequency(.com1Active))
                selectTile("MIC", active: transmitCom, onTap: toggleTransmitter)
                frequencyTile("COM2", store.radioState?.com2Frequency, .frequency(.com2Active))
                transponderTile
            }
            HStack(spacing: 8) {
                frequencyTile("STBY", store.radioState?.com1StandbyFrequency, .frequency(.com1Standby))
                selectTile("MON", active: receiveComs, onTap: toggleReceiver)
                frequencyTile("STBY", store.radioState?.com2StandbyFrequency, .frequency(.com2Standby))
                messageTile
            }
        }
    }

    private var narrowLayout: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                frequencyTile("COM1", store.radioState?.com1Frequency, .frequency(.com1Active))
                frequencyTile("COM2", store.radioState?.com2Frequency, .frequency(.com2Active))
            }
            HStack(spacing: 8) {
                frequencyTile(nil, store.radioState?.com1StandbyFrequency, .frequency(.com1Standby))
                frequencyTile(nil, store.radioState?.com2StandbyFrequency, .frequency(.com2Standby))
            }
            HStack(spacing: 8) {
                transponderTile
                selectTile("MIC", active: transmitCom, onTap: toggleTransmitter)
                selectTile("MON", active: receiveComs, onTap: toggleReceiver)
                messageTile
            }
        }
    }

    // MARK: Derived radio state

    private var transmitCom: [Int] {
        guard let radio = store.radioState else { return [] }
        var coms: [Int] = []
        if radio.com1TransmitEnabled { coms.append(1) }
        if radio.com2TransmitEnabled { coms.append(2) }
        return coms
    }

    /// Receive is genuinely independent per COM -- both lit at once is a normal
    /// "listening on both" state, so this is a list, not a single selection.
    private var receiveComs: [Int] {
        guard let radio = store.radioState else { return [] }
        var coms: [Int] = []
        if radio.com1ReceiveEnabled { coms.append(1) }
        if radio.com2ReceiveEnabled { coms.append(2) }
        return coms
    }

    private func toggleTransmitter() {
        transmitCom.contains(1) ? store.selectCom2Transmitter() : store.selectCom1Transmitter()
    }

    private func toggleReceiver() {
        // Cycle COM1 -> COM2 -> both, so every state the panel can report is reachable.
        let current = receiveComs
        if current == [1] {
            store.setCom1ReceiveEnabled(false)
            store.setCom2ReceiveEnabled(true)
        } else if current == [2] {
            store.setCom1ReceiveEnabled(true)
            store.setCom2ReceiveEnabled(true)
        } else {
            store.setCom1ReceiveEnabled(true)
            store.setCom2ReceiveEnabled(false)
        }
    }

    private func frequencyText(_ compressed: Int?) -> String {
        guard let compressed else { return "---.---" }
        return String(format: "%.3f", VHFFrequency.decode(compressed: compressed))
    }

    private var currentFrequencyText: String? {
        guard let radio = store.radioState else { return nil }
        let transmitting = radio.com1TransmitEnabled ? radio.com1Frequency : radio.com2Frequency
        guard let transmitting else { return nil }
        return String(format: "%.3f", VHFFrequency.decode(compressed: transmitting))
    }

    // MARK: Tiles

    private func frequencyTile(_ label: String?, _ compressed: Int?, _ sheet: DashboardSheet) -> some View {
        tileShell {
            activeSheet = sheet
        } content: {
            VStack(alignment: .leading, spacing: 2) {
                if let label {
                    Text(label).font(.caption2.bold()).foregroundStyle(.secondary)
                }
                Text(frequencyText(compressed))
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(compressed == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var transponderTile: some View {
        tileShell {
            activeSheet = .transponder
        } content: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("XPDR").font(.caption2.bold()).foregroundStyle(.secondary)
                    if store.radioState?.modeCEnabled == true {
                        Text("C").font(.caption2.bold()).foregroundStyle(.blue)
                    }
                }
                Text(store.radioState?.transponderCode.map { String(format: "%04d", $0) } ?? "----")
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundStyle(store.radioState?.transponderCode == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func selectTile(_ label: String, active: [Int], onTap: @escaping () -> Void) -> some View {
        tileShell(action: onTap) {
            VStack(spacing: 4) {
                Text(label).font(.caption2.bold()).foregroundStyle(.secondary)
                HStack(spacing: 3) {
                    if active.isEmpty {
                        indicator("–", color: Color(.systemGray4), textColor: .secondary)
                    } else {
                        ForEach(active, id: \.self) { com in
                            indicator("\(com)", color: com == 1 ? .teal : .purple, textColor: .white)
                        }
                    }
                }
            }
        }
    }

    private func indicator(_ text: String, color: Color, textColor: Color) -> some View {
        Text(text)
            .font(.system(.subheadline, design: .monospaced).bold())
            .foregroundStyle(textColor)
            .frame(width: 26, height: 26)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var messageTile: some View {
        tileShell(action: onOpenChat) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("MSG").font(.caption2.bold()).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Text("\(store.unreadChatCount)")
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(store.unreadChatCount > 0 ? Color.blue : Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                Text(currentFrequencyText ?? " ")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tileShell<Content: View>(
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            content()
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 62)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
