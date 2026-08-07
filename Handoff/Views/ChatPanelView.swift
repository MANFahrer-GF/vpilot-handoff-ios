import SwiftUI

/// The RADIO panel. In a wide layout it sits permanently beside the dashboard
/// (gallery/01-initial.png); in a narrow split it's toggled from the MSG tile and
/// drawn over the rest, which is why closing is offered here rather than only
/// from the tile.
struct ChatPanelView: View {
    @Environment(AppStore.self) private var store
    /// Owned by the dashboard so tapping a controller row's chat icon can aim the
    /// panel at that station even while it's already open.
    @Binding var privateTarget: String?
    var showsCloseButton: Bool
    var onClose: () -> Void

    @State private var draft = ""
    @State private var showNearbyAircraft = false
    @State private var flashOn = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            messageList
            selcalBanner
            Divider()
            composer
        }
        .background(.background)
        .sheet(isPresented: $showNearbyAircraft) {
            PrivateChatTargetSheet { callsign in
                privateTarget = callsign
                showNearbyAircraft = false
            }
        }
        .onAppear {
            store.markConversationRead(currentKey)
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                flashOn = true
            }
        }
        .onChange(of: currentKey) { _, key in store.markConversationRead(key) }
        .onChange(of: store.chatMessages) { _, _ in store.markConversationRead(currentKey) }
    }

    private var currentKey: String {
        privateTarget ?? ChatMessage.radioConversationKey
    }

    /// Radio first, then every station the pilot has an exchange with -- plus the
    /// one they just picked, even before a message exists for it.
    private var conversationKeys: [String] {
        var keys = [ChatMessage.radioConversationKey]
        for message in store.chatMessages where !message.isRadio {
            let key = message.conversationKey
            if !keys.contains(key) { keys.append(key) }
        }
        if let privateTarget, !keys.contains(privateTarget) { keys.append(privateTarget) }
        return keys
    }

    private var header: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(conversationKeys, id: \.self) { key in
                        conversationTab(key)
                    }
                }
            }

            Button {
                showNearbyAircraft = true
            } label: {
                Image(systemName: "airplane")
                    .font(.system(size: 17))
            }
            .buttonStyle(.plain)

            if showsCloseButton {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.primary)
        .padding(12)
    }

    private func conversationTab(_ key: String) -> some View {
        let isRadio = key == ChatMessage.radioConversationKey
        let isSelected = key == currentKey
        let unread = store.unreadByConversation[key] ?? 0
        // Directed traffic is aimed at this pilot; ambient chatter on the frequency
        // isn't. Only the former earns the flash.
        let shouldFlash = unread > 0 && !isRadio

        return Button {
            privateTarget = isRadio ? nil : key
        } label: {
            HStack(spacing: 6) {
                Text(isRadio ? "RADIO" : key)
                    .font(.caption.bold())
                if unread > 0 {
                    Text("\(unread)")
                        .font(.caption2.monospacedDigit().bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(shouldFlash && flashOn ? Color.orange : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// With no target selected the header says RADIO, so it shows radio traffic --
    /// private conversations are reached by picking a callsign, not by being mixed
    /// into the frequency's chatter.
    private var visibleMessages: [ChatMessage] {
        guard let privateTarget else { return store.chatMessages.filter(\.isRadio) }
        return store.chatMessages.filter { $0.peer == privateTarget }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleMessages) { message in
                        ChatMessageCard(message: message)
                            .id(message.id)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay {
                if visibleMessages.isEmpty {
                    Text("Noch keine Nachrichten")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: visibleMessages.last?.id) { _, lastId in
                guard let lastId else { return }
                withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
            }
        }
        // Without this the scroll view sizes to its content inside the overlay and
        // leaves dead space between the last message and the composer.
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var selcalBanner: some View {
        if !store.selcalAlerts.isEmpty {
            VStack(spacing: 4) {
                ForEach(store.selcalAlerts) { alert in
                    HStack {
                        Label("SELCAL · \(alert.from)", systemImage: "bell.fill")
                            .font(.caption.bold())
                        Spacer()
                        Button("Quittieren") { store.dismissSelcal(alert.from) }
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.15))
                }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            // Single line, like the Android composer: a radio call is one line, and
            // a growing field would push the message list around mid-flight.
            TextField(placeholder, text: $draft)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(send)

            Button(action: send) {
                Label(privateTarget == nil ? "TRANSMIT" : "SENDEN", systemImage: "mic.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    // A flat grey fill reads as "enabled" against a dark background,
                    // so the disabled state dims the label too rather than only the fill.
                    .background(canSend ? Color.blue : Color.secondary.opacity(0.18))
                    .foregroundStyle(canSend ? Color.white : Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(12)
    }

    private var placeholder: String {
        privateTarget.map { "Nachricht an \($0)…" } ?? "Transmit on current frequency…"
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let privateTarget {
            store.sendPrivateMessage(to: privateTarget, text: text)
        } else {
            store.sendRadioMessage(text)
        }
        draft = ""
    }
}

struct ChatMessageCard: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(message.headerLabel)
                    .font(.caption.monospaced())
                if let sender = message.senderLabel {
                    Text(sender).font(.caption.monospaced()).opacity(0.8)
                }
                Text("·").font(.caption)
                Text(message.timeLabel).font(.caption.monospaced())
            }
            .foregroundStyle(.secondary)

            Text(message.text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(message.isOutgoing ? Color.blue.opacity(0.12) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

/// gallery/14-contact-nearby-aircraft.png: free-text callsign entry on top, the
/// 20nm traffic list below as a shortcut -- not a picker you're forced through.
struct PrivateChatTargetSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var onSelect: (String) -> Void

    @State private var callsign = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    TextField("Callsign", text: $callsign)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onSubmit(confirm)
                    Button(action: confirm) {
                        Image(systemName: "checkmark")
                            .padding(10)
                            .background(callsign.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(callsign.isEmpty)
                }
                .padding()

                Text("AIRCRAFT WITHIN 20NM · CLOSEST FIRST")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                List(store.nearbyAircraft) { aircraft in
                    Button {
                        onSelect(aircraft.callsign)
                        dismiss()
                    } label: {
                        HStack {
                            Text(aircraft.callsign).font(.callout.bold())
                            Spacer()
                            Text(aircraft.aircraftType ?? "–")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1fnm", aircraft.distanceNm))
                                .font(.callout.monospacedDigit())
                                .frame(width: 70, alignment: .trailing)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .overlay {
                    if store.nearbyAircraft.isEmpty {
                        Text("Kein Verkehr in der Nähe")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Private chat to callsign")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    private func confirm() {
        guard !callsign.isEmpty else { return }
        onSelect(callsign.uppercased())
        dismiss()
    }
}
