import UIKit

/// App delegate that exposes a mutable interface-orientation mask so individual
/// SwiftUI screens can opt into landscape (see `ForceLandscape`). The window
/// server reads `supportedInterfaceOrientationsFor` on every rotation; the value
/// returned is INTERSECTED with the Info.plist `UISupportedInterfaceOrientations`
/// (which lists portrait + both landscapes — see `ios/project.yml`).
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Single source of truth the window server reads on every rotation.
    /// Defaults to portrait so the rest of the app stays portrait; the
    /// HalfCourtHero (Nara's Room) host flips it to landscape while visible.
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}
