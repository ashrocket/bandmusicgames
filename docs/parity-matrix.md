# BandMusicGames Web/Native Parity Matrix

## Goal

Bring the web/laptop games and native iOS games to consistent, high-quality parity while keeping each repo clean, independently deployable, and clear about source of truth.

## Source Of Truth

- `bandmusicgames` owns the native iOS app and shared lobby.
- `forcuttinggrass`, `lizzymcguire`, and `francis` own the deployed web games.
- For each feature, the better implementation is the reference. Do not assume native or web is automatically canonical.
- Native Swift stays in `bandmusicgames`. Web game changes stay in their sibling repos.

## Verification Gates

| Surface | Gate | Current command or evidence |
| --- | --- | --- |
| Native iOS | Builds, installs, launches key states, and captures screenshots | `scripts/smoke-ios.sh` |
| Web lobby | Local page serves and DOM markers render in a browser | `scripts/smoke-web.sh` |
| Web games | Live URLs respond and local DOM markers render in a browser | `scripts/smoke-web.sh` |
| Web deploys | GitHub Actions Cloudflare deploy passes | `gh run list --repo ashrocket/<repo> --branch main --limit 1` |
| Live sites | Custom domains return 200 | `curl -fsSI https://...` |
| Repo hygiene | Worktree clean | `git status -sb` in all four repos |

## Goon / For Cutting Grass

| Area | Web state | Native state | Reference | Gap / next work |
| --- | --- | --- | --- | --- |
| Gameplay | Phaser game with 5 levels, gas, stumps, crickets, skunks, poo hazards, score, retry, win, replay. | SpriteKit port with levels, tile grid, mowing, movement-gated gas drain/cutting, gas-can placement/pickup, stump blockers/digging, cricket placement/hopping/gas penalty, phase state, renderer, native overlays. | Web for gameplay completeness. | Continue hazard parity: skunks, poo, score/combo, replay, and stump power-up behavior. |
| Controls | Keyboard, pointer, mobile D-pad/throttle/dig, canvas fallback. | Native joystick and dig overlay. | Split: web for laptop, native for app ergonomics. | Add explicit native parity tests for one-hand controls and verify level 3 stump digging. |
| Art | Pixel/procedural web visuals with Phaser effects. | Native SpriteKit fallback shapes plus texture lookup and grass animation. | Native for texture pipeline, web for gameplay readability. | Finish missing native sprite atlas and compare tile/hazard readability on device. |
| Audio | Web Audio SFX plus Spotify overlay integration. | Procedural/native audio planned or partial; Spotify track starts from app auth. | Web for SFX richness, native for app Spotify lifecycle. | Port SFX set: mower, cut, gas, dig, splat, spray, game over, level complete. |
| Save state | Cookie/local progress helpers. | `UserDefaults` saved level/win state. | Tie. | Verify reset/replay behavior matches web. |
| Menus | Web level picker, game over, win, replay. | Native phase cards and overlays. | Web for completeness. | Compare every phase screen and add missing menu actions. |
| Spotify | Web cookie/overlay based. | Native app auth manager starts track directly. | Native for app, web for laptop. | Confirm web token cookie name and native pause-on-exit parity. |
| Mobile | Web recently improved mobile controls and HUD. | Native iOS target. | Native for iPhone, web for mobile browser fallback. | Browser-test web portrait/landscape and simulator-test native touch flow. |
| Laptop | Web has keyboard/desktop flow. | Native app is iOS only. | Web. | Keep web as laptop canonical. |
| Deploy | `forcuttinggrass` GitHub Actions deploy passes. | Native branch pushed; not merged to main. | Both. | Merge native branch through review once parity gaps are accepted. |

## Half Court Hero / Lizzy McGuire

