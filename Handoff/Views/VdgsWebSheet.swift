import SwiftUI
import WebKit

/// The real A-CDM website in a sheet, so the pilot can log in with VATSIM and set or change
/// their TOBT without leaving the cockpit (upstream issue #143). A web view rather than Safari
/// for the same reason the Android client uses one: the session cookie then lives in this app,
/// so the VATSIM login is asked for once rather than on every visit.
///
/// Nothing here reads or writes the pilot's credentials — the page does, in its own fields, with
/// its own login. The app only hosts the frame.
struct VdgsWebSheet: View {
    /// What vats.im/vdgs itself redirects to.
    static let url = URL(string: "https://vdgs.vatsimspain.es/vdgs/index.php")!

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VdgsWebView(url: Self.url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("TOBT · VDGS")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

/// The hosts this view may navigate to: the site itself, VATSIM's login, and the bot check that
/// fronts both. Any other top-level navigation is refused, so a stray link cannot take a
/// JavaScript-enabled web view somewhere else. Subdomains count.
private let allowedHostSuffixes = ["vatsimspain.es", "vatsim.net", "cloudflare.com"]

/// True for an https URL on one of `allowedHostSuffixes` (or a subdomain of one).
func isAllowedVdgsNavigation(_ url: URL?) -> Bool {
    guard let url, url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
    return allowedHostSuffixes.contains { host == $0 || host.hasSuffix(".\($0)") }
}

private struct VdgsWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Only top-level navigation is gated: sub-resources (the site's own scripts, styles
            // and images) are the page's business, and blocking those would break the page it is
            // here to show.
            guard navigationAction.targetFrame?.isMainFrame != false else {
                decisionHandler(.allow)
                return
            }
            decisionHandler(isAllowedVdgsNavigation(navigationAction.request.url) ? .allow : .cancel)
        }
    }
}
