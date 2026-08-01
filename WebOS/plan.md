# LG TV (webOS) Integration Plan

## Objective
Transform the Band Music Games lobby into an All-in-One native webOS application for the LG TV App Store. The app will feature a new song search function and will load game URLs internally via a fullscreen iframe rather than redirecting the browser. This development will be isolated in a separate git worktree.

## Key Files & Context
- Git repository: Need to create a new worktree.
- `index.html`: Will be updated to include a Search UI and an Iframe container.
- `js/lobby.js`: Will handle the new Search logic and the Iframe lifecycle (opening, closing, and returning to the lobby).
- `appinfo.json` (New): Required webOS configuration file.

## Implementation Steps

### Phase 1: Environment Setup
1. Create a new git worktree named `bandmusicgames-lg-tv` branching off `main`.
2. Navigate into the new worktree to perform all subsequent changes.

### Phase 2: webOS App Configuration
1. Create an `appinfo.json` file in the root directory with the necessary webOS metadata (id, version, title, etc.).
2. (Optional) Add placeholder icon files if required by the webOS packager, or define them in `appinfo.json`.

### Phase 3: Song Search Function
1. Update `index.html` to include a visually consistent search input element (e.g., above or below the iPod dial, or as an overlay).
2. Update `js/lobby.js` to filter the `SONGS` array based on the search input.
3. Allow the user to select a searched song and trigger the play action.

### Phase 4: All-in-One Iframe Integration
1. Update `index.html` to add a hidden fullscreen container for the game `<iframe>` and a "Back to Lobby" button.
2. Modify the click/touch handlers in `js/lobby.js` to prevent `window.location.href` redirection.
3. Instead, set the `<iframe>` source to the selected song's `gameUrl` and display the iframe container.
4. Implement a handler (either via the "Back to Lobby" UI button or by listening for the TV remote's physical back button via webOS events) to hide the iframe, clear its source, and return focus to the lobby dial.

## Verification & Testing
- Ensure the git worktree is created successfully and isolated.
- Verify that `appinfo.json` is correctly formatted.
- Test the Search function to ensure it filters the `SONGS` list accurately and allows selection.
- Test that selecting a game opens it in the iframe without navigating away from the main app.
- Test the "Back" functionality to ensure the iframe closes and the lobby state is preserved.