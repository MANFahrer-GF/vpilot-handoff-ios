import UIKit

/// View-scoped capture of the app's own window, matching the Android client's default
/// (non-opted-in) debug screenshot behavior in protocol.md -- deliberately not a
/// full-device capture, since the iPad normally runs this app in Split View next to
/// an unrelated EFB app that has nothing to do with a Handoff bug report.
enum AppScreenshotter {
    static func captureCurrentWindowPNG() -> Data? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else { return nil }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        return image.pngData()
    }
}
