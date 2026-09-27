# Board data model

The engine lives in `scripts/sudoku/`. It's plain GDScript on `RefCounted`, with no nodes, scenes or resources. That keeps it testable headless and portable between scenes.

## Variant

A `Variant` describes one tier. It's built once and never changed.

- `id`, for example `"latin_cube_3"` or `"slice_sudoku_3"`
- `size`, the cube edge N
- `digit_count`, the highest digit (3 or 9 today)
- `groups`: `Array[PackedInt32Array]`, each one the cell indices of a single constraint group
- `peers`: `Array[PackedInt32Array]`, precomputed from `groups`, with duplicates and the cell itself removed
- `cell_groups`: `Array[PackedInt32Array]`, the group ids each cell belongs to

Factory functions (`Variants.latin_cube(3)`, `Variants.slice_sudoku(3)`) build the groups. Nothing else in the codebase enumerates lines or slices.

## Cell index

Cells are stored in flat arrays. The one conversion lives on `Variant`:

```
index = x + y * N + z * N * N
x = index % N
y = (index / N) % N
z = index / (N * N)
```

`Variant.index_of(x, y, z)`, `Variant.coord_of(index) -> Vector3i` and `Variant.is_valid_coord(coord)` are the only functions allowed to do this math. The 3D layer works with `Vector3i` and calls these helpers.

## Board

A `Board` is the mutable state of one puzzle.

- `variant`: `Variant`
- `values`: `PackedByteArray`, one byte per cell, where 0 means empty
- `givens`: `PackedByteArray` used as a mask, where 1 means the cell is a given
- `solution`: `PackedByteArray`, stored with the puzzle so hints and the optional solution check don't need a re-solve

Rules:
- `set_value(index, digit)` rejects givens, out-of-range indices and digits outside `1..digit_count`. It returns whether the board changed.
- `clear_value(index)` is the same as setting 0.
- A board is never left half updated. Invalid input is rejected before anything is written.

## Candidates

Candidates are bitmasks (`int`, where bit `d` means digit `d` is possible). Computing them for a cell means OR-ing the digits held by its peers, then inverting inside the digit range. The solver keeps its own candidate array. Player pencil marks, if added later, are a separate array on the game state, not on `Board`.

## Validator

- `conflicts(board) -> PackedInt32Array`: every cell that has the same digit as a peer
- `is_complete(board)`: no empty cells
- `is_solved(board)`: complete and no conflicts

## Solver

Deterministic: the same board always gives the same result, with no randomness.

1. Constraint propagation: naked singles, then hidden singles for each group.
2. Backtracking on the cell with the fewest candidates, trying digits in ascending order.
3. `count_solutions(board, limit)` stops early at `limit`. Uniqueness is checked with `limit = 2`.

The solver also reports stats (singles used, guesses made, maximum depth). The difficulty rater uses them.

## Generator

1. Build a solved board (the construction in game-rules.md for Tier 2, backtracking with a seeded shuffle for Tier 1).
2. Shuffle it with symmetries that keep it solved, using a seeded `RandomNumberGenerator`.
3. Remove givens in a seeded order. Keep a removal only if `count_solutions(limit = 2) == 1`.
4. Stop when the target clue count or difficulty is reached. Rate the result with the solver stats.

Every generated puzzle is checked with the solver before it's returned. With a seed, the output is reproducible, and the daily puzzle can use the date as its seed.

## Game state (outside the engine)

`GameState` (in `scripts/core/`) holds the board plus session data: selected cell, undo stack, elapsed time, mistakes and hints used. Undo is a stack of `{index, previous, next}` moves. It's never a board snapshot.
