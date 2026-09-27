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
