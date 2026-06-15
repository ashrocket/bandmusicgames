import SwiftUI

@main
struct BandMusicGamesApp: App {
    @StateObject private var auth = SpotifyAuthManager()
    @StateObject private var appleMusic = AppleMusicManager()
    private let showsTurntablePreview = ProcessInfo.processInfo.arguments.contains("--turntable-preview")

    var body: some Scene {
        WindowGroup {
            Group {
                if showsTurntablePreview {
                    TurntableAnimationPreview()
                } else {
                    ContentView()
                }
            }
                .environmentObject(auth)
                .environmentObject(appleMusic)
                .statusBarHidden(showsTurntablePreview)
                .onOpenURL { url in
                    // ASWebAuthenticationSession handles its own callback;
                    // this is here for any future deep-link needs.
                    auth.handleCallback(url: url)
                }
        }
    }
}
