import SwiftUI

@main
struct HandoffApp: App {
    @State private var store = AppStore()
    @State private var themeStore = ThemeStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(themeStore)
                .preferredColorScheme(store.appearance.colorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        store.reconnectIfNeeded()
                    }
                }
        }
    }
}
