extends "res://tests/test_case.gd"

const SaveData := preload("res://scripts/core/save_data.gd")


func test_garbage_falls_back_to_defaults() -> void:
	for text in ["", "{not json", "[1, 2]", "42", "null"]:
		var data := SaveData.parse(text)
		assert_eq(data["settings"], SaveData.DEFAULT_SETTINGS, text)
		assert_eq(data["stats"], {})
		assert_eq(data["game"], {})


func test_settings_keep_valid_values_only() -> void:
	var data := SaveData.parse(JSON.stringify({"settings": {"sound": false, "haptics": "yes", "extra": 1}}))
	assert_eq(data["settings"]["sound"], false)
	assert_eq(data["settings"]["haptics"], true)
	assert_false(data["settings"].has("extra"))


func test_stats_are_sanitized() -> void:
	var raw := {"stats": {"a/easy": {"played": 3, "solved": -2, "best_time": "x"}, "b": 5}}
	var stats: Dictionary = SaveData.parse(JSON.stringify(raw))["stats"]
	assert_eq(stats.keys(), ["a/easy"])
	assert_eq(stats["a/easy"]["played"], 3)
	assert_eq(stats["a/easy"]["solved"], 0)
	assert_eq(stats["a/easy"]["best_time"], 0.0)


func test_record_keeps_best_time() -> void:
	var stats := {}
	SaveData.record_start(stats, "k")
	SaveData.record_solve(stats, "k", 90.0)
	SaveData.record_solve(stats, "k", 120.0)
	SaveData.record_solve(stats, "k", 60.0)
	assert_eq(stats["k"]["played"], 1)
	assert_eq(stats["k"]["solved"], 3)
	assert_eq(stats["k"]["best_time"], 60.0)


func test_average_time() -> void:
	var stats := {}
	SaveData.record_solve(stats, "k", 60.0)
	SaveData.record_solve(stats, "k", 120.0)
	assert_eq(SaveData.average_time(stats["k"]), 90.0)
	assert_eq(SaveData.average_time({}), 0.0)


func test_daily_streak_grows_on_consecutive_days() -> void:
	var daily := SaveData.empty_daily()
	SaveData.record_daily(daily, "2026-09-26")
	SaveData.record_daily(daily, "2026-09-27")
	SaveData.record_daily(daily, "2026-09-27")
	assert_eq(daily["streak"], 2)
	SaveData.record_daily(daily, "2026-09-30")
	assert_eq(daily["streak"], 1)
	assert_eq(daily["best_streak"], 2)


func test_streak_crosses_month_and_year() -> void:
	var daily := SaveData.empty_daily()
	SaveData.record_daily(daily, "2026-12-31")
	SaveData.record_daily(daily, "2027-01-01")
	assert_eq(daily["streak"], 2)


func test_current_streak_breaks_after_a_missed_day() -> void:
	var daily := {"last_date": "2026-09-25", "streak": 4, "best_streak": 4}
	assert_eq(SaveData.current_streak(daily, "2026-09-25"), 4)
	assert_eq(SaveData.current_streak(daily, "2026-09-26"), 4)
	assert_eq(SaveData.current_streak(daily, "2026-09-27"), 0)
	assert_true(SaveData.solved_today(daily, "2026-09-25"))


func test_daily_seed_is_stable() -> void:
	assert_eq(SaveData.daily_seed("2026-09-27"), 20260927)


func test_daily_sanitized() -> void:
	var data := SaveData.parse(JSON.stringify({"daily": {"last_date": "garbage", "streak": 3, "best_streak": 1}}))
	assert_eq(data["daily"]["last_date"], "")
	assert_eq(data["daily"]["best_streak"], 3)
