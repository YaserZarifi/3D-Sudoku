extends Node
## Autoload. Every vibration goes through here so the setting is respected
## and fast input can't turn into constant buzzing.

const MIN_INTERVAL_MS := 60
const PATTERNS := {
	"light": {"ms": 12, "amplitude": 0.35},
	"medium": {"ms": 28, "amplitude": 0.7},
	"success": {"ms": 60, "amplitude": 0.9},
}

var _last_ms := -MIN_INTERVAL_MS


func play(level: String) -> void:
	if not SaveManager.get_setting("haptics") or not PATTERNS.has(level):
		return
	var now := Time.get_ticks_msec()
	if now - _last_ms < MIN_INTERVAL_MS:
		return
	_last_ms = now
	var pattern: Dictionary = PATTERNS[level]
	Input.vibrate_handheld(pattern["ms"], pattern["amplitude"])
