import UIKit

/// Capture of the app's own window for a debug snapshot.
///
/// protocol.md's issue #73a lets the Android client opt into a *full-device* capture
/// via MediaProjection, so a bug report can show the neighbouring EFB app. iOS has
/// no equivalent: the sandbox permits an app to capture its own layers and nothing
/// else -- ReplayKit records this app's content, not the screen. There is therefore
/// no full-device option to offer here, only whether to attach the app's own window
/// at all, which is a privacy choice worth exposing.
@MainActor
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
