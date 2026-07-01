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
    /// Sets the app-wide orientation mask and asks the active window scene to
    /// re-evaluate its geometry so the device rotates immediately.
    static func lock(_ mask: UIInterfaceOrientationMask) {
        AppDelegate.orientationLock = mask
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        if #available(iOS 16.0, *) {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                #if DEBUG
                print("requestGeometryUpdate failed (check plist orientation keys): \(error)")
                #endif
            }
            scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
