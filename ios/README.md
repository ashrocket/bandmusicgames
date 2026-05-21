# Band Music Games — iOS App

Native SwiftUI launcher with a Lottie-rendered line drawing selector. Songs open
in native Swift games or an embedded WKWebView with the Spotify token injected
as a cookie so the web games see it.

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
├── Animations/
│   ├── JukeboxLineIdle.json    — Looping line selector animation
│   └── JukeboxLineKnot.json    — Selection knot transition
└── Views/
    ├── ContentView.swift       — Root: selector + sheet coordination
    ├── JukeboxView.swift       — Lottie line selector + song controls
    ├── LottieAnimationPlayer.swift — SwiftUI wrapper for LottieAnimationView
    ├── GameWebView.swift       — WKWebView wrapper + Spotify cookie injection
    ├── SpotifySheetView.swift  — Connect/skip sheet in jukebox style
    ├── ArchHeaderView.swift    — Tombstone arch + animated amber glow + title
    ├── BubbleTubeView.swift    — TimelineView/Canvas animated bubble columns
    ├── SongDisplayView.swift   — Dark glass window, swipe/arrow navigation
    └── ChromePlayButton.swift  — Legacy chrome play button
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

## TestFlight automation

### Local upload

From the repo root:

```sh
npm run testflight
```

The local uploader defaults to:

- key path: `~/.env/ashcode/apple/AuthKey_N89CARWD2R.p8`
- key ID: `N89CARWD2R`
- issuer ID: `69a6de77-108b-47e3-e053-5b8c7c11a4d1`
- bundle ID: `party.bandmusicgames.app`

It creates a timestamp build number, archives, uploads to App Store Connect, then
polls TestFlight readiness and sets `usesNonExemptEncryption=false` if Apple
asks for export compliance.

Override defaults with environment variables:

```sh
ASC_KEY_PATH=/path/to/AuthKey_XXXX.p8 ASC_KEY_ID=XXXX npm run testflight
```

### GitHub Actions

`.github/workflows/testflight.yml` archives and uploads the iOS app to App Store
Connect on pushes to `main` that touch `ios/**`, and can also be run manually.
It uses automatic signing plus an App Store Connect API key by running the same
uploader script, then polls TestFlight readiness and applies the export
compliance flag.

Required repository secrets:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_PRIVATE_KEY_BASE64`

Encode the `.p8` key before saving it as the base64 secret:

```sh
base64 -i AuthKey_KEYID.p8 | pbcopy
```
