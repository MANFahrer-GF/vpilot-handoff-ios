import SwiftUI

/// gallery/02-pairing.png. The identity-changed warning is the security-relevant
/// part: a certificate that no longer matches the pinned one means either a
/// reinstalled plugin or someone else answering on that address, and only the pilot
/// can tell those apart -- so it's stated plainly rather than auto-accepted.
struct PairingCodeView: View {
    @Environment(AppStore.self) private var store
    @State private var code = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Kopplung").font(.headline)
                    Spacer()
                }

                // Driven by our own refused handshake, not by anything the server
                // said -- a hostile server can't suppress this by answering "success".
                if store.connection.state == .identityChanged {
                    Text("""
                        Die Identität dieses PCs hat sich seit der letzten Kopplung geändert. \
                        Die Verbindung wurde deshalb abgelehnt und es wurde nichts an ihn gesendet. \
                        Das passiert nach einer Neuinstallation oder einem Zurücksetzen des Plugins \
                        — es kann aber auch bedeuten, dass sich etwas anderes dafür ausgibt. \
                        Gib den Code nur ein, wenn du das Plugin gerade selbst neu installiert oder \
                        zurückgesetzt hast.
                        """)
                        .font(.callout.bold())
                        .foregroundStyle(.orange)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Text("Gib den Code ein, der auf dem PC (\(store.lastHost)) angezeigt wird, um dieses iPad zu koppeln.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextField("123456", text: $code)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor, lineWidth: 2)
                    )
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.filter(\.isNumber).prefix(6))
                    }

                if let error = store.pairingCodeError {
                    Text(error).font(.callout).foregroundStyle(.red)
                }

                HStack(spacing: 12) {
                    Button("Abbrechen") {
                        store.disconnect()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                    Button("Koppeln") {
                        store.submitPairingCode(code)
                        code = ""
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(code.count < 4 ? Color.gray.opacity(0.4) : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .disabled(code.count < 4)
                }
                .buttonStyle(.plain)
                .font(.headline)
            }
            .padding(24)
        }
    }
}
