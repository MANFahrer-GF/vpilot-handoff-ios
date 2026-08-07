import SwiftUI

/// The per-controller tune card from README screenshot 3: callsign + frequency,
/// who's working the station, four one-tap tune targets, then the station's raw
/// ATIS/info lines. Takes the row's own colour so it reads as an extension of it.
struct ControllerTunePopover: View {
    @Environment(AppStore.self) private var store
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let controller: Controller
    var showDebug: Bool = false

    private var background: Color {
        themeStore.active.rowColor(for: controller, darkMode: colorScheme == .dark)
    }

    private var foreground: Color {
        themeStore.active.textColor(on: RGBColor(background))
    }

    private var frequencyMHz: Double {
        VHFFrequency.decode(compressed: controller.frequency)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(controller.callsign) · \(controller.frequencyMHzText)")
                        .font(.headline.monospaced())
                    Text(subtitle)
                        .font(.caption)
                        .opacity(0.85)
                }

                HStack(spacing: 10) {
                    tuneButton("COM1") {
                        store.setCom1Frequency(frequencyMHz)
                        dismiss()
                    }
                    tuneButton("COM2") {
                        store.setCom2Frequency(frequencyMHz)
                        dismiss()
                    }
                }

                HStack(spacing: 10) {
                    tuneButton("STBY 1") {
                        store.setCom1StandbyFrequency(frequencyMHz)
                        dismiss()
                    }
                    tuneButton("STBY 2") {
                        store.setCom2StandbyFrequency(frequencyMHz)
                        dismiss()
                    }
                }

                HStack(spacing: 10) {
                    secondaryButton(controller.isPinned ? "Unpin" : "Pin") {
                        controller.isPinned
                            ? store.clearPinnedController(controller.callsign)
                            : store.pinController(controller.callsign)
                        dismiss()
                    }
                    if controller.isSelcalActive {
                        secondaryButton("Dismiss SELCAL") {
                            store.dismissSelcal(controller.callsign)
                            dismiss()
                        }
                    }
                }

                if let lines = controller.textAtis, !lines.isEmpty {
                    Divider().overlay(foreground.opacity(0.3))
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line).font(.caption)
                        }
                    }
                }

                if showDebug, let debug = controller.debug {
                    Divider().overlay(foreground.opacity(0.3))
                    VStack(alignment: .leading, spacing: 3) {
                        if let bucketName = debug.bucketName {
                            Text("Bucket \(debug.bucket.map(String.init) ?? "?") · \(bucketName)")
                                .font(.caption.bold())
                        }
                        if let reason = debug.reason {
                            Text(reason).font(.caption2)
                        }
                    }
                }
            }
            .foregroundStyle(foreground)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(background)
        .frame(minWidth: 320, idealWidth: 380, minHeight: 260)
    }

    private var subtitle: String {
        [controller.stationName, controller.name, controller.ratingLabel]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func tuneButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(foreground.opacity(0.2))
                .foregroundStyle(foreground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
