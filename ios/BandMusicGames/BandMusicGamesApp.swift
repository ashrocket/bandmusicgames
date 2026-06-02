import SwiftUI

@main
struct BandMusicGamesApp: App {
    @StateObject private var auth = SpotifyAuthManager()

    /// Temporary: boot straight into the Lizzie McGuire game, skipping the jukebox lobby.
    /// Flip back to `false` to restore the normal lobby flow.
    private let bootsDirectlyToLizzie = true

    var body: some Scene {
        WindowGroup {
            Group {
                if bootsDirectlyToLizzie {
                    LizzyMcGuireGameView()
                } else {
                    ContentView()
                }
            }
                .environmentObject(auth)
                .onOpenURL { url in
                    // ASWebAuthenticationSession handles its own callback;
                    // this is here for any future deep-link needs.
                    auth.handleCallback(url: url)
                }
        }
    }
}
