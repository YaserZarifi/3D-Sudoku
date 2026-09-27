# Architecture

## Layers

```
SudokuEngine (scripts/sudoku)       pure logic, RefCounted, no Node APIs
        ▲
GameState / GameManager (scripts/core)   owns the current puzzle, undo, timer, emits signals
        ▲
Presentation
  Board3D (scripts/board)           cells, materials, visual states
  CameraController (scripts/camera) orbit, zoom, reset, auto-orient
  InputManager (scripts/input)      turns touch and mouse into intents
  UI (scripts/ui)                   HUD, number pad, menus
Services (autoloads, added when needed)
  SaveManager, AudioManager, HapticsManager, ThemeManager
```

Dependencies only point up this diagram. The engine doesn't know about the game state. The game state doesn't know about nodes it doesn't own. Presentation reads state and sends intents, and never edits a `Board` directly.

## Flow of one move

1. `InputManager` sees a tap below the drag threshold and raycasts. `Board3D` turns the hit into a cell `Vector3i`.
2. `GameManager.select_cell(coord)` updates `GameState` and emits `selection_changed`.
3. The player taps a digit on the number pad. `GameManager.enter_digit(d)` calls `Board.set_value` and pushes an undo move.
4. `GameManager` asks `Validator` for conflicts and completion, then emits `board_changed(changed_indices)`, and later `puzzle_solved` if the board is done.
5. `Board3D`, the HUD, audio and haptics react to those signals. None of them call each other.

In code, `scripts/core/game_screen.gd` is the only script that connects these pieces. It listens to `InputManager`, `GameUi` and `GameManager` signals and forwards intents.

## Cell visual state

Each `Cell3D` gets one state dictionary: `{digit, is_given, is_selected, is_peer, is_same_digit, is_conflict, is_dimmed}`. `CellStates.compute()` builds all 27 from the board, the selection and the slice focus, and `Cell3D.apply_state()` turns one into a look. There are no per-state code paths scattered across the board.

## Autoloads

Only systems that really are global are autoloads (`scripts/services/`):

- `SaveManager`: settings, statistics and the active puzzle in `user://save.json`
- `ThemeManager`: active palette, builds the UI `Theme` from `ThemeTokens`, dark mode
- `HapticsManager`: vibration with a setting and rate limit
- `AudioManager`: short synthesized sounds, respects the sound setting

`GameManager` is a node in the game scene, not an autoload, so a new game or a trip to the menu just frees the scene.

## Scenes

- `scenes/main/main.tscn`: entry point. `main.gd` swaps between the menu and the game.
- `scenes/menu/menu.tscn`: menu controls over a slowly turning cube.
- `scenes/game/game.tscn`: lights, `CameraRig`, `Board3D`, `GameManager` and the `GameUI` canvas layer.

Controls are built in code from theme tokens (`game_ui.gd`, `menu_screen.gd`, `ui_kit.gd`), so no visual value lives in a scene file.

## Testing

Tests live in `tests/`: the engine, plus the pure helpers around it (`GestureTracker`, `CellStates`, `GameState` and its save format, `SaveData`). They use the dependency-free runner in `tests/run_tests.gd`. Test files are named `test_*.gd`, extend `res://tests/test_case.gd`, and define `test_*` methods. Scripts that tests load must not rely on `class_name` lookups, because a fresh headless run may not have the global class cache yet. Use `preload` paths in engine code.
