extends Node

signal scene_changed

# anything you want to remember across scene changes
var selected_level: int = 1

const LEVEL_PATHS := {
	1: "res://game_map_scenes/game_map_scene_level1.tscn",
	
	#2: "res://game_map_scenes/game_map_scene_level2.tscn",
	#3: "res://game_map_scenes/game_map_scene_level3.tscn",
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func goto(path: String) -> void:
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	scene_changed.emit()

func goto_level(level_number: int) -> void:
	selected_level = level_number
	var path: String = LEVEL_PATHS.get(level_number, "")
	assert(path != "", "No scene registered for level %d" % level_number)
	goto(path)

func goto_main_menu() -> void:
	goto("res://ui/main_menu.tscn")

func goto_level_select() -> void:
	goto("res://ui/level_select.tscn")
