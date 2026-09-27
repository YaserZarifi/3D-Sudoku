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

In a 3 × 3 × 3 cube, 26 cells are on the surface and one sits in the middle. Planned tools, to be tested in Milestone 3:

- **Slice focus:** tap x, y or z to show one slice at a time, with the other cells dimmed and shrunk. Swipe on the slice bar, or tap again, to move to the next slice. This is the main way to read the middle cell and the full slice constraint.
- **Exploded spacing:** gaps between cells so every cell is visible from most angles. The gap grows a little while dragging.
- **Selection assist:** selecting a cell lights up its peers (outline, not color alone). The camera eases just enough to keep the selected cell from being hidden, and never snaps.

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
