import Foundation
@testable import Handoff

/// Redirects every persisted preference into a throwaway suite, once per test
/// process. Without this the suites wrote into the real app's defaults -- an earlier
/// version even carried a `makeIsolatedDefaults` helper that was never called, so the
/// isolation its comment promised didn't exist.
enum TestDefaults {
    private static let suiteName = "com.thomaskant.handoff.tests.isolated"
    nonisolated(unsafe) private static var installed = false

    static func installOnce() {
        guard !installed else { return }
        installed = true
        HandoffDefaults.useIsolatedSuite(named: suiteName)
    }
}
