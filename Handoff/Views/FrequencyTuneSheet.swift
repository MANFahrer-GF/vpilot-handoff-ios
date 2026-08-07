import SwiftUI

/// Numeric-keypad tuning dialog (gallery/07-com-tune.png). Entry starts pre-filled
/// with the tile's current value; digits type into a fixed 3+3 civil-VHF shape.
/// The whole body scrolls -- on iPad a sheet is a fixed-height form sheet, and the
/// keypad plus action row is taller than it in landscape.
struct FrequencyTuneSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let target: FrequencyTarget

    @State private var digits: [Character] = []
    /// Seeded from the pilot's default in Settings; toggling here is a one-off
    /// override for this entry, not a change of the default.
    @State private var spacing833 = true

    private static let maxDigits = 6

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                entryDisplay
                keypad
                actionRow
                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .onAppear {
            spacing833 = store.channelSpacing833
            prefill()
        }
    }

    private var header: some View {
        HStack {
            Text(target.title).font(.headline)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private var entryDisplay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ENTRY").font(.caption.bold()).foregroundStyle(.secondary)
            Text(displayText)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var keypad: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(1...9, id: \.self) { number in
                keypadButton(String(number)) { append(Character(String(number))) }
            }
            keypadButton("CLR", tint: .red.opacity(0.15), textColor: .red) { digits.removeAll() }
            keypadButton("0") { append("0") }
            keypadButton("⌫") { if !digits.isEmpty { digits.removeLast() } }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            // Labelled explicitly: the original shows both values stacked, which
            // leaves it unclear that it's a toggle at all, let alone which one is
            // active. Caption plus the live value removes the guesswork.
            Button {
                spacing833.toggle()
            } label: {
                VStack(spacing: 1) {
                    Text("RASTER")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text(grid.label)
                        .font(.subheadline.monospaced().bold())
                    Text("kHz")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Kanalraster, aktuell \(spacing833 ? "8,33" : "25") Kilohertz. Antippen zum Umschalten.")

            Button(action: swapActiveStandby) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button(action: confirm) {
                Image(systemName: "checkmark")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(parsedValue == nil ? Color.gray.opacity(0.4) : Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(parsedValue == nil)
        }
    }

    // MARK: Entry handling

    private var displayText: String {
        var padded = digits
        while padded.count < Self.maxDigits { padded.append("-") }
        return "\(String(padded[0..<3])).\(String(padded[3..<6]))"
    }

    /// Nil until six digits are in AND the result is a legal channel for the selected
    /// spacing -- the plugin silently drops out-of-range values, so catching it here
    /// is the only way the pilot ever finds out the entry was rejected.
    private var parsedValue: Double? {
        guard digits.count == Self.maxDigits else { return nil }
        guard let value = Double("\(String(digits[0..<3])).\(String(digits[3..<6]))") else { return nil }
        // The band limit always applies -- the plugin drops anything outside it, so
        // letting it through would just fail silently. The channel grid is the part
        // "Allow all" relaxes.
        guard VHFChannelGrid.inBand(value) else { return nil }
        guard !store.blockInvalidFrequencies || grid.contains(value) else { return nil }
        return value
    }

    private var validationError: String? {
        guard digits.count == Self.maxDigits, parsedValue == nil else {
            // Off-grid but accepted because the pilot chose "Allow all" -- worth
            // saying so, otherwise a typo looks like a deliberate entry.
            if !store.blockInvalidFrequencies, let value = parsedValue, !grid.contains(value) {
                return "Außerhalb des \(grid.label)-kHz-Rasters — wird trotzdem gesendet."
            }
            return nil
        }
        guard let value = Double("\(String(digits[0..<3])).\(String(digits[3..<6]))"),
              VHFChannelGrid.inBand(value) else {
            return "Außerhalb des Flugfunkbands (118.000–136.990)."
        }
        // Only offer the other grid when it would actually accept this value --
        // suggesting it otherwise sends the pilot in a circle.
        return grid.other.contains(value)
            ? "Keine gültige \(grid.label)-kHz-Frequenz — auf \(grid.other.label) umschalten?"
            : "Keine gültige \(grid.label)-kHz-Frequenz."
    }

    private var grid: VHFChannelGrid { spacing833 ? .khz833 : .khz25 }

    private func append(_ digit: Character) {
        guard digits.count < Self.maxDigits else { return }
        digits.append(digit)
    }

    private func prefill() {
        let current: Int?
        switch target {
        case .com1Active: current = store.radioState?.com1Frequency
        case .com1Standby: current = store.radioState?.com1StandbyFrequency
        case .com2Active: current = store.radioState?.com2Frequency
        case .com2Standby: current = store.radioState?.com2StandbyFrequency
        }
        guard let current else { return }
        let text = String(format: "%.3f", VHFFrequency.decode(compressed: current))
            .replacingOccurrences(of: ".", with: "")
        digits = Array(text.prefix(Self.maxDigits))
    }

    /// Swaps that COM's active and standby in one command -- protocol.md warns that
    /// two separate writes land over a second apart because each blocks the plugin's
    /// SimConnect queue for its own settle wait.
    private func swapActiveStandby() {
        guard let radio = store.radioState else { return }
        if target.isCom1 {
            let active = radio.com1Frequency.map(VHFFrequency.decode) ?? 0
            let standby = radio.com1StandbyFrequency.map(VHFFrequency.decode) ?? 0
            store.setCom1ActiveAndStandby(active: standby, standby: active)
        } else {
            let active = radio.com2Frequency.map(VHFFrequency.decode) ?? 0
            let standby = radio.com2StandbyFrequency.map(VHFFrequency.decode) ?? 0
            store.setCom2ActiveAndStandby(active: standby, standby: active)
        }
        dismiss()
    }

    private func confirm() {
        guard let value = parsedValue else { return }
        switch target {
        case .com1Active: store.setCom1Frequency(value)
        case .com1Standby: store.setCom1StandbyFrequency(value)
        case .com2Active: store.setCom2Frequency(value)
        case .com2Standby: store.setCom2StandbyFrequency(value)
        }
        dismiss()
    }

    private func keypadButton(
        _ label: String,
        tint: Color = Color(.secondarySystemBackground),
        textColor: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(tint)
                .foregroundStyle(textColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
