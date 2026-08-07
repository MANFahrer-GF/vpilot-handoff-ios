import Foundation

/// Single indirection for every preference this app persists.
///
/// It exists so tests can point the stores at a throwaway suite. Before this, the
/// test suites wrote into the real app's `UserDefaults.standard` -- one of them even
/// had an unused `makeIsolatedDefaults` helper whose comment promised an isolation
/// it never actually provided.
enum HandoffDefaults {
    nonisolated(unsafe) private static var backing: UserDefaults = .standard

    static var store: UserDefaults { backing }

    /// Test-only: redirect persistence to a named, empty suite.
    static func useIsolatedSuite(named name: String) {
        UserDefaults.standard.removePersistentDomain(forName: name)
        backing = UserDefaults(suiteName: name) ?? .standard
    }
}
