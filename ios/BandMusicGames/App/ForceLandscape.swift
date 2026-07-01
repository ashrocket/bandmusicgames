import SwiftUI
import UIKit

/// Attach `.forceLandscape()` to a screen that should rotate to landscape while
/// it is on-screen and restore portrait when it leaves. Scoped per-view so the
/// rest of the app stays portrait.
struct ForceLandscape: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear    { OrientationController.lock(.landscape) }
            .onDisappear { OrientationController.lock(.portrait) }
    }
}

extension View {
    func forceLandscape() -> some View { modifier(ForceLandscape()) }
}

enum OrientationController {
    /// Sets the app-wide orientation mask and asks every window scene to re-evaluate
    /// its geometry so the device rotates immediately. Applies to ALL connected window
    /// scenes (not just a foreground-active one) because `onAppear` can fire before the
    /// scene becomes active — filtering on that would silently skip the rotation.
    static func lock(_ mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = mask
        guard #available(iOS 16.0, *) else { return }
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in windowScenes {
            // Force the root VC to re-evaluate supportedInterfaceOrientations against the
            // new mask, then request the actual geometry change.
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                #if DEBUG
                print("requestGeometryUpdate failed (check plist orientation keys): \(error)")
                #endif
            }
        }
    }
}
