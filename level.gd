extends Control

#button for submitted code for execution/reset level/hint refreshing
@onready var submit_button: Button = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/SubmitButton
@onready var reset_button: Button = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/ResetButton
@onready var hint_button: Button = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/HintButton

# variable referring to the game_map_scene, can call its function to execute code/refresh hint/reset level
@onready var game_map_scene: GameMapScene

# var, refers to the text input box for user to input code
@onready var code_text_edit: TextEdit = $VBoxContainer/HBoxContainer/VBoxContainer/CodeTextEdit

# var, refers to the panel in the UI the panel is a placeholder
# to reserve UI space to put the game_map_scene 
@onready var panel: Panel = $VBoxContainer/HBoxContainer/Panel

# this labels shows hints, and error messages/code result message
@onready var hint_label: Label = $VBoxContainer/HBoxContainer/VBoxContainer/HintLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	# make an instance of level1 gameMapScene, set its script, 
	# so that it knows its a gameMapScene class, otherwise casting as gameMapScene will FAIL
	var inst : Node = load("res://game_map_scenes/game_map_scene_level1.tscn").instantiate()
	inst.set_script(load("res://game_map_script/game_map_scene_level_1.gd"))
	
	# initiating the GameMapScene node
	game_map_scene = inst as GameMapScene
	
	panel.add_child(game_map_scene)

	game_map_scene.setup(hint_label)

	submit_button.pressed.connect(
		func():
			game_map_scene.execute_code(code_text_edit.text)
	)
	
	reset_button.pressed.connect(
		game_map_scene.level_reset
	)
	
	hint_button.pressed.connect(
		game_map_scene.refresh_hint
	)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
