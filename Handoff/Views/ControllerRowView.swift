import SwiftUI

/// One controller row. Tapping the body opens the tune popover; the pin and chat
/// icons are their own hit targets. Deliberately built from nested Buttons with
/// explicit `contentShape`s rather than a container `onTapGesture` -- the latter
/// competes with the inner buttons and swallows their taps.
struct ControllerRowView: View {
    @Environment(\.colorScheme) private var colorScheme

    let controller: Controller
    let theme: ControllerTheme
    var compact: Bool = false
    var showDebug: Bool = false
    var onTap: () -> Void
    var onPinTap: () -> Void
    var onChatTap: () -> Void

    @State private var flashOn = false

    private var isDark: Bool { colorScheme == .dark }

    private var baseColor: Color {
        theme.rowColor(for: controller, darkMode: isDark)
    }

    private var background: Color {
        controller.isContactMe && flashOn ? theme.contactMeAlert.color : baseColor
    }

    /// Contrast is always judged against the row's own resting colour, so the
    /// contact-me flash doesn't make the text strobe between black and white too.
    private var foreground: Color {
        theme.textColor(on: RGBColor(baseColor))
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onTap) {
                rowContent
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 12) {
                Button(action: onPinTap) {
                    Image(systemName: controller.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 17))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(controller.isPinned ? "Unpin" : "Pin")

                Button(action: onChatTap) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 17))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Chat with \(controller.callsign)")
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear(perform: syncFlash)
        .onChange(of: controller.isContactMe) { _, _ in syncFlash() }
    }

    @ViewBuilder
    private var rowContent: some View {
        if compact {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(controller.callsign).font(.headline.monospaced())
                    statusTag
                }
                Text(controller.frequencyMHzText)
                    .font(.title3.monospacedDigit().bold())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(controller.callsign)
                        .font(.headline.monospaced())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    statusTag
                }

                Text(controller.frequencyMHzText)
                    .font(.title3.monospacedDigit().bold())
                    .layoutPriority(1)

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 1) {
                    if let stationName = controller.stationName {
                        Text(stationName)
                            .font(.caption.bold())
                            .lineLimit(1)
                    }
                    if let name = controller.name {
                        Text(name)
                            .font(.caption2)
                            .opacity(0.85)
                            .lineLimit(1)
                    }
                }

                if let rating = controller.ratingLabel {
                    Text(rating)
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(foreground.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
        }
    }

    @ViewBuilder
    private var statusTag: some View {
        if controller.isContactMe {
            tag("CONTACT ME")
        } else if controller.isNext {
            tag("NEXT")
        } else if controller.isLikelyNext {
            tag("NEXT?")
        } else if controller.isSelcalActive {
            tag("SELCAL")
        } else if controller.isCurrent {
            tag("TUNED")
        } else if controller.isStandbyTuned {
            tag("STBY")
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(foreground.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// An unresolved contact-me flashes the row twice a second until the pilot
    /// tunes the frequency (protocol.md clears `isContactMe` at that point).
    private func syncFlash() {
        guard controller.isContactMe else {
            flashOn = false
            return
        }
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            flashOn = true
        }
    }
}
