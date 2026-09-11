extends Control

@onready var grid: GridContainer = $VBoxContainer/GridContainer

const LEVEL_COUNT: int = 10
const BUTTON_MIN_SIZE: Vector2 = Vector2(90, 45)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:	
	for level_num in range(1, LEVEL_COUNT + 1):
		var btn := Button.new()
		btn.text = "Level %d" % level_num
		btn.pressed.connect(_on_level_pressed.bind(level_num))
		grid.add_child(btn)
		btn.custom_minimum_size = BUTTON_MIN_SIZE

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_level_pressed(level_num: int) -> void:
	SceneManager.goto_level(level_num)

func _on_back_pressed() -> void:
	SceneManager.goto_main_menu()
