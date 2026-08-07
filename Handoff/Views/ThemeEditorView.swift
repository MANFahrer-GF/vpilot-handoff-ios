import SwiftUI

/// gallery/06-controller-colors.png. Each facility is shown as the two rows it can
/// actually render as -- highlighted and not -- so the brightness slider's effect
/// is visible while you drag it, rather than described.
struct ThemeEditorView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var editingFacility: ThemeFacility?
    @State private var newThemeName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    presetPicker
                    previewGrid
                    contactMeSection
                    sliderSections
                    saveSection
                    if !themeStore.saved.isEmpty { savedSection }
                }
                .padding(24)
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Controller-Farben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(item: $editingFacility) { facility in
                FacilityColorPicker(facility: facility)
                    .presentationDetents([.medium])
            }
        }
    }

    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("VORLAGE")
            HStack(spacing: 10) {
                ForEach(ControllerTheme.presets) { preset in
                    Button {
                        themeStore.apply(preset)
                    } label: {
                        Text(preset.name)
                            .font(.callout.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(themeStore.active.name == preset.name ? Color.accentColor : Color(.secondarySystemBackground))
                            .foregroundStyle(themeStore.active.name == preset.name ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Aktiv: \(themeStore.active.name)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var previewGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("ZEILE ANTIPPEN, UM IHRE FARBE ZU ÄNDERN")
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 10
            ) {
                ForEach(ThemeFacility.allCases) { facility in
                    VStack(spacing: 6) {
                        previewRow(facility, highlighted: true)
                        previewRow(facility, highlighted: false)
                    }
                }
            }
        }
    }

    private func previewRow(_ facility: ThemeFacility, highlighted: Bool) -> some View {
        let controller = facility.sampleController(highlighted: highlighted)
        return Button {
            editingFacility = facility
        } label: {
            HStack {
                Text(controller.callsign)
                    .font(.subheadline.monospaced().bold())
                Spacer()
                Text(controller.frequencyMHzText)
                    .font(.subheadline.monospacedDigit().bold())
                Text(facility.badge)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .foregroundStyle(textColor(for: facility, highlighted: highlighted))
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(rowColor(for: facility, highlighted: highlighted))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func rowColor(for facility: ThemeFacility, highlighted: Bool) -> Color {
        themeStore.active.rowColor(
            for: facility.sampleController(highlighted: highlighted),
            darkMode: colorScheme == .dark
        )
    }

    private func textColor(for facility: ThemeFacility, highlighted: Bool) -> Color {
        themeStore.active.textColor(on: RGBColor(rowColor(for: facility, highlighted: highlighted)))
    }

    private var contactMeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("CONTACT-ME-ALARM")
            Text("Eine offene Contact-me-Anfrage lässt die Zeile zweimal pro Sekunde zwischen ihrer eigenen Farbe und dieser Alarmfarbe blinken.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ColorPicker(selection: contactMeBinding, supportsOpacity: false) {
                HStack {
                    Text("LOVV_CTR").font(.subheadline.monospaced().bold())
                    Text("CONTACT ME")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.25))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .foregroundStyle(themeStore.active.textColor(on: themeStore.active.contactMeAlert))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeStore.active.contactMeAlert.color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var sliderSections: some View {
        VStack(alignment: .leading, spacing: 22) {
            sliderSection(
                title: "HELLIGKEIT NICHT-HERVORGEHOBENER ZEILEN",
                explanation: "Wo normale (nicht hervorgehobene) Zeilen zwischen Schwarz und Weiß liegen, relativ zu ihrer Hervorhebungsfarbe.",
                value: brightnessBinding,
                leading: "Schwarz",
                middle: "Hervorhebung",
                trailing: "Weiß"
            )
            sliderSection(
                title: "TEXTKONTRAST-SCHWELLE",
                explanation: "Ab wann der Zeilentext von Dunkel auf Weiß wechselt, wenn eine Farbe dunkler wird.",
                value: contrastBinding,
                leading: "Früh",
                middle: nil,
                trailing: "Spät"
            )
            sliderSection(
                title: "DARK-MODE-ABDUNKLUNG",
                explanation: "Zusätzliche Abdunklung auf jeder Zeile — auch hervorgehobenen — nur im dunklen Erscheinungsbild.",
                value: darkOffsetBinding,
                leading: "Aus",
                middle: nil,
                trailing: "Schwarz"
            )
        }
    }

    private func sliderSection(
        title: String,
        explanation: String,
        value: Binding<Double>,
        leading: String,
        middle: String?,
        trailing: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(title)
            Text(explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Slider(value: value, in: 0...1)
            HStack {
                Text(leading)
                Spacer()
                if let middle {
                    Text(middle)
                    Spacer()
                }
                Text(trailing)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("ALS NEUES THEMA SICHERN")
            HStack {
                TextField("Name des Themas", text: $newThemeName)
                    .textFieldStyle(.roundedBorder)
                Button("Sichern") {
                    themeStore.saveActive(as: newThemeName)
                    newThemeName = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(newThemeName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("EIGENE THEMEN")
            ForEach(themeStore.saved) { theme in
                HStack {
                    Button(theme.name) { themeStore.apply(theme) }
                        .buttonStyle(.plain)
                        .font(.callout.bold())
                    Spacer()
                    ForEach(ThemeFacility.allCases) { facility in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.highlightColor(for: facility.sampleController(highlighted: true)).color)
                            .frame(width: 18, height: 18)
                    }
                    Button(role: .destructive) {
                        themeStore.delete(theme)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text).font(.caption.bold()).foregroundStyle(.secondary)
            Divider()
        }
    }

    // MARK: Bindings

    private var contactMeBinding: Binding<Color> {
        Binding(
            get: { themeStore.active.contactMeAlert.color },
            set: { newValue in
                themeStore.updateActive { $0.contactMeAlert = RGBColor(newValue) }
            }
        )
    }

    private var brightnessBinding: Binding<Double> {
        Binding(
            get: { themeStore.active.nonHighlightBrightness },
            set: { newValue in themeStore.updateActive { $0.nonHighlightBrightness = newValue } }
        )
    }

    private var contrastBinding: Binding<Double> {
        Binding(
            get: { themeStore.active.textContrastThreshold },
            set: { newValue in themeStore.updateActive { $0.textContrastThreshold = newValue } }
        )
    }

    private var darkOffsetBinding: Binding<Double> {
        Binding(
            get: { themeStore.active.darkModeOffset },
            set: { newValue in themeStore.updateActive { $0.darkModeOffset = newValue } }
        )
    }
}

/// The facilities the editor exposes -- one per colour slot in `ControllerTheme`.
enum ThemeFacility: String, CaseIterable, Identifiable {
    case delivery, ground, tower, approach, center, atis

    var id: String { rawValue }

    var badge: String {
        switch self {
        case .delivery: return "DEL"
        case .ground: return "GND"
        case .tower: return "TWR"
        case .approach: return "APP"
        case .center: return "CTR"
        case .atis: return "ATIS"
        }
    }

    private var facilityCode: Int {
        switch self {
        case .delivery: return 2
        case .ground: return 3
        case .tower: return 4
        case .approach: return 5
        case .center: return 6
        case .atis: return 0
        }
    }

    private var sampleCallsign: String {
        switch self {
        case .delivery: return "LOWW_DEL"
        case .ground: return "LOWW_GND"
        case .tower: return "LOWW_TWR"
        case .approach: return "LOWW_APP"
        case .center: return "LOVV_CTR"
        case .atis: return "LOWW_D_ATIS"
        }
    }

    private var sampleFrequency: Int {
        switch self {
        case .delivery: return 22125
        case .ground: return 21600
        case .tower: return 19400
        case .approach: return 34675
        case .center: return 32600
        case .atis: return 21730
        }
    }

    func sampleController(highlighted: Bool) -> Controller {
        Controller.preview(
            callsign: sampleCallsign,
            frequency: sampleFrequency,
            facility: facilityCode,
            isHighlighted: highlighted
        )
    }

    func color(in theme: ControllerTheme) -> RGBColor {
        theme.highlightColor(for: sampleController(highlighted: true))
    }

    func setColor(_ color: RGBColor, in theme: inout ControllerTheme) {
        switch self {
        case .delivery: theme.delivery = color
        case .ground: theme.ground = color
        case .tower: theme.tower = color
        case .approach: theme.approach = color
        case .center: theme.center = color
        case .atis: theme.atis = color
        }
    }
}

private struct FacilityColorPicker: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.dismiss) private var dismiss
    let facility: ThemeFacility

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ColorPicker(
                    "Farbe für \(facility.badge)",
                    selection: Binding(
                        get: { facility.color(in: themeStore.active).color },
                        set: { newValue in
                            themeStore.updateActive { facility.setColor(RGBColor(newValue), in: &$0) }
                        }
                    ),
                    supportsOpacity: false
                )
                .padding()

                Spacer()
            }
            .navigationTitle(facility.badge)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
