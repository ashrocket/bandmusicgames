import SwiftUI

@main
struct BandMusicGamesApp: App {
    @StateObject private var auth = SpotifyAuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .onOpenURL { url in
                    // ASWebAuthenticationSession handles its own callback;
                    // this is here for any future deep-link needs.
                    auth.handleCallback(url: url)
                }
        }
    }
}
