import SwiftUI

@main
struct BandMusicGamesApp: App {
    @StateObject private var auth = SpotifyAuthManager()

    var body: some Scene {
        WindowGroup {
            rootView
                .environmentObject(auth)
                .onOpenURL { url in
                    // ASWebAuthenticationSession handles its own callback;
                    // this is here for any future deep-link needs.
                    auth.handleCallback(url: url)
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
#if DEBUG
        switch DebugLaunchTarget.current {
        case .goon:
            GoonGameView()
        case .francis:
            FrancisGameView()
        case .lizzyMcGuire:
            LizzyMcGuireGameView()
        case nil:
            ContentView()
        }
#else
        ContentView()
#endif
    }
}

#if DEBUG
private enum DebugLaunchTarget {
    case francis
    case lizzyMcGuire
    case goon

    static var current: DebugLaunchTarget? {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-bmg-open-goon") {
            return .goon
        }
        if args.contains("-bmg-open-francis") {
            return .francis
        }
        if args.contains("-bmg-open-lizzy") {
            return .lizzyMcGuire
        }
        return nil
    }
}
#endif
