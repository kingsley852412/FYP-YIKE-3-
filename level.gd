extends Control

@onready var submit_button: Button = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/SubmitButton
@onready var game_map_scene: GameMapScene = $VBoxContainer/HBoxContainer/Panel/GameMapScene
@onready var code_text_edit: TextEdit = $VBoxContainer/HBoxContainer/VBoxContainer/CodeTextEdit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	submit_button.pressed.connect(
		func():
			game_map_scene.execute_code(code_text_edit.text)
	)
	game_map_scene.HintLabel = $VBoxContainer/HBoxContainer/VBoxContainer/HintLabel


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
