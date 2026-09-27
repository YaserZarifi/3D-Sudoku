# Design system

Tokens live in `scripts/ui/theme_tokens.gd`. `ThemeManager` builds the Godot `Theme` from them at runtime, and the board reads the same palette for its materials. Values are placeholders until they've been tried on a device. What matters is that every visual value comes from a token, and nothing is hard-coded in scenes.

The canvas is 1080 pixels wide, so sizes given here in dp are multiplied by `UI_SCALE` (2.6) in code. A 56 dp button is about 146 canvas pixels, which lands near 56 dp on a typical phone.

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

Extra tokens: `axis_x`, `axis_y` and `axis_z` (red, green and purple) tie the slice buttons to the letters and outlines on the cube, `gold` tints cells holding the selected digit and colors confetti, and `hairline` and `shadow` style borders and panels.

Dark mode uses the `DARK` set in the same file, with the same token names.

Contrast target: 4.5:1 for text and 3:1 for state outlines, checked in both themes.

## Typography

Two families, both bundled in `assets/fonts/` under the SIL Open Font License:

- **Outfit** (variable, used at 500, 600 and 700) is the display face: titles, big numbers, primary buttons, the number pad and the digits on the cube. Large display text is tracked 2 px tighter.
- **Inter** (Regular, SemiBold, Bold) carries body text, captions and the timer. Tabular figures are on, so the timer never shifts.
- Small uppercase section labels (`OverlineLabel`) use Inter SemiBold tracked 3 px wider.

On the cube, givens use Outfit Bold in ink and entries Outfit Medium in the accent color. Same-digit matches get an outline in their own color. Digits scale with their cell and are corrected for their lift toward the camera, so they never spill past the cell. Scale: 12, 14, 16, 20, 28, 40, 56. Givens use a heavier weight than entries. Digit glyphs on the cube are rendered from the same font.

## Spacing and shape

- Spacing steps: 4, 8, 12, 16, 24, 32
- Corner radius: 14 for buttons, 22 for panels. Cells get a small bevel, not a round shape.
- Borders: a 1 dp hairline (`hairline` token) on light surfaces
- Elevation: at most two levels, drawn with soft shadow on panels only
- Press feedback: buttons shrink to 95% while held

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
