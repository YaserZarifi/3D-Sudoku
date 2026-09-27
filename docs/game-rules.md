# Game rules

The game is built from puzzle **tiers**. Each tier is one rule set. The engine treats every tier the same way: it's a set of cells, a range of digits, and a list of **constraint groups**. A group is a set of cells that must not repeat a digit. Adding a tier means writing a new definition, not new solver logic.

## Coordinates

A cube of size N has N × N × N cells. Each cell is addressed as `(x, y, z)` with every component in `0 .. N-1`.

- `x` runs left to right
- `y` runs bottom to top
- `z` runs back to front

These are logical coordinates. The 3D board decides how they map to world space, and the engine never sees world positions.

A **line** is N cells that share two coordinates, for example every cell with `y = 1, z = 2`. A **slice** is N × N cells that share one coordinate, for example every cell with `z = 0`.

## Shared definitions

These apply to every tier.

- **Given:** a clue placed by the puzzle. The player can't change it.
- **Entry:** a digit placed by the player. It can be changed or erased.
- **Empty:** a cell with no digit. Empty cells never conflict.
- **Peers:** all other cells that share at least one constraint group with a cell.
- **Conflict:** two cells in the same group hold the same digit. Both cells are marked. A given can be part of a conflict, but it's never the cell that gets blamed. The entry is always what's marked as wrong.
- **Solved:** every cell holds a digit and there are no conflicts.
- **Valid puzzle:** the givens have exactly one completion that satisfies all groups. The generator must prove this with the solver before handing out a puzzle.

Conflicts are checked against the rules, not against the stored solution. Placing a digit that doesn't break any rule but differs from the solution isn't flagged as a conflict. An optional "check against solution" assist can be added later as a hint feature.

## Tier 1: Latin Cube

Intro and tutorial tier.

| | |
|---|---|
| Size | 3 × 3 × 3 (27 cells) |
| Digits | 1, 2, 3 |
| Groups | Every line along x, y and z. 9 lines per axis, 27 groups in total, 3 cells each |
| Peers per cell | 6 (2 on each of its 3 lines) |

Each line holds 1, 2 and 3 exactly once. Slices don't need to hold anything in particular. Each slice ends up as a 3 × 3 Latin square, because its rows and columns are lines.

This tier is small on purpose. It teaches rotating the cube, selecting cells and reading lines in depth, without the difficulty of the main game.

## Tier 2: Slice Sudoku

Main game.

| | |
|---|---|
| Size | 3 × 3 × 3 (27 cells) |
| Digits | 1 to 9 |
| Groups | Every slice along x, y and z. 3 per axis, 9 groups in total, 9 cells each |
| Peers per cell | 18 (every cell that shares its x, its y or its z) |

Each slice holds 1 to 9 exactly once. Every line lies inside a slice, so no line repeats a digit either. That falls out of the slice rule and doesn't need a separate group.

Every digit appears exactly 3 times in a solved cube, once in each x slice, each y slice and each z slice. So the three cells holding a given digit never share a coordinate.

**Solutions exist.** For each pair `(s, t)` with `s, t` in `0..2`, the three cells `(i, (i + s) mod 3, (i + t) mod 3)` for `i = 0, 1, 2` never share a coordinate. The 9 pairs split the 27 cells into 9 disjoint triples. Give each triple its own digit and you get a solved cube. The generator starts from a construction like this, then shuffles it by permuting digits, permuting each axis and swapping axes (all of these keep the board solved), then removes givens.

**Things to confirm during Milestone 2:**
- How many givens it takes to get a unique solution at each difficulty.
- Whether any puzzles need guessing (backtracking) rather than pure deduction. Those should be rated Expert or thrown away.

## Tier 3 and later (not built yet)

Candidates, to be decided after Tier 2 has been tested on a device:
- **4 × 4 × 4, digits 1 to 16, slice rule.** Same structure as Tier 2, but 16 digits needs a bigger number pad.
- **4 × 4 × 4, digits 1 to 4, lines plus 2 × 2 boxes in every slice.** Each slice is a small 4 × 4 Sudoku.

Any new tier has to be defined here, with the same tables, before any code is written for it.
