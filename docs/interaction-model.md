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

## Tutorial

A coach card sits at the top of the board area and the cube frames itself below it. Steps: turn the cube, select a cell, place a fitting digit (a wrong one gets a gentle retry message), try slice view, turn on Notes, then finish the cube. Skip ends it at any point. It's offered as the main action on the menu until it's been finished or skipped once.

## Menu

Continue is the main action when a game is saved. Below it: tier and level choice, New Game, then Daily, Stats, How to play and Settings. Stats and Settings open as sheets. The Android back button closes an open sheet, then leaves the app.

## Keyboard (desktop testing)

1 to 9 enter digits, Backspace or Delete erases, Ctrl+Z undoes, N toggles notes, R resets the view. A mouse drag orbits and the wheel zooms, because mouse input is emulated as touch.
