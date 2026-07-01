import SwiftUI

@main
struct BandMusicGamesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth = SpotifyAuthManager()
    @StateObject private var appleMusic = AppleMusicManager()
    private let showsTurntablePreview  = ProcessInfo.processInfo.arguments.contains("--turntable-preview")
    private let showsMechanicsProto    = false  // mechanics prototype (meter-only testbed)
    private let showsNaraRoom          = true   // playtest: boot straight into Nara's Room (landscape button controls)

    var body: some Scene {
        WindowGroup {
            Group {
                if showsTurntablePreview {
                    TurntableAnimationPreview()
                } else if showsNaraRoom {
                    LizzyMcGuireGameView()
                } else if showsMechanicsProto {
                    MechanicsPrototypeView()
                } else {
                    ContentView()
                }
            }
                .environmentObject(auth)
                .environmentObject(appleMusic)
                .statusBarHidden(showsTurntablePreview || showsMechanicsProto || showsNaraRoom)
                .onOpenURL { url in
                    // ASWebAuthenticationSession handles its own callback;
                    // this is here for any future deep-link needs.
                    auth.handleCallback(url: url)
                }
        }
    }
}
