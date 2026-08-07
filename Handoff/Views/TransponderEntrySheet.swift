import SwiftUI

/// gallery/08-xdpr-code.png: 4-digit entry, 8 and 9 disabled (civil squawk digits
/// are octal), common-code presets along the bottom.
struct TransponderEntrySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var digits: [Character] = []

    private static let maxDigits = 4
    private static let presets = [2000, 1000, 7000, 1200]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                entryDisplay
                keypad
                presetRow
            }
            .padding(20)
        }
        .onAppear(perform: prefill)
    }

    private var header: some View {
        HStack {
            Text("TRANSPONDER").font(.headline)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Squawk digits are octal, so 8 and 9 have no place on the pad at all -- their
    /// grid slots carry 0 and CLR instead, matching the Android dialog. Digits dim
    /// once four are entered, since nothing more can be typed until something is
    /// cleared.
    private var keypad: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(1...7, id: \.self) { number in
                keypadButton(String(number), enabled: canAppend) { append(Character(String(number))) }
            }
            keypadButton("0", enabled: canAppend) { append("0") }
            keypadButton("CLR", enabled: !digits.isEmpty, tint: .red.opacity(0.15), textColor: .red) {
                digits.removeAll()
            }

            keypadButton("⌫", enabled: !digits.isEmpty) { digits.removeLast() }
            Color.clear.frame(height: 1)
            Button(action: confirm) {
                Image(systemName: "checkmark")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(digits.count == Self.maxDigits ? Color.green : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(digits.count != Self.maxDigits)
        }
    }

    private var canAppend: Bool { digits.count < Self.maxDigits }

    private var presetRow: some View {
        HStack(spacing: 10) {
            ForEach(Self.presets, id: \.self) { preset in
                Button {
                    store.setTransponderCode(preset)
                    dismiss()
                } label: {
                    Text(String(format: "%04d", preset))
                        .font(.subheadline.monospaced().bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var displayText: String {
        var padded = digits
        while padded.count < Self.maxDigits { padded.append("-") }
        return String(padded)
    }

    private func append(_ digit: Character) {
        guard digits.count < Self.maxDigits else { return }
        digits.append(digit)
    }

    private func prefill() {
        guard let code = store.radioState?.transponderCode else { return }
        digits = Array(String(format: "%04d", code))
    }

    private func confirm() {
        guard digits.count == Self.maxDigits, let code = Int(String(digits)) else { return }
        store.setTransponderCode(code)
        dismiss()
    }

    private func keypadButton(
        _ label: String,
        enabled: Bool = true,
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
                .foregroundStyle(enabled ? textColor : Color.secondary.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
