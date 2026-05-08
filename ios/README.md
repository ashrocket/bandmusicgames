# Band Music Games — iOS App

Native SwiftUI jukebox launcher. Wurlitzer 1015–inspired cabinet with animated
bubble tubes, warm chrome, and amber glow. Songs open in an embedded WKWebView
with the Spotify token injected as a cookie so the web games see it.

## Xcode setup

1. Open Xcode → **File → New → Project** → App
   - Product Name: `BandMusicGames`
   - Bundle Identifier: `party.bandmusicgames.app`
   - Interface: SwiftUI · Lifecycle: SwiftUI App
   - Language: Swift · Deployment target: iOS 16.0

2. Delete the default `ContentView.swift` and `BandMusicGamesApp.swift` that
   Xcode generates.

3. Drag all files from `BandMusicGames/` into the Xcode project navigator
   (choose **Copy items if needed**, add to the app target).

4. Replace the generated `Info.plist` contents with the one in `ios/Info.plist`,
   or merge the `CFBundleURLTypes` and `NSAppTransportSecurity` keys into the
   existing file.

5. In the Spotify Developer Dashboard, add the redirect URI:
   ```
   bandmusicgames://spotify-callback
   ```

6. Build & run on a device or simulator (iOS 16+).

## Architecture

```
BandMusicGames/
├── BandMusicGamesApp.swift     — @main, wires SpotifyAuthManager into env
├── Models/
│   └── Song.swift              — Song struct + catalog + Color(hex:) extension
├── Managers/
│   ├── SpotifyAuthManager.swift— PKCE OAuth via ASWebAuthenticationSession
│   └── HapticManager.swift     — UIFeedbackGenerator wrappers
└── Views/
    ├── ContentView.swift       — Root: jukebox + sheet coordination
    ├── JukeboxView.swift       — Full cabinet layout
    ├── ArchHeaderView.swift    — Tombstone arch + animated amber glow + title
    ├── BubbleTubeView.swift    — TimelineView/Canvas animated bubble columns
    ├── SongDisplayView.swift   — Dark glass window, swipe/arrow navigation
    ├── ChromePlayButton.swift  — Large circular chrome play button
    ├── GameWebView.swift       — WKWebView wrapper + Spotify cookie injection
    └── SpotifySheetView.swift  — Connect/skip sheet in jukebox style
```

## Auth flow

1. Tap **CONNECT SPOTIFY** → `SpotifyAuthManager.login()` opens an
   `ASWebAuthenticationSession` with PKCE challenge.
2. Spotify redirects to `bandmusicgames://spotify-callback?code=…`
3. Manager exchanges the code for a token, stores it in `UserDefaults`.
4. When a game launches, `GameSheetView` passes the token to `GameWebView`,
   which sets it as an HTTP cookie on `.bandmusicgames.party` before loading
   the game URL — so the existing web games pick it up exactly as they do
   from the web lobby.

## Notes

- The cookie domain `.bandmusicgames.party` covers all `*.bandmusicgames.party`
  subdomains, matching the web app's existing cookie strategy.
- Token expiry is tracked; expired tokens are cleared on next launch.
- "Play without music" sets `sp_skip=1` in both `UserDefaults` and the WebView
  cookie store.
