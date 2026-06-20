import SwiftUI

@main
struct BandMusicGamesApp: App {
    @StateObject private var auth = SpotifyAuthManager()
    @StateObject private var appleMusic = AppleMusicManager()
    private let showsTurntablePreview  = ProcessInfo.processInfo.arguments.contains("--turntable-preview")
    private let showsMechanicsProto    = true  // mechanics prototype build — revert to false after playtest

    var body: some Scene {
        WindowGroup {
            Group {
                if showsTurntablePreview {
                    TurntableAnimationPreview()
                } else if showsMechanicsProto {
                    MechanicsPrototypeView()
                } else {
                    ContentView()
                }
            }
                .environmentObject(auth)
                .environmentObject(appleMusic)
                .statusBarHidden(showsTurntablePreview || showsMechanicsProto)
                .onOpenURL { url in
                    // ASWebAuthenticationSession handles its own callback;
                    // this is here for any future deep-link needs.
                    auth.handleCallback(url: url)
                }
        }
    }
}
