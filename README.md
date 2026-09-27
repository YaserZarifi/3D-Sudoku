# 3D Sudoku

A Sudoku puzzle played on a cube, built with Godot 4 for Android and iOS. Everything runs offline.

There are two tiers:

- **Latin Cube** (digits 1 to 3): every line through the cube holds 1, 2 and 3 once. A gentle intro.
- **Slice Sudoku** (digits 1 to 9): every flat slice of the cube, along x, y and z, holds 1 to 9 once. The main game.

The full rules are in [docs/game-rules.md](docs/game-rules.md). The plan and what's left are in [docs/roadmap.md](docs/roadmap.md).

## Running it on your computer

1. Install Godot 4.5 or newer, the standard build (not .NET): https://godotengine.org/download
2. Clone the repo and open Godot's Project Manager.
3. Click **Import**, pick the `project.godot` file in the repo, then **Import & Edit**.
4. Press **F5** (or the play button at the top right) to run the game.

The window opens in portrait at 450 × 800. You can resize it to try other phone shapes.

From a terminal instead:

```bash
godot --path . --import      # once after cloning
godot --path .               # runs the game
```

### Controls on desktop

| Action | Mouse and keyboard |
|---|---|
| Select a cell | Click it |
| Deselect | Click empty space |
| Rotate the cube | Drag |
| Zoom | Mouse wheel |
| Reset the view | Double click empty space, **R**, or the Reset view button |
| Enter a digit | **1** to **9**, or the number pad |
| Erase | **Backspace** or **Delete** |
| Undo | **Ctrl+Z** or the Undo button |
| Show one slice | **X**, **Y** or **Z** buttons. Tap again for the next slice, then off |

## Running the tests

The tests cover the Sudoku engine, the gesture logic, the game state and the save format. They run headless with no addons:

```bash
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
```

The first command only needs to run once after cloning. The last line should read `55 passed, 0 failed`.

## Trying it on an Android phone

1. In Godot, open **Editor > Manage Export Templates** and download the templates for your Godot version.
2. Install the Android SDK (Android Studio is the easiest way) and a JDK 17.
3. In **Editor > Editor Settings > Export > Android**, set the Android SDK path and the Java SDK path. Godot creates a debug keystore on its own.
4. Turn on USB debugging on the phone and plug it in.
5. Either click the Android icon that appears next to the play button (one-click deploy), or use **Project > Export**, pick the **Android** preset and export an APK.

Release signing details go in `export_credentials.cfg`, which Godot keeps out of `export_presets.cfg` and which is in `.gitignore`. Never commit a keystore.

iOS needs a Mac with Xcode. Set your team ID in the iOS preset and export an Xcode project from there.

## Where things are

```
scripts/sudoku/    engine: variants, board, validator, solver, generator (pure logic)
scripts/core/      game state, game manager, save format, scene scripts
scripts/board/     3D cube and cells
scripts/camera/    orbit camera
scripts/input/     touch gestures
scripts/ui/        theme tokens, HUD, number pad, menu
scripts/services/  autoloads: save, theme, haptics, audio
scenes/            main router, menu, game
tests/             headless tests
docs/              rules, data model, architecture, interaction, design, roadmap
```

Saves live in Godot's user data folder (`user://save.json`). On desktop that's `~/.local/share/godot/app_userdata/3D Sudoku/` on Linux, `%APPDATA%\Godot\app_userdata\3D Sudoku\` on Windows and `~/Library/Application Support/Godot/app_userdata/3D Sudoku/` on macOS. Delete the file to start fresh.
