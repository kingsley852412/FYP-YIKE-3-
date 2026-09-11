extends Node

signal scene_changed

# anything you want to remember across scene changes
var selected_level: int = 1

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
	goto("res://level.tscn")

func goto_main_menu() -> void:
	goto("res://main_menu.tscn")

func goto_level_select() -> void:
	goto("res://level_select.tscn")
