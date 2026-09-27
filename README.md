# 3D Sudoku

A Sudoku puzzle played on a cube, built with Godot 4 for Android and iOS. Everything runs offline.

The rules for each puzzle tier are in [docs/game-rules.md](docs/game-rules.md). The plan is in [docs/roadmap.md](docs/roadmap.md).

## Opening the project

Install Godot 4.5 or newer (standard build, not .NET) and open `project.godot`.

## Running tests

The Sudoku engine tests run headless with no extra addons:

```bash
godot --headless --path . --import
godot --headless --path . -s tests/run_tests.gd
```

The first command only needs to run once after cloning. It builds Godot's import cache.
