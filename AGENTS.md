# BandMusicGames Codex Notes

## Source of Truth

- This repo owns the BandMusicGames lobby and native iOS app.
- Native Swift/SwiftUI/SpriteKit game code belongs under `ios/BandMusicGames/`.
- The sibling repos are web game deploy roots and reference implementations:
  - `../forcuttinggrass` -> `https://forcuttinggrass.goon.bandmusicgames.party`
  - `../lizzymcguire` -> `https://lizzymcguire.narasroom.bandmusicgames.party`
  - `../francis` -> `https://francis.darger.bandmusicgames.party`
- Do not copy native Swift code back into sibling web repos. Port from the web repos into this repo when building native iOS versions.

## Repo Hygiene

- Keep this repo clean before handing off. Commit scoped native/lobby changes or explicitly document any remaining dirty state.
- Treat sibling repo changes as separate deployable units. Verify and commit them in their own repos.
- Do not move sibling repos into this checkout unless the project intentionally changes to a submodule or monorepo layout.

## Verification

- Web lobby: `npm run dev` from repo root, then verify the lobby in a browser.
- iOS app: run `xcodegen generate` from `ios/` after project structure changes, then build/test with `xcodebuild`.
- UI changes need browser or simulator verification, not only source inspection.
