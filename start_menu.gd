extends Control

@onready var start_game_button: Button = $VBoxContainer/StartGameButton
@onready var exit_game_button: Button = $VBoxContainer/ExitGameButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AudioManager.play_music("Title_bgm", 0, true)
	start_game_button.pressed.connect(start_game)
	exit_game_button.pressed.connect(exit_game)
	settings_button.pressed.connect(settings)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# use scene manager to goto level select menu
func start_game() -> void:
	SceneManager.goto_level_select()
	
# exit/close game
func exit_game() -> void:
	get_tree().quit()

func settings() -> void:
	SceneManager.goto_settings()
	
func _on_settings_button_pressed() -> void:
	AudioManager.play_click();

func _on_start_game_button_pressed() -> void:
	AudioManager.play_click();
