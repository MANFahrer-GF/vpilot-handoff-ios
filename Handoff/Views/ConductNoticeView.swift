import SwiftUI

/// One-time "stay at your sim" notice (upstream issue #188, as on Android). VATSIM's Code of
/// Conduct forbids unattended connections (A9) and caps an unattended pilot connection at 30
/// minutes (B3(b)); a second screen that can chat, tune and even connect makes that easy to forget.
///
/// Closes only through the acknowledge button, so it can't be waved away by accident. Unlike the
/// Android notice it carries no penalty scale: VATSIM can change those numbers at any time, and the
/// link always leads to the current rules. The app may already reconnect to a known plugin behind
/// it -- nothing is sent to VATSIM by doing so, and the pilot can't act on anything until it is gone.
struct ConductNoticeView: View {
    var onAcknowledge: () -> Void

    static let storageKey = "handoff.conductNoticeAck.v1"
    static let codeOfConductUrl = URL(string: "https://vatsim.net/docs/policy/code-of-conduct")!

    /// Whether this install still has to show it. Persisted, so it appears once, not every launch.
    static var isPending: Bool { !HandoffDefaults.store.bool(forKey: storageKey) }

    static func acknowledge() {
        HandoffDefaults.store.set(true, forKey: storageKey)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                Text("Unattended connections")
                    .font(.title3.bold())

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Group {
                            Text("vPilot Remote lets you chat, tune the radios and connect from a second device. VATSIM's Code of Conduct still applies in full: you must not leave your connection unattended (A9). If you have to step away, disconnect. A pilot connection may never be unattended for more than 30 minutes (B3(b)).")
                            Text("Your VATSIM connection is made by vPilot on your sim PC. This app only works on your local network alongside it and does not change these rules.")
                        }
                        .foregroundStyle(.secondary)
                        Link("Read the VATSIM Code of Conduct", destination: Self.codeOfConductUrl)
                    }
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onAcknowledge) {
                    Text("I have read and understood the VATSIM Code of Conduct")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(20)
            .frame(maxWidth: 440)
            .frame(maxHeight: 560)
            .fixedSize(horizontal: false, vertical: true)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .padding(16)
        }
        .accessibilityAddTraits(.isModal)
    }
}
