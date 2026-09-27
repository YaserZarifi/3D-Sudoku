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
	"tutorial_done": false,
	"intro_seen": false,
}

const DAILY_KEY := "daily"
const SECONDS_PER_DAY := 86400


static func defaults() -> Dictionary:
	return {"settings": DEFAULT_SETTINGS.duplicate(), "stats": {}, "game": {}, "daily": empty_daily()}


static func empty_daily() -> Dictionary:
	return {"last_date": "", "streak": 0, "best_streak": 0}


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
	result["daily"] = sanitize_daily(data.get("daily"))
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


## Stats are {"<variant>/<difficulty>": {"played", "solved", "best_time",
## "total_time"}}. total_time sums solved games, for the average.
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
			"best_time": maxf(_float(entry.get("best_time")), 0.0),
			"total_time": maxf(_float(entry.get("total_time")), 0.0),
		}
	return stats


static func sanitize_daily(raw: Variant) -> Dictionary:
	var daily := empty_daily()
	if not raw is Dictionary:
		return daily
	var last: Variant = raw.get("last_date")
	if last is String and (last == "" or is_date(last)):
		daily["last_date"] = last
	daily["streak"] = maxi(_number(raw.get("streak")), 0)
	daily["best_streak"] = maxi(_number(raw.get("best_streak")), daily["streak"])
	return daily


static func record_start(stats: Dictionary, key: String) -> void:
	var entry: Dictionary = stats.get(key, _empty_entry())
	entry["played"] = int(entry["played"]) + 1
	stats[key] = entry


static func record_solve(stats: Dictionary, key: String, seconds: float) -> void:
	var entry: Dictionary = stats.get(key, _empty_entry())
	entry["solved"] = int(entry["solved"]) + 1
	entry["total_time"] = float(entry.get("total_time", 0.0)) + seconds
	var best := float(entry["best_time"])
	entry["best_time"] = seconds if best <= 0.0 else minf(best, seconds)
	stats[key] = entry


static func average_time(entry: Dictionary) -> float:
	var solved: int = entry.get("solved", 0)
	return float(entry.get("total_time", 0.0)) / solved if solved > 0 else 0.0


## Marks today's daily puzzle as solved and updates the streak. Solving on
## consecutive days grows the streak, a gap restarts it at 1.
static func record_daily(daily: Dictionary, today: String) -> void:
	var last: String = daily.get("last_date", "")
	if last == today:
		return
	var streak: int = daily.get("streak", 0)
	daily["streak"] = streak + 1 if last != "" and days_between(last, today) == 1 else 1
	daily["best_streak"] = maxi(int(daily.get("best_streak", 0)), int(daily["streak"]))
	daily["last_date"] = today


## The streak as it stands today: it's broken once a whole day is missed.
static func current_streak(daily: Dictionary, today: String) -> int:
	var last: String = daily.get("last_date", "")
	if last == "":
		return 0
	return int(daily.get("streak", 0)) if days_between(last, today) <= 1 else 0


static func solved_today(daily: Dictionary, today: String) -> bool:
	return daily.get("last_date", "") == today


## Every player gets the same daily puzzle, seeded by the date.
static func daily_seed(date: String) -> int:
	return int(date.replace("-", ""))


static func days_between(from_date: String, to_date: String) -> int:
	var start := Time.get_unix_time_from_datetime_string(from_date + "T00:00:00")
	var end := Time.get_unix_time_from_datetime_string(to_date + "T00:00:00")
	return int(round(float(end - start) / SECONDS_PER_DAY))


## YYYY-MM-DD in local time.
static func today() -> String:
	return Time.get_date_string_from_system()


static func is_date(text: String) -> bool:
	var parts := text.split("-")
	return parts.size() == 3 and parts[0].length() == 4 and parts[0].is_valid_int() \
		and parts[1].is_valid_int() and parts[2].is_valid_int()


static func _empty_entry() -> Dictionary:
	return {"played": 0, "solved": 0, "best_time": 0.0, "total_time": 0.0}


static func _float(value: Variant) -> float:
	return float(value) if value is int or value is float else 0.0


static func _number(value: Variant) -> int:
	if value is int or value is float:
		return int(value)
	return 0
