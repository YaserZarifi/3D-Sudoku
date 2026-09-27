# Interaction model

The game runs in portrait only. A cube reads well in a tall frame, and one-handed play with the thumb near the number pad matters more than extra width.

## Layout (portrait)

```
┌──────────────────────┐
│ ⏸  Tier · 04:12   ↶ │  HUD: pause, puzzle info, undo    (~8%)
│                      │
│                      │
│       [ cube ]       │  3D board                         (~62%)
│                      │
│  ○ x  ○ y  ○ z  ⟲    │  slice controls, reset view       (~6%)
├──────────────────────┤
│  1   2   3           │
│  4   5   6     ⌫     │  number pad + erase               (~24%)
│  7   8   9           │
└──────────────────────┘
```

Tier 1 shows only 1, 2 and 3, as larger buttons. Everything stays inside the safe area.

## Gestures on the board

| Gesture | Result |
|---|---|
| Tap a cell (moves less than the tap threshold, ~12 px at 160 dpi, scaled by screen density) | Select that cell |
| Tap empty space | Deselect |
| One-finger drag | Orbit the cube. Yaw is free, pitch is clamped to about ±70° so the cube can't flip |
| Release after a fast drag | Short inertia with strong damping |
| Pinch | Zoom between set min and max distance |
| Double-tap empty space | Animate back to the default view |

A touch becomes a drag once it moves past the threshold, and then it can't select anything. Touches that start on UI controls never reach the board.

## Readability of the inside

In a 3 × 3 × 3 cube, 26 cells are on the surface and one sits in the middle. Built in Milestone 3:

- **Slice focus:** tap X, Y or Z to show one slice at a time, with the other cells dimmed, shrunk and not selectable. Tap the same button again to move to the next slice; after the last one, focus turns off. The button shows which slice is showing, for example "Z 2/3". This is the main way to reach the middle cell and read a full slice.
- **Exploded spacing:** gaps between cells so every cell is visible from most angles. The gap grows a little while dragging.
- **Selection assist:** selecting a cell lights up its peers (outline, not color alone). If other cells hide the selected cell, the camera turns around the vertical axis by at most about 20°. It never snaps and never changes pitch.

## Feedback per state

Every state has a non-color cue as well.

| State | Cue |
|---|---|
| Selected | Raised cell, thick outline, color |
| Peer | Thin outline, light tint |
| Same digit | Digit in bold |
| Conflict | Red tint plus a small corner mark, and a short shake when the digit is placed |
| Given | Heavier digit weight, no fill change on selection |
| Dimmed (outside the focused slice) | Lower opacity and smaller scale |

Placing a digit gives a light haptic tap and a short scale pop. A conflict gives a sharper haptic and the shake. Sound follows the same events and can be turned off separately.

## Number pad

- Buttons are at least 56 dp. Presses show immediately on touch down.
- When every copy of a digit is on the board (3 per digit in Tier 2, 9 in Tier 1), its button fades but stays usable.
- Erase clears the selected entry. Undo reverts the last move, including erases.
- Hint fills the selected cell from the solution, or the first wrong or empty cell when nothing useful is selected. Hints are counted on the result screen.

## Pencil marks

Notes sits between Erase and Hint. While it's on, digit buttons toggle small candidates in the selected empty cell instead of placing a digit, and the pad shows lighter digits so the mode is obvious. The pad highlights the selected cell's entry, or its notes in notes mode. Notes are laid out in a fixed grid (1 2 3 on the top row), so a digit is always in the same spot. Erase on an empty cell clears its notes.

## First launch

Four swipeable intro cards, drawn in code as isometric cubes: what the game is, the slice rule (with X, Y and Z slices in their axis colors), turn and tap, and seeing inside. The last card offers "Try a practice cube". Skip goes to the menu. How to play on the menu shows the cards again.

## Practice tutorial

A tip banner sits at the top of the board area and the cube frames itself below it. Steps: turn the cube, select a cell, place a fitting digit (a wrong one gets a gentle retry message), try slice view, turn on Notes, try Hint, then finish the cube. Skip ends it at any point.

## Hints that teach

The first tap on Hint selects a cell and explains why, in the tip banner, without changing the board: a wrong entry ("This 7 doesn't match the solution"), a naked single ("Only 5 fits here"), a hidden single ("5 has only one spot left in this Z slice", which also switches slice view to that slice), or, if nothing simple exists, a plain reveal. Tapping Hint again, or Fill in on the banner, carries it out. Any other move dismisses it.

## Menu

Home has one main action: Play, or Continue when a game is saved (with New puzzle under it). Then a Daily puzzle card with the streak, and three small links: How to play, Stats and Settings. Play opens "Choose a puzzle": two tier cards that say what each tier is, a difficulty row and Start. Stats and Settings open as sheets. Android back closes a sheet, then the picker, then leaves the app.

## Reading the cube

- Letters X, Y and Z float past the cube's front edges in the same colors as the dots on the slice buttons.
- Cells in the focused slice get an outline in that axis color. Other cells shrink and fade further than before.
- Cells holding the same digit as the selected one get a warm tint as well as the heavier digit.
- A puzzle starts with the cells growing in from the center, and a solve ends with confetti.

## Number pad and HUD

Each pad digit shows how many are still missing in its corner, and fades when none are. The HUD title adds the mistake count once there is one. The win screen shows the time large, a "New best time" badge when it is one, mistakes, hints, best time and the daily streak, then Next puzzle.

## Keyboard (desktop testing)

1 to 9 enter digits, Backspace or Delete erases, Ctrl+Z undoes, N toggles notes, R resets the view. A mouse drag orbits and the wheel zooms, because mouse input is emulated as touch.
