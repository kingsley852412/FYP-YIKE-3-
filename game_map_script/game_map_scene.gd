class_name GameMapScene
extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func level_reset() -> void:
	assert(false, "Error, game_map_scene.gd level_reset(), not implemented by subclass yet")

func execute_code(code_text: String) -> void:
	assert(false, "Error, game_map_scene.gd execute_code(), not implemented by subclass yet")

func refresh_hint() -> void:
	assert(false, "Error, game_map_scene.gd label_node(), not implemented by subclass yet")
