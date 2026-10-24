extends Node

@onready var back_button: Button = $VBoxContainer/BackButton

@onready var musicVolume: HSlider = $VBoxContainer/VBoxContainer/HBoxContainer/musicSlider

@onready var seVolume: HSlider = $VBoxContainer/VBoxContainer/HBoxContainer2/seSlider




# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	back_button.pressed.connect(SceneManager.goto_start_menu)
	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_back_button_pressed() -> void:
	AudioManager.play_click()
