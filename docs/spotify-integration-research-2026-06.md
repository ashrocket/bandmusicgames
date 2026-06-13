# Spotify Integration — Verified Research & Recommended Architecture (June 2026)

Deep-research run 2026-06-12: 22 sources fetched, 106 claims extracted, 25 adversarially
verified (3 independent votes each) → 24 confirmed, 1 refuted. All Spotify-doc claims were
live-fetched June 2026. Spotify changed developer policy three times in 18 months
(Nov 2024, Apr 2025, Feb 2026) — re-verify before launch decisions.

## TL;DR per surface

| Surface | Premium users | Free / not logged in |
|---|---|---|
| Desktop web | **Web Playback SDK** (keep — only in-browser full-track path) | Embed iframe → ~30s demo mode |
| Mobile web | **Web Playback SDK** — now officially supported on iOS/Android browsers; replaces the Connect remote-control dance | Embed iframe → ~30s demo mode |
| Native iOS | **App Remote SDK** (controls installed Spotify app) primary; Web API Connect fallback when Spotify app absent | No real option (App Remote URI playback is Premium-only; free = shuffle behavior) |

## ⚠️ The dominant constraint is policy, not playback tech

- **Nov 27 2024**: dev-mode/new apps lost Recommendations, Audio Features/Analysis,
  Related Artists, editorial playlists, and **`preview_url`** (the old no-login 30s MP3) —
  still in force mid-2026.
- **Apr 15 2025**: Web API **extended access now requires a registered business entity +
  250k MAU** — effectively unreachable for an indie app.
- **Feb 6 2026**: development mode now requires **Premium** accounts and is capped at
  **5 test users** (down from 25).
- Net effect (medium confidence — from verifier evidence citing Spotify's own blog +
  TechCrunch): an unallowlisted dev-mode app **cannot serve a general public audience**
  through any user-authorized flow (Web Playback SDK, Connect, App Remote all need the
  user to authorize against the registered app). "Real public streams via our own app"
  may be unreachable; the no-auth **Embed** is the only public-scale Spotify surface.
- Open strategic options (unresearched): per-band app registrations, label/artist
  partnership allowlisting, or leaning on **Apple Music/MusicKit** (full-track in-process
  for subscribers, no developer user cap — needs dedicated research; no claims survived
  on it this run).

## Verified findings that shape implementation

1. **Web Playback SDK supports mobile browsers** (iOS + Android, Safari included) per
   current official docs. Caveat: community threads still report iOS Safari flakiness —
   field-test before betting mobile web on it. *(3-0, developer.spotify.com)*
2. **SDK is strictly Premium-only** everywhere; Spotify Lite / Premium Mini excluded.
   *(3-0 ×2)*
3. **iOS Safari autoplay rules**: playback transfer counts as autoplay and gets blocked
   unless `player.activateElement()` is called inside the user's tap AND the track starts
   promptly (>~10s after the gesture can still be blocked). Wire `activateElement()` +
   play into the game-start tap. *(3-0 ×3)*
4. **Embed iFrame API** is genuinely game-controllable: `loadUri/play/pause/seek` +
   `playback_update` events (position/duration) — fine for syncing game state (francis
   already does this). But programmatic control does **not** lift the preview wall;
   full-track conditions are undocumented officially and empirically ≈ logged-in Premium.
   Treat Embed as the **30s demo mode** for everyone else. *(3-0 ×5 across 2 findings)*
5. **App Remote SDK (iOS)**: no in-process playback — it drives the installed Spotify app
   (which handles playback, auth, networking, offline). Requires physical-device testing;
   needs a `playURI` to wake Spotify; **on-demand URI playback is Premium-only** (free =
   shuffle). v5.0.1 actively maintained (Aug 2025). *(3-0 ×5)*
6. **No mobile SDK streams in-process** since the 2014 streaming SDKs were killed
   (Sept 1 2022). The native app fundamentally cannot self-stream Spotify audio. *(3-0 ×2)*
7. **PKCE refresh**: token refresh needs only `client_id` (no secret, no Basic header) —
   browser-side refresh is correct. Refresh tokens **rotate** under PKCE: conditionally
   overwrite `sp_refresh` when a new one is returned, keep the old one otherwise.
   ✅ *Lobby already does this* (`js/spotify.js:60`). PKCE is an IETF mandate for
   browser public clients (RFC 9700 / BCP 240). *(3-0 ×3)*

**Refuted (0-3)**: "the iOS SDK overview's silence on Premium means free users get
full-track App Remote playback" — false planning assumption; Premium-only stands.

## Recommended changes to this codebase

1. **Mobile web games (grass cutter, half court)**: replace the Connect
   remote-control path with the Web Playback SDK in the phone browser —
   `activateElement()` on the start tap, play immediately, keep Connect as fallback
   when SDK init fails. Removes the "music plays on your other device" weirdness.
2. **Native iOS app**: swap `SpotifyAuthManager` Web-API play calls for **App Remote**
   when the Spotify app is installed (`spotify:` URL-scheme check); keep the current
   Connect call as fallback. Benefit: playback survives backgrounding, no token
   refresh mid-game, instant start.
3. **Standardize free-tier demo mode** on the Embed iFrame API across all three web
   games (francis's integration is the template — port its `playback_update` sync).
4. **Auth**: no changes needed (PKCE + conditional rotation already correct). Keep
   cookie scheme; note httpOnly tradeoffs were NOT adjudicated by this research.
5. **Before any public launch**: resolve the dev-mode user-cap question (see policy
   section) — it gates everything else.

## Open questions (worth a follow-up research pass)

- Can the app serve a public audience at all under Feb 2026 dev-mode rules; are
  per-band registrations or label partnerships viable within ToS?
- Does the Sept 2025 consumer free-tier change (limited daily on-demand picks) leak
  through App Remote/Connect in practice?
- Is MusicKit/Apple Music the better iOS bet (no user cap, full tracks for
  subscribers)? Do Apple Music streams serve the bands' promo goals as well as
  Spotify streams?
- Exact Embed full-track conditions for logged-in *free* users; iOS Safari
  third-party-cookie partitioning effects inside the game iframe.

## Primary sources

- developer.spotify.com: web-playback-sdk (+ getting-started, reference), embeds
  (+ iframe-api reference, troubleshooting), ios (+ getting-started), web-api
  refreshing-tokens & code-pkce-flow
- Spotify dev blog: 2022-03-31 (iFrame API), 2022-07-15 (streaming SDK shutdown),
  2024-11-27 (Web API removals), 2025-04-15 (extended-access criteria),
  2026-02-06 (dev-mode Premium + 5 test users)
- RFC 9700 / BCP 240; draft-ietf-oauth-browser-based-apps
- TechCrunch 2024-11-27 & 2026-02-06; github.com/spotify/ios-sdk; community threads
  (embed preview wall, mobile Safari reliability)
