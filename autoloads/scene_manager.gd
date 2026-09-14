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



func _goto(path: String) -> void:
	var err: int = get_tree().change_scene_to_file(path)
	assert(err == OK, "SceneManager.goto: failed to change scene to '%s' (error %d)" % [path, err])
	
	# wait until current scene code all ended to switch to new scene, avoid error
	await get_tree().process_frame
	
	#emit signal for other objects to do things
	scene_changed.emit()

func goto_level(level_number: int) -> void:
	selected_level = level_number
	_goto("res://level.tscn")

func goto_start_menu() -> void:
	_goto("res://start_menu.tscn")

func goto_level_select() -> void:
	_goto("res://level_select_menu.tscn")
