import Foundation
import Observation

/// Holds the active controller-row theme plus any the pilot has saved under their
/// own name. Persisted in UserDefaults -- purely a display preference, nothing the
/// plugin knows or cares about.
@MainActor
@Observable
final class ThemeStore {
    private var defaults: UserDefaults { HandoffDefaults.store }
    private let activeKey = "handoff.theme.active"
    private let savedKey = "handoff.theme.saved"

    private(set) var active: ControllerTheme
    private(set) var saved: [ControllerTheme]

    init() {
        // Read through the type, not `self.defaults` -- the computed property counts
        // as touching self before every stored property is initialised.
        let store = HandoffDefaults.store
        let decoder = JSONDecoder()
        active = store.data(forKey: "handoff.theme.active")
            .flatMap { try? decoder.decode(ControllerTheme.self, from: $0) }
            ?? .default
        saved = store.data(forKey: "handoff.theme.saved")
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

    /// Sliders and the colour picker fire continuously while dragging; writing the
    /// encoded theme on every intermediate value meant dozens of UserDefaults writes
    /// per drag. The in-memory value still updates immediately, so the preview stays
    /// live -- only the write is coalesced.
    private var persistTask: Task<Void, Never>?

    func updateActive(_ mutate: (inout ControllerTheme) -> Void) {
        var copy = active
        mutate(&copy)
        // Editing a built-in makes it a modification of that preset, not the preset
        // itself -- otherwise "Default" would silently stop meaning default.
        if ControllerTheme.presets.contains(where: { $0.name == copy.name }), copy != active {
            copy.name = "\(copy.name) (angepasst)"
        }
        active = copy
        schedulePersistActive()
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

    private func schedulePersistActive() {
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.persistActive()
        }
    }

    private func persistActive() {
        persistTask?.cancel()
        persistTask = nil
        guard let data = try? JSONEncoder().encode(active) else { return }
        defaults.set(data, forKey: activeKey)
    }

    private func persistSaved() {
        guard let data = try? JSONEncoder().encode(saved) else { return }
        defaults.set(data, forKey: savedKey)
    }
}
