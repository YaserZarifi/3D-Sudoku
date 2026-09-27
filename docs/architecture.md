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

## Cell visual state

Each `Cell3D` gets one state struct: `{digit, is_given, is_selected, is_peer, is_same_digit, is_conflict, is_dimmed}`. It computes its look from that struct in one place. There are no per-state code paths scattered across the board.

## Autoloads

Only systems that really are global become autoloads, and only once they exist. Planned: `SaveManager`, `AudioManager`, `HapticsManager`, `ThemeManager`. `GameManager` is a node in the game scene, not an autoload, so the game can be restarted by reloading the scene.

## Scenes

- `scenes/main/main.tscn`: entry point. It'll become a small router that swaps screens.
- `scenes/game/`, `scenes/board/`, `scenes/ui/`: added in Milestone 3 and later.

## Testing

Engine tests live in `tests/`. They use the dependency-free runner in `tests/run_tests.gd`. Test files are named `test_*.gd`, extend `res://tests/test_case.gd`, and define `test_*` methods. Scripts that tests load must not rely on `class_name` lookups, because a fresh headless run may not have the global class cache yet. Use `preload` paths in engine code.
