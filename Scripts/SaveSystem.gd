extends Node

const SAVE_FILE_PATH := "user://space_progression.save"

var max_unlocked_mission: int = 0
var selected_start_mission: int = 0

func _ready() -> void:
	load_progress()

func save_progress() -> void:
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(max_unlocked_mission)

func load_progress() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		if file:
			max_unlocked_mission = file.get_32()

func unlock_mission(index: int) -> void:
	if index > max_unlocked_mission:
		max_unlocked_mission = index
		save_progress()

func reset_progress() -> void:
	max_unlocked_mission = 0
	selected_start_mission = 0
	save_progress()
