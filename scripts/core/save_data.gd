extends RefCounted
## Shape of the save file and the rules for reading it back. Anything
## missing, of the wrong type or unparsable falls back to defaults.

const DEFAULT_SETTINGS := {
	"sound": true,
	"haptics": true,
	"reduced_motion": false,
	"dark_mode": false,
	"last_variant": "slice_sudoku_3",
	"last_difficulty": "easy",
}


static func defaults() -> Dictionary:
	return {"settings": DEFAULT_SETTINGS.duplicate(), "stats": {}, "game": {}}


## Parses save text. Returns defaults when the text isn't a valid save.
static func parse(text: String) -> Dictionary:
	var result := defaults()
	var json := JSON.new()
	if text.strip_edges() == "" or json.parse(text) != OK or not json.data is Dictionary:
		return result
	var data: Dictionary = json.data
	result["settings"] = sanitize_settings(data.get("settings"))
	result["stats"] = sanitize_stats(data.get("stats"))
	var game: Variant = data.get("game")
	result["game"] = game if game is Dictionary else {}
	return result


static func is_valid_text(text: String) -> bool:
	var json := JSON.new()
	return json.parse(text) == OK and json.data is Dictionary


static func sanitize_settings(raw: Variant) -> Dictionary:
	var settings := DEFAULT_SETTINGS.duplicate()
	if not raw is Dictionary:
		return settings
	for key: String in DEFAULT_SETTINGS:
		var value: Variant = raw.get(key)
		if value != null and typeof(value) == typeof(DEFAULT_SETTINGS[key]):
			settings[key] = value
	return settings


## Stats are {"<variant>/<difficulty>": {"played", "solved", "best_time"}}.
static func sanitize_stats(raw: Variant) -> Dictionary:
	var stats := {}
	if not raw is Dictionary:
		return stats
	for key: Variant in raw:
		var entry: Variant = raw[key]
		if not key is String or not entry is Dictionary:
			continue
		stats[key] = {
			"played": maxi(_number(entry.get("played")), 0),
			"solved": maxi(_number(entry.get("solved")), 0),
			"best_time": maxf(float(_number(entry.get("best_time"))), 0.0),
		}
	return stats


static func record_start(stats: Dictionary, key: String) -> void:
	var entry: Dictionary = stats.get(key, {"played": 0, "solved": 0, "best_time": 0.0})
	entry["played"] = int(entry["played"]) + 1
	stats[key] = entry


static func record_solve(stats: Dictionary, key: String, seconds: float) -> void:
	var entry: Dictionary = stats.get(key, {"played": 0, "solved": 0, "best_time": 0.0})
	entry["solved"] = int(entry["solved"]) + 1
	var best := float(entry["best_time"])
	entry["best_time"] = seconds if best <= 0.0 else minf(best, seconds)
	stats[key] = entry


static func _number(value: Variant) -> int:
	if value is int or value is float:
		return int(value)
	return 0
