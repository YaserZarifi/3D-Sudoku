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

## 3. 3D board prototype

- `Board3D` builds 27 `Cell3D` instances from a `Variant`, with shared materials and a single state struct per cell
- Digit rendering on cells (Label3D or a digit atlas, to be decided by testing readability)
- `CameraController`: orbit, clamped pitch, pinch zoom, inertia, animated reset
- `InputManager`: tap versus drag threshold, raycast selection, UI touches kept separate
- Slice focus and exploded spacing, to test readability

Done when: rotating and selecting feels good on a real phone, and the middle cell is easy to reach.

## 4. Gameplay

`GameManager` and `GameState`: load a generated puzzle, enter digits, erase, undo, conflicts, completion, restart.

## 5. Mobile UX

Number pad, HUD, safe areas, responsive layout on small, tall and tablet screens, haptics, theme tokens in use.

## 6. Visual polish

Materials, lighting, typography, icons, motion, sound, completion moment.

## 7. Persistence

Save and resume the active puzzle, settings, basic statistics. Corrupt save data falls back safely.

## 8. Mobile builds

Android export, performance on a mid-range device, input and crash testing. Then iOS export setup.
