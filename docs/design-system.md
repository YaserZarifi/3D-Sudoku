# Design system

This is a starting point, to be implemented as a Godot `Theme` resource plus a small `ThemeTokens` script in Milestones 5 and 6. Values are placeholders until they've been tried on a device. What matters now is that every visual value comes from a token, and nothing is hard-coded in scenes.

## Direction

Calm and tactile. A warm off-white background, a matte cube, one accent color. The cube is the only strong object on screen, and UI chrome stays quiet around it. Dark mode is a second token set, not a separate design.

## Color tokens

| Token | Light | Use |
|---|---|---|
| `bg` | #F1F0ED | Screen background |
| `surface` | #FFFFFF | Cards, number pad |
| `ink` | #1F2328 | Primary text, given digits |
| `ink_muted` | #6B6F76 | Secondary text |
| `cell` | #E8E6DF | Cell body |
| `accent` | #2F6FEB | Selection, entries |
| `peer` | accent at 18% | Peer highlight |
| `conflict` | #D64545 | Conflicts |
| `success` | #2E9E6A | Completion |

Contrast target: 4.5:1 for text and 3:1 for state outlines, checked in both themes.

## Typography

One sans family (to be picked; it needs clear tabular numerals, where 1 and 7 are easy to tell apart). Scale: 12, 14, 16, 20, 28, 40. Givens use a heavier weight than entries. Digit glyphs on the cube are rendered from the same font.

## Spacing and shape

- Spacing steps: 4, 8, 12, 16, 24, 32
- Corner radius: 8 for buttons, 12 for panels. Cells get a small bevel, not a round shape.
- Elevation: at most two levels, drawn with soft shadow on panels only

## Motion

| Token | Duration | Use |
|---|---|---|
| `fast` | 90 ms | Button press, digit pop |
| `base` | 160 ms | Selection, highlight changes |
| `slow` | 280 ms | Camera reset, slice focus, screen transitions |

Easing: ease-out cubic for anything that enters, ease-in-out for camera moves. With reduced motion on, durations are halved and shake and inertia are turned off.

## Haptics

| Level | Event |
|---|---|
| light | Select a cell, place a digit |
| medium | Conflict |
| success | Puzzle solved |

All haptics go through `HapticsManager`. It respects the setting and rate-limits so fast input can't cause constant buzzing.
