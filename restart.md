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
   - `bandmusicgames` should also be clean after the latest parity/prototype commits are pushed.
   - `docs/parity-matrix.md` is the current parity tracker.
   - `scripts/smoke-web.sh` exists and passed previously with live HTTP checks plus local DOM checks.
   - `scripts/smoke-ios.sh` exists and now launches lobby, Goon level 1, Goon level 2, Goon level 3, Francis, Lizzy title, Lizzy picker, and Lizzy gameplay.
   - Native iOS tests passed with 34 tests and 0 failures.
   - Native iOS smoke passed and produced screenshots under `/private/tmp/bmg-ios-smoke-*.png`.
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

   - Movement-gated mowing and gas drain now match the web game behavior more closely.
   - Gas cans are placed deterministically, render on an item layer, bob visibly, refill gas to `config.gasMax`, and emit pickup particles.
   - Stumps are placed deterministically without overlapping gas cans, block mower movement and mowing, show dig progress, and become cut tiles when dug.
   - Level debug launch arguments support `-bmg-goon-level 2` and `-bmg-goon-level=2`.
   - Focused tests cover idle gas/cutting, gas-can placement and pickup, stump placement, stump blocking, and stump digging.

7. Latest native Frattypipeline state:

   - A Frattypipeline V2 promise prototype exists under `ios/BandMusicGames/Views/Games/Frattypipeline/`.
   - The native app lobby can route to the prototype through the `frattypipeline` song entry.
   - Prototype tests exist under `ios/BandMusicGamesTests/Frattypipeline/`.
   - `docs/frattypipeline-v2-goal.md` captures the product goal and vertical-slice acceptance criteria.
   - `xcodegen generate` was run from `ios/` so the Xcode project includes the new prototype sources and tests.

8. Next concrete implementation task:

   Continue parity work by choosing the weakest remaining surface and closing the next small gap. For Goon native, the remaining gameplay gaps are crickets, skunks, poo hazards, gas penalties, score/combo behavior, replay details, and stump power-up behavior. For web/laptop quality, verify the live deployed versions against the native simulator captures and fix whichever side is weaker.

   Inspect these files before editing Goon again:
   - `docs/parity-matrix.md`
   - `ios/BandMusicGames/Views/Games/Goon/GoonGameScene.swift`
   - `ios/BandMusicGames/Views/Games/Goon/GoonInputController.swift`
   - `ios/BandMusicGames/Views/Games/Goon/GoonGrid.swift`
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
