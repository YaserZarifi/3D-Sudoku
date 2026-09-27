# Roadmap

Each milestone ends with tests passing, a manual run, updated docs and one or more clean commits.

## 1. Project foundation (done)

- Repository, `.gitignore`, `.gitattributes`
- `project.godot`: Mobile renderer, portrait, stretch settings, touch emulation, input actions
- Minimal main scene
- Docs: rules, data model, architecture, interaction model, design system
- Headless test runner and cloud setup script
- Project imports headless on Godot 4.5.1 with no warnings, and the smoke test passes

The theme resource and InputManager move into the milestones that first use them (3 and 5), so no empty systems get built now.

## 2. Sudoku engine (done)

- `Variant` with `latin_cube(3)` and `slice_sudoku(3)` factories, index helpers and precomputed peers
- `Board`, `Validator`, `Solver` (propagation plus backtracking, with solution counting and stats)
- `Generator` (seeded, uniqueness checked) and a first-pass difficulty rating
- Tests: indexing, group counts and peer counts per tier, set and clear rules, conflicts, completion, solving known puzzles, no-solution boards, uniqueness, generated puzzles always valid and unique, same seed gives the same puzzle
- Measure clue counts and generation time for Tier 2 and write them into game-rules.md

Done when: all tests pass headless, and generation for Tier 2 takes under ~200 ms on desktop.

Result: 31 engine tests pass. Tier 2 generation takes about 5 ms (worst seen 12 ms). Clue counts are in game-rules.md.

## 3. 3D board prototype (done)

- `Board3D` builds 27 `Cell3D` instances from a `Variant`, with shared materials and a single state dictionary per cell (`cell_states.gd`)
- Cells are beveled blocks built in code (`cell_mesh.gd`)
- Digits are billboard `Label3D`s. Each frame the digit moves to the camera side of its cell, onto the plane touching the cell's nearest point, so a cell never hides its own digit while nearer cells still do. Bold is an outline in the digit's own color
- `CameraController`: orbit, pitch clamped to ±70°, pinch and wheel zoom, inertia, animated reset, framing that fits the board area on any aspect ratio
- `InputManager` (a transparent Control over the board area) plus a pure `GestureTracker`: tap versus drag threshold, double tap, pinch. Picking is a ray against cell boxes, no physics
- Slice focus (X, Y, Z buttons cycle through the three layers, then off) and exploded spacing while dragging

Left for a real phone: confirm the feel of orbit speed, inertia and tap threshold, and that the middle cell is easy to reach with slice focus.

## 4. Gameplay (done)

`GameManager` and `GameState`: generated puzzles, enter digits, erase, undo (including erases), hints, conflicts, mistakes, completion, restart. Keyboard works on desktop (1 to 9, Backspace or Delete, Ctrl+Z, R to reset the view).

## 5. Mobile UX (done)

- Number pad (larger 1 to 3 row for Tier 1), Erase and Hint, HUD with Menu, tier, timer and Undo
- Safe areas on mobile, layout that fits small, tall and tablet screens
- `HapticsManager` with a setting and rate limit, `ThemeManager` building the UI `Theme` from `ThemeTokens`
- Digits that are all placed fade on the pad but stay usable
- Android back button pauses the game, or quits from the menu

## 6. Visual polish (done, first pass)

- Light and dark palettes, soft lighting, beveled cells
- Motion: digit pop, conflict shake, selection scale, camera ease, all halved or removed with Reduced motion
- Synthesized sounds (select, place, erase, conflict, solved), no audio files
- Completion: a success-colored wave across the cube, a slow spin, then a summary with time, mistakes, hints and best time
- Menu with a slowly turning solved cube

Second pass (done):
- Inter (SIL Open Font License) with tabular figures, bold givens on the cube, rounded modern theme with hairline borders and soft shadows
- Press feedback on every button, fades between screens and sheets, a clean splash, 2x MSAA on the cube
- New app icon

## 7b. Features (done)

- Pencil marks with a Notes toggle. Placing a digit clears it from the notes of every peer, and one undo restores it all
- Daily puzzle (Slice Sudoku, Medium, seeded by the local date) with a streak
- Statistics sheet: played, solved, best and average time per tier and level, daily streak
- Guided tutorial on a fixed Latin Cube, offered on first launch
- Menu with Continue, New Game, Daily, Stats, How to play and Settings

## 7. Persistence (done)

`SaveManager` writes settings, statistics and the active puzzle to `user://save.json` after every move, through a temp file. A corrupt save is moved to `save.corrupt.json` and the game starts from defaults. Restored games are fully validated before use.

## 8. Mobile builds (Android done)

Done:
- Android and iOS export presets (`export_presets.cfg`), portrait, vibrate permission, no internet permission
- Build steps in the README
- GitHub Actions: tests on every push, and a release workflow that builds and signs the APK and publishes it with notes from `docs/releases/`
- Performance: digit labels only move when the camera or a cell moves, the timer label updates once a second, saves are batched and flushed on pause or exit

Left (needs a real machine and devices):
- Install Android export templates and SDK, export a debug APK and test on a mid-range phone
- Performance, input and crash testing on device
- iOS export on a Mac with Xcode, signing team set in the preset
