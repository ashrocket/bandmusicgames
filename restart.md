# Restart Prompt

Use this prompt in a new Codex session.

1. Start here:

   ```sh
   cd /Users/ashrocket/ashcode/bandmusicgames
   ```

2. Read `AGENTS.md` and keep the work on the Codex-first loop: inspect first, make scoped edits, verify, review the diff, and report changed behavior plus verification.

3. Continue this active goal:

   Bring the BandMusicGames web/laptop games and native iOS games to consistent, high-quality parity while keeping each repo clean, independently deployable, and clear about source of truth.

   Context:
   - `bandmusicgames` owns the native iOS app and shared lobby.
   - `/Users/ashrocket/ashcode/forcuttinggrass`, `/Users/ashrocket/ashcode/lizzymcguire`, and `/Users/ashrocket/ashcode/francis` own the deployed web versions.
   - For each feature, treat the better implementation as the reference. Do not assume native or web is automatically canonical.

   Constraints:
   - Keep repos separate and clean.
   - Do not copy native Swift into web repos.
   - Do not let web fixes sit unpushed.
   - Preserve each repo's deploy path.
   - Do not mark the goal complete until all parity, deploy, and verification gates are actually done.

   Done when:
   - Each game has a parity matrix covering gameplay, controls, art, audio, save state, menus, Spotify, mobile, laptop, and deploys.
   - Gaps are implemented on the weaker platform.
   - All four repos have clean worktrees.
   - Web games deploy from GitHub Actions.
   - Native builds pass.

   Verification required:
   - Browser smoke tests for web/laptop versions.
   - Live HTTP checks for deployed sites.
   - GitHub Actions deploy checks for web repos.
   - `xcodebuild` plus simulator launch-state checks for native iOS.

4. Current verified state at handoff:

   - `bandmusicgames` is on `feat/goon-native-port` tracking `origin/feat/goon-native-port`.
   - `forcuttinggrass`, `lizzymcguire`, and `francis` are on `main` tracking `origin/main`.
   - `forcuttinggrass`, `lizzymcguire`, and `francis` were clean by `git status -sb` at handoff.
   - `bandmusicgames` native TestFlight build `202605182100` was archived and uploaded to App Store Connect from this branch.
   - Archive path used: `/private/tmp/BandMusicGames-202605182100.xcarchive`.
   - Export/upload path used: `/private/tmp/BandMusicGames-202605182100-export`.
   - App Store Connect upload output ended with `Uploaded BandMusicGames` and `** EXPORT SUCCEEDED **`; wait for TestFlight processing before installing.
   - `docs/parity-matrix.md` is the current parity tracker.
   - `scripts/smoke-web.sh` exists and passed previously with live HTTP checks plus local DOM checks.
   - `scripts/smoke-ios.sh` exists and now launches lobby, Goon levels 1-5, Frattypipeline autoplay, Francis, Lizzy title, Lizzy picker, and Lizzy gameplay.
   - Full native iOS tests passed with 41 tests and 0 failures on iPhone 17 simulator.
   - Focused native iOS tests passed with 30 tests and 0 failures across Frattypipeline, Goon game state, and Goon levels.
   - Native iOS smoke passed with `SMOKE_SETTLE_SECONDS=8 scripts/smoke-ios.sh` and produced screenshots under `/private/tmp/bmg-ios-smoke-*.png`.
   - Screenshot sanity checks confirmed nonblank lobby, Goon levels 1-5, Frattypipeline, Francis, Lizzy title, Lizzy picker, and Lizzy gameplay captures.
   - `forcuttinggrass` deploy workflow passed: run `26057901595`.
   - `halfcourthero` deploy workflow passed: run `26057900787`.
   - `francis` deploy workflow failed: run `26059966440`.
   - `francis` custom domain still returned HTTP 200 from a prior deploy, but GitHub Actions deploy is not healthy.

5. Known deploy blocker:

   - `ashrocket/francis` has `CLOUDFLARE_ACCOUNT_ID` set.
   - `ashrocket/francis` is missing `CLOUDFLARE_API_TOKEN`.
   - Do not set the local Wrangler OAuth token as the GitHub secret; it was short-lived and not durable CI auth.
   - Fixing this needs a durable Cloudflare API token, then rerun the Francis deploy workflow.

