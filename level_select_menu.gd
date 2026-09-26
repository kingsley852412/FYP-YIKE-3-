extends Control

@onready var grid: GridContainer = $VBoxContainer/GridContainer

@onready var back_button: Button = $VBoxContainer/BackButton

const LEVEL_COUNT: int = 10
const BUTTON_MIN_SIZE: Vector2 = Vector2(90, 45)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:	
	for level_num in range(1, LEVEL_COUNT + 1):
		var btn := Button.new()
		btn.text = "Level %d" % level_num
		btn.pressed.connect(SceneManager.goto_level.bind(level_num))
		btn.pressed.connect(func(): AudioManager.play_click())
		grid.add_child(btn)
		btn.custom_minimum_size = BUTTON_MIN_SIZE
		
	#connect back_button signal to "go to main menu" 
	back_button.pressed.connect(SceneManager.goto_start_menu)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func _on_back_button_pressed() -> void:
	AudioManager.play_click()
