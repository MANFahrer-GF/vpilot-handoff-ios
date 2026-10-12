import Testing
import Foundation
import WebKit
@testable import Handoff

/// WebKit's delegate methods are optional Objective-C selectors: a signature that is close but
/// not exact compiles, is never called, and leaves the host gate doing nothing at all. The
/// compiler only warns. These check the selectors are actually implemented, so the gate cannot
/// be disabled by a silent near-miss.
@MainActor
struct VdgsWebSheetTests {
    @Test func theDelegateImplementsTheSelectorsWebKitActuallyCalls() {
        let delegate = makeVdgsWebViewDelegate()
        #expect(delegate is WKNavigationDelegate)
        #expect(delegate is WKUIDelegate)
        #expect(delegate.responds(to: Selector(("webView:decidePolicyForNavigationAction:decisionHandler:"))))
        #expect(delegate.responds(to: Selector(("webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:"))))
    }
}
