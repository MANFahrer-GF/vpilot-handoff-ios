import Foundation
import Observation

/// Holds the active controller-row theme plus any the pilot has saved under their
/// own name. Persisted in UserDefaults -- purely a display preference, nothing the
/// plugin knows or cares about.
@Observable
final class ThemeStore {
    private let defaults = UserDefaults.standard
    private let activeKey = "handoff.theme.active"
    private let savedKey = "handoff.theme.saved"

    private(set) var active: ControllerTheme
    private(set) var saved: [ControllerTheme]

    init() {
        let decoder = JSONDecoder()
        active = defaults.data(forKey: activeKey)
            .flatMap { try? decoder.decode(ControllerTheme.self, from: $0) }
            ?? .default
        saved = defaults.data(forKey: savedKey)
            .flatMap { try? decoder.decode([ControllerTheme].self, from: $0) }
            ?? []
    }

    /// Every theme offered in the picker: the three built-ins first, then the
    /// pilot's own, so a saved theme never hides a preset.
    var allThemes: [ControllerTheme] {
        ControllerTheme.presets + saved
    }

    func apply(_ theme: ControllerTheme) {
        active = theme
        persistActive()
    }

    func updateActive(_ mutate: (inout ControllerTheme) -> Void) {
        var copy = active
        mutate(&copy)
        // Editing a built-in makes it a modification of that preset, not the preset
        // itself -- otherwise "Default" would silently stop meaning default.
        if ControllerTheme.presets.contains(where: { $0.name == copy.name }), copy != active {
            copy.name = "\(copy.name) (angepasst)"
        }
        active = copy
        persistActive()
    }

    func saveActive(as name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var theme = active
        theme.name = trimmed
        saved.removeAll { $0.name == trimmed }
        saved.append(theme)
        active = theme
        persistActive()
        persistSaved()
    }

    func delete(_ theme: ControllerTheme) {
        saved.removeAll { $0.name == theme.name }
        persistSaved()
        if active.name == theme.name { apply(.default) }
    }

    private func persistActive() {
        guard let data = try? JSONEncoder().encode(active) else { return }
        defaults.set(data, forKey: activeKey)
    }

    private func persistSaved() {
        guard let data = try? JSONEncoder().encode(saved) else { return }
        defaults.set(data, forKey: savedKey)
    }
}
