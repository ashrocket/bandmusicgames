# CheapLoop Handoff — bandmusicgames onboarding / Apple Music polish

## Source prompt

> take the existing work we stopped working on mid last week and spend no more than 10% of my weekly session fable budget but make it so much better of an experience, especially work on the onboarding, consider focusing on the Apple side of things, apple music integration is smoother than Spotify for now anyway.

## Compacted prompt

Repo `bandmusicgames`, branch `feat/hch-fun-polish-v2.4` (v2.4.0 polish done, awaiting playtest). Budget: lean — ≤10% of weekly Fable session budget.

Resume last week's stopped work and materially improve the app experience, prioritizing onboarding and the Apple Music path (preferred over Spotify for now).

Established facts:

1. Stopped work = uncommitted diff in `ios/BandMusicGames/Views/Games/LizzyMcGuireGameView.swift` (+65/−54): lobby and character-select wrapped in ScrollViews so PLAY/footer stay reachable on compact-landscape screens. Coherent and standalone.
2. No onboarding exists anywhere. Boot is hijacked by playtest flags: `BandMusicGamesApp.showsNaraRoom = true` and `ContentView.autoLaunchLizzyLobby = true`.
3. Apple Music is fallback-only today — reachable solely via the SpotifyErrorBanner "Switch to Apple Music" button. `AppleMusicManager.activateAsPreferred()` has a 300 ms sleep race before reading `canPlayCatalog`.
4. All three native games (Lizzy, Francis, ForCuttingGrass) already route playback via `appleMusic.isPreferred` + `song.appleMusicId`; all 3 catalog songs have `appleMusicId`.
5. `ContentView.handlePlay` only attempts Spotify (`auth.canAttemptPlayback`) and forces the Spotify sheet for non-native games when disconnected — it ignores the Apple Music preference.
6. BUG: `ios/Info.plist` lacks `NSAppleMusicUsageDescription`, so the MusicKit authorization prompt cannot be shown (app is killed on request on device).

Work items, in order:

- **A.** Commit the stopped LizzyMcGuire scroll work as its own commit.
- **B.** Add `NSAppleMusicUsageDescription` to `ios/Info.plist`.
- **C.** Fix `activateAsPreferred()`: replace the sleep race with a direct `MusicSubscription.current` check.
- **D.** New first-run onboarding (`Views/OnboardingView.swift`): choose music source — Apple Music (recommended; inline auth request + subscription check, graceful denied/no-subscription states), Spotify (existing `SpotifySheetView`), or Skip (play without music). Persist `hasCompletedOnboarding`; set `appleMusic.isPreferred` on the Apple path. Match the monospaced/neon jukebox aesthetic.
- **E.** Wire into boot: flip `showsNaraRoom = false` and `autoLaunchLizzyLobby = false`; show onboarding before `JukeboxView` on first run.
- **F.** `ContentView.handlePlay` + the non-native-game gate: respect `appleMusic.isPreferred` (play via Apple Music; don't force the Spotify sheet).

Verify: project builds for iOS simulator (`xcodebuild`), unit tests pass.

## Why content was dropped

- Skill-invocation mechanics, budget phrasing repetition, and hedging ("consider focusing on…") collapsed into the direct Apple-first priority.
- "Existing work stopped mid last week" resolved to the concrete uncommitted diff + branch state, so the vague reference is replaced by file paths.
- Memory/recall context (HCH difficulty history, TestFlight IDs, storm branch) dropped — not load-bearing for this task.

## Browser/Chrome routing decision

None — no browser work in this task. (Rule kept: any future Chrome step goes to a Haiku-override subagent, never Fable-direct.)

## Rough before/after size

- Source (user prompt + session context actually consumed — memory index, git state, surveyed files): 30,855 chars, archived at `.cheaploop/benchmarks/prompts/bmg-onboarding-src.txt`
- Compacted handoff prompt: ~2,400 chars (ratio ≈ 0.08)
- The bare user prompt was only 311 chars (context-poor); the compaction is of the session context, so the fingerprint source includes it. A future `fable-unthrottled` comparison run must use the same archived source file.

## Benchmark record

- Log path: `.cheaploop/benchmarks/sessions.jsonl` (this repo)
- Prompt hash: `sha256:46da24e8e94e047925c72c10d41dd8d1349ff3150b16baf85980fcd65a58804e`
- Mode: `cheaploop`, session `cheaploop-bmg-onboarding-001`, model `claude-fable-5`, runner `claude-code`
- Recorded via `python3 -m cheaploop_bench record` from `/Users/ashrocket/ashcode/cheaploop`