6. Latest native Goon parity implemented:

   - Pushed commits:
     - `f31911c feat: close native goon gas and stump gaps`
     - `7106d52 feat: add native goon cricket parity`
   - Movement-gated mowing and gas drain now match the web game behavior more closely.
   - Gas cans are placed deterministically, render on an item layer, bob visibly, refill gas to `config.gasMax`, and emit pickup particles.
   - Stumps are placed deterministically without overlapping gas cans, block mower movement and mowing, show dig progress, and become cut tiles when dug.
   - Crickets are placed deterministically without overlapping gas cans or stumps, hop on the configured level timer, splat on collision, and subtract 30 gas.
   - Level debug launch arguments support `-bmg-goon-level 2` and `-bmg-goon-level=2`.
   - Focused tests cover idle gas/cutting, gas-can placement and pickup, stump placement, stump blocking, stump digging, cricket placement, cricket hopping, and cricket gas penalty.

7. Latest native Frattypipeline state:

   - A Frattypipeline V2 promise prototype exists under `ios/BandMusicGames/Views/Games/Frattypipeline/`.
   - The native app lobby can route to the prototype through the `frattypipeline` song entry.
   - Debug launch supports `-bmg-open-frattypipeline` and `-bmg-frattypipeline-autoplay` for smoke-test capture.
   - Prototype now has a beat-indexed song section, campus hype state, progressive stem unlocks, HUD pills for mood/section/stems, a generated audio conductor, and song-reactive backdrop/tile color changes.
   - Prototype tests exist under `ios/BandMusicGamesTests/Frattypipeline/`.
   - `docs/frattypipeline-v2-goal.md` captures the product goal and vertical-slice acceptance criteria.
   - `xcodegen generate` was run from `ios/` so the Xcode project includes the new prototype sources and tests.

8. Next concrete implementation task:

   Continue parity work by choosing the weakest remaining surface and closing the next small gap. For Goon native, the remaining gameplay gaps are skunks, poo hazards, score/combo behavior, replay details, and stump power-up behavior. For web/laptop quality, verify the live deployed versions against the native simulator captures and fix whichever side is weaker.

   Inspect these files before editing Goon again:
   - `docs/parity-matrix.md`
   - `ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`
   - `ios/BandMusicGames/Views/Games/Goon/GoonInputController.swift`
   - `ios/BandMusicGames/Views/Games/Goon/GoonLevels.swift`
   - `ios/BandMusicGames/Views/Games/Goon/GoonRenderer.swift`
   - `ios/BandMusicGamesTests/Goon/GoonLevelsTests.swift`
   - `ios/BandMusicGamesTests/Goon/GoonGameStateTests.swift`
   - `/Users/ashrocket/ashcode/forcuttinggrass/js/game.js`

9. Verification before the next handoff:

   - Run focused iOS tests for any touched native game.
   - Run full `xcodebuild` tests when project wiring, shared app routing, or generated Xcode files change.
   - Run `scripts/smoke-ios.sh` for native launch and screenshot coverage after UI/gameplay work.
   - Run `scripts/smoke-web.sh` and live deploy checks after web/laptop changes.
   - Run `git status -sb` in all four repos.

10. Useful status commands:

   ```sh
   git status -sb
   git -C /Users/ashrocket/ashcode/forcuttinggrass status -sb
   git -C /Users/ashrocket/ashcode/lizzymcguire status -sb
   git -C /Users/ashrocket/ashcode/francis status -sb
   gh run list --repo ashrocket/forcuttinggrass --branch main --limit 1
   gh run list --repo ashrocket/halfcourthero --branch main --limit 1
   gh run list --repo ashrocket/francis --branch main --limit 1
   ```

11. Stop conditions:

   - If the Francis Cloudflare token is still unavailable, keep it documented as a deploy blocker instead of inventing a workaround.
   - If unrelated user changes appear, preserve them and work around them.
   - If a command needs network, simulator, or filesystem escalation, request it directly and keep going after approval.
