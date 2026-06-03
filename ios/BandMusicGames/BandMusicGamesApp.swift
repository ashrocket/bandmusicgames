import SwiftUI

@main
struct BandMusicGamesApp: App {
    @StateObject private var auth = SpotifyAuthManager()
    private let showsTurntablePreview = ProcessInfo.processInfo.arguments.contains("--turntable-preview")

    /// Temporary: boot straight into the Lizzie McGuire game, skipping the jukebox lobby.
    /// Flip back to `false` to restore the normal lobby flow.
    private let bootsDirectlyToLizzie = true

    var body: some Scene {
        WindowGroup {
            Group {
                if showsTurntablePreview {
                    TurntableAnimationPreview()
                } else if bootsDirectlyToLizzie {
                    LizzyMcGuireGameView()
                } else {
                    ContentView()
                }
            }
                .environmentObject(auth)
                .statusBarHidden(showsTurntablePreview)
                .onOpenURL { url in
                    // ASWebAuthenticationSession handles its own callback;
                    // this is here for any future deep-link needs.
                    auth.handleCallback(url: url)
                }
        }
    }
}