| Area | Web state | Native state | Reference | Gap / next work |
| --- | --- | --- | --- | --- |
| Gameplay | Large canvas basketball game with shooting, defense, NPC behavior, touch/keyboard/mouse, feedback overlay, character pages. | SwiftUI Canvas game with title, character select, gameplay, ended state, native sprites. | Web for basketball mechanics depth. | Compare shot timing, rebounds, pass/steal/block, CPU behavior, win conditions. |
| Controls | Mature browser controls and laptop support. | Native joystick/action buttons. | Web for laptop, native for iPhone. | Add simulator launch checks for title, teammate picker, and gameplay. |
| Art | Updated PNG character sprites and court environment. | Native asset catalog imports matching web art. | Shared. | Keep asset versions traceable; avoid silent drift between PNG sets. |
| Audio | Web Spotify integration and volume/mute UI. | Native Spotify track playback via auth manager. | Split. | Add/native-match mute/pause behavior and verify web local dev skip path. |
| Save state | Browser state as implemented in web. | Native in-memory game state, no obvious persistent basketball progress. | Web if persistence exists. | Decide whether basketball needs persistent unlock/progress on native. |
| Menus | Web title and character selection surfaces. | Native title and two-step teammate picker. | Native for app framing, web for depth. | Compare character bios, selection affordances, difficulty, start/replay paths. |
| Spotify | Web overlay and `js/spotify.js`. | Native app-level Spotify auth. | Native in app, web on laptop. | Verify `127.0.0.1` local dev path and native pause-on-dismiss. |
| Mobile | Web touch controls exist; native is primary iPhone experience. | Native full-screen iOS game. | Native. | Browser smoke web mobile, simulator smoke native states. |
| Laptop | Web is canonical. | Native not laptop-targeted. | Web. | Keep web deploy healthy and keyboard/mouse controls first-class. |
| Deploy | `halfcourthero` GitHub Actions deploy passes. | Native branch pushed in `bandmusicgames`. | Both. | Add native parity tests before merging. |

## Francis

| Area | Web state | Native state | Reference | Gap / next work |
| --- | --- | --- | --- | --- |
| Gameplay | D3/SVG constellation interaction, pointer drawing, ambient stars, card scene, Spotify embed prompt. | SwiftUI Canvas native game with star canvas and accessibility layer. | Web for interaction richness. | Compare star sequence, scoring/reveal logic, card/result flow, and ambient star behavior. |
| Controls | Pointer/mouse/touch drawing. | Native touch Canvas interaction. | Web for laptop, native for iPhone. | Add web laptop smoke and native simulator touch-state checks. |
| Art | SVG constellation and organic dog visual refresh. | Native Canvas implementation and app framing. | Split. | Decide whether the web dog/card art should become native assets or remain web-specific. |
| Audio | Spotify embed/player prompt and mute UI. | Native Spotify track playback from auth manager. | Native for app Spotify lifecycle, web for browser. | Align logged-in/needs-login messaging across web and app. |
| Save state | Browser runtime state. | Native runtime state. | Unclear. | Decide if Francis needs persistent progress at all. |
| Menus | Web intro/login/card overlays. | Native full-screen view and result framing. | Web for richer narrative flow. | Compare start, complete, fail, and replay states. |
| Spotify | Web uses Spotify embed/login flow. | Native calls `playTrack`. | Split. | Verify web embed works after deploy and native pause-on-dismiss. |
| Mobile | Web touch support exists. | Native primary iPhone path. | Native. | Browser-test web mobile as fallback. |
| Laptop | Web is canonical. | Native not laptop-targeted. | Web. | Keep web pointer interactions first-class. |
| Deploy | Repo now exists and code is pushed; GitHub Actions fails because `CLOUDFLARE_API_TOKEN` is missing. `CLOUDFLARE_ACCOUNT_ID` is set. | Native branch pushed in `bandmusicgames`. | Both. | Add `CLOUDFLARE_API_TOKEN` to `ashrocket/francis`, then rerun deploy. |

## Current Implementation Backlog

1. Add the missing `CLOUDFLARE_API_TOKEN` secret to `ashrocket/francis` and rerun the deploy workflow.
2. Expand `scripts/smoke-ios.sh` with stronger visual assertions for each screenshot.
3. Expand `scripts/smoke-web.sh` with desktop/mobile viewport interaction checks for each game.
4. For each game, compare web and native manually once, then convert the differences into issue-sized tasks.
5. Promote better mechanics both ways: web remains laptop canonical, native remains iPhone canonical.
