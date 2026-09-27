extends Node
## Autoload. Reads and writes user://save.json: settings, statistics and the
## active puzzle. Writes go to a temp file first, so a crash mid-write can't
## corrupt the save. A corrupt file is kept aside and replaced by defaults.

const SaveData := preload("res://scripts/core/save_data.gd")

const SAVE_PATH := "user://save.json"
const TEMP_PATH := "user://save.tmp"
const CORRUPT_PATH := "user://save.corrupt.json"

signal settings_changed

var data: Dictionary = SaveData.defaults()


func _ready() -> void:
	load_file()


func load_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		data = SaveData.defaults()
		return
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	if not SaveData.is_valid_text(text):
		push_warning("Save file was unreadable, starting fresh.")
		DirAccess.rename_absolute(SAVE_PATH, CORRUPT_PATH)
	data = SaveData.parse(text)


func save_file() -> void:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data))
	file.close()
	DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)


func get_setting(key: String) -> Variant:
	return data["settings"].get(key, SaveData.DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value: Variant) -> void:
	if data["settings"].get(key) == value:
		return
	data["settings"][key] = value
	save_file()
	settings_changed.emit()


func has_game() -> bool:
	return not (data["game"] as Dictionary).is_empty()


func get_game() -> Dictionary:
	return data["game"]


func store_game(game: Dictionary) -> void:
	data["game"] = game
	save_file()


func clear_game() -> void:
	data["game"] = {}
	save_file()


func stats() -> Dictionary:
	return data["stats"]


func record_start(key: String) -> void:
	SaveData.record_start(data["stats"], key)
	save_file()


func record_solve(key: String, seconds: float) -> void:
	SaveData.record_solve(data["stats"], key, seconds)
	save_file()
