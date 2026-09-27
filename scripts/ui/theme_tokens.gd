extends RefCounted
## Every visual value in the game comes from here (see docs/design-system.md).
## Scenes and scripts read tokens instead of hard-coding colors or sizes.

const LIGHT := {
	"bg": Color("#F1F0ED"),
	"surface": Color("#FFFFFF"),
	"surface_pressed": Color("#E4E7EC"),
	"hairline": Color("#1F2328", 0.08),
	"shadow": Color("#1F2328", 0.10),
	"ink": Color("#1F2328"),
	"ink_muted": Color("#6B6F76"),
	"cell": Color("#E8E6DF"),
	"cell_given": Color("#DAD7CD"),
	"accent": Color("#2F6FEB"),
	"accent_ink": Color("#FFFFFF"),
	"peer": Color("#2F6FEB", 0.12),
	"conflict": Color("#D64545"),
	"success": Color("#2E9E6A"),
	"scrim": Color(0.12, 0.13, 0.16, 0.45),
}

const DARK := {
	"bg": Color("#16181C"),
	"surface": Color("#23262C"),
	"surface_pressed": Color("#2F333B"),
	"hairline": Color("#FFFFFF", 0.07),
	"shadow": Color("#000000", 0.35),
	"ink": Color("#ECEDEF"),
	"ink_muted": Color("#9BA0A8"),
	"cell": Color("#3A3E46"),
	"cell_given": Color("#2C2F35"),
	"accent": Color("#5B8FF5"),
	"accent_ink": Color("#FFFFFF"),
	"peer": Color("#5B8FF5", 0.16),
	"conflict": Color("#EF6666"),
	"success": Color("#4CC38A"),
	"scrim": Color(0.0, 0.0, 0.0, 0.55),
}

const FONT_SIZES := {"xs": 12, "sm": 14, "md": 16, "lg": 20, "xl": 28, "xxl": 40}
## The canvas is 1080 wide, so UI sizes are scaled up from the dp values in the docs.
const UI_SCALE := 2.6

const SPACE := [4, 8, 12, 16, 24, 32]
const RADIUS_BUTTON := 14
const RADIUS_PANEL := 22
const HAIRLINE_DP := 1.0
const SHADOW_DP := 14
const MIN_BUTTON_DP := 56

const MOTION_FAST := 0.09
const MOTION_BASE := 0.16
const MOTION_SLOW := 0.28
## Buttons shrink to this scale while pressed.
const PRESS_SCALE := 0.95

const FONT_REGULAR := "res://assets/fonts/Inter-Regular.woff2"
const FONT_SEMIBOLD := "res://assets/fonts/Inter-SemiBold.woff2"
const FONT_BOLD := "res://assets/fonts/Inter-Bold.woff2"

## Board geometry, in world units.
const CELL_SIZE := 0.82
const CELL_SPACING := 1.25
const CELL_SPACING_DRAG := 1.4
const CELL_BEVEL := 0.08
const SELECTED_SCALE := 1.1
const DIMMED_SCALE := 0.55
const DIMMED_ALPHA := 0.22
const OUTLINE_SELECTED := 1.14
const OUTLINE_PEER := 1.07
const DIGIT_FONT_SIZE := 128
const DIGIT_PIXEL_SIZE := 0.0034
const DIGIT_BOLD_OUTLINE := 14
const CELL_ROUGHNESS := 0.85


static func palette(dark: bool) -> Dictionary:
	return DARK if dark else LIGHT


static func font_size(name: String) -> int:
	return int(round(FONT_SIZES[name] * UI_SCALE))


static func space(step: int) -> int:
	return int(round(SPACE[step] * UI_SCALE))


static func dp(value: float) -> int:
	return int(round(value * UI_SCALE))


## Durations shrink when reduced motion is on.
static func motion(duration: float, reduced: bool) -> float:
	return duration * 0.5 if reduced else duration

## Scene lighting.
const KEY_LIGHT_ENERGY := 0.75
const FILL_LIGHT_ENERGY := 0.3
const AMBIENT_ENERGY := 0.35
## Seconds to wait after the last cell animates before showing the result.
const SOLVED_PANEL_DELAY := 0.9
## Turns per second of the celebration spin.
const SOLVED_SPIN_SPEED := 0.12
const SOLVED_WAVE_STEP := 0.025
