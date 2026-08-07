import Testing
import Foundation
import Observation
@testable import Handoff

/// Regression guard for a class of bug that compiles, persists correctly, and still
/// does nothing on screen: a property backed directly by UserDefaults via a computed
/// getter/setter is invisible to Observation, so SwiftUI never re-renders when it
/// changes. That's exactly how the Hell/Dunkel switch ended up doing nothing until
/// the app was relaunched.
@MainActor
struct ObservationTests {
    /// Runs `mutate` and reports whether Observation saw the change to `read`.
    private func isObserved(
        _ read: @escaping () -> Void,
        whenChangedBy mutate: () -> Void
    ) -> Bool {
        final class Flag: @unchecked Sendable { var fired = false }
        let flag = Flag()
        withObservationTracking(read) { flag.fired = true }
        mutate()
        return flag.fired
    }

    @Test func appearanceChangesAreObservable() {
        let store = AppStore()
        store.appearance = .system
        let observed = isObserved({ _ = store.appearance }) { store.appearance = .dark }
        #expect(observed, "preferredColorScheme won't update when appearance isn't tracked")
    }

    @Test func appearanceStillPersists() {
        let store = AppStore()
        store.appearance = .dark
        #expect(AppStore().appearance == .dark)
        store.appearance = .system
        #expect(AppStore().appearance == .system)
    }

    @Test func lastHostChangesAreObservable() {
        let store = AppStore()
        store.lastHost = ""
        let observed = isObserved({ _ = store.lastHost }) { store.lastHost = "192.168.1.42" }
        #expect(observed, "the status footer won't redraw when lastHost isn't tracked")
        store.lastHost = ""
    }

    @Test func hideTunedChangesAreObservable() {
        let store = AppStore()
        store.hideTuned = false
        let observed = isObserved({ _ = store.hideTuned }) { store.hideTuned = true }
        #expect(observed)
    }

    @Test func everyAppearanceModeMapsToTheRightColorScheme() {
        #expect(AppearanceMode.system.colorScheme == nil)
        #expect(AppearanceMode.light.colorScheme == .light)
        #expect(AppearanceMode.dark.colorScheme == .dark)
    }
}
