# 3D Sudoku

A mobile Sudoku game played on a 3D cube. Godot 4.5+, GDScript, Mobile renderer, portrait orientation. Android first, iOS later. Fully offline.

Read before working:
- `docs/game-rules.md`: tier rules (Tier 1 Latin Cube 1 to 3, Tier 2 Slice Sudoku 1 to 9)
- `docs/data-model.md`: Variant, Board, Validator, Solver, Generator
- `docs/architecture.md`: layers and signal flow
- `docs/interaction-model.md`: gestures, layout, feedback
- `docs/roadmap.md`: current milestone and what's left

## Commands

```bash
godot --headless --path . --import            # once after clone
godot --headless --path . -s tests/run_tests.gd
```

In cloud sessions, `scripts/tools/setup_godot.sh` installs Godot through the SessionStart hook.

## How to work

- Go one milestone at a time. At the start: inspect the repo, state the plan and the risks. At the end: run the tests, run the project, review, update the docs, commit.
- The engine (`scripts/sudoku/`) is pure `RefCounted` GDScript. No nodes, scenes, input, audio or UI in it.
- Coordinate math lives only in `Variant` (`index_of`, `coord_of`). Everywhere else uses `Vector3i` or indices.
- Don't hard-code board size, digit count or group layout outside the variant factories.
- Use `preload` with paths instead of relying on `class_name`, so headless tests work on a fresh clone.
- Add a regression test when fixing an engine bug.
- Keep scripts small and single-purpose. Don't build a system before something uses it.
- Put visual values in theme tokens (`docs/design-system.md`), never hard-coded in scenes.
- UI copy is short: "New Game", "Resume", "Undo".

## Code style

- Static typing everywhere (`var count: int`, `func solve(board: Board) -> bool`).
- Clear names. Constants for tuning values. Comments explain why, not what.
- Tabs for indentation (Godot default).

## Git

- Use the existing git identity. Never change it.
- Short, natural, imperative commit messages: "Add puzzle solver", "Fix selection after rotation". No conventional-commit prefixes.
- No em dashes in commit messages. No mention of AI tools. No Co-authored-by trailers or any other AI attribution.
- Check `git status` and `git diff` before committing. One meaningful unit of work per commit.
- Never commit secrets, keystores, export credentials, `.godot/` or build output.
