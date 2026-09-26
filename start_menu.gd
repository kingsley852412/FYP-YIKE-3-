extends Control

@onready var start_game_button: Button = $VBoxContainer/StartGameButton
@onready var exit_game_button: Button = $VBoxContainer/ExitGameButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AudioManager.play_music("Title_bgm", 0, true)
	start_game_button.pressed.connect(start_game)
	exit_game_button.pressed.connect(exit_game)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# use scene manager to goto level select menu
func start_game() -> void:
	AudioManager.play_click()
	SceneManager.goto_level_select()
	
# exit/close game
func exit_game() -> void:
	AudioManager.play_click()
	get_tree().quit()
