## The main gameplay screen.
##
## Owns the UI (code editor, buttons, hint label) and hosts a single
## [GameMapScene] inside [member panel].
## All player interaction with the level flows through this script:
## button presses are wired to [GameMapScene] methods here.
##
## Responsibilities:
## [br]- Instantiate the level scene and embed it in [member panel].
## [br]- Pass [member hint_label] to the level (gameMapScene) via [method GameMapScene.setup].
## [br]- Wire Submit / Reset / Hint buttons to the level's methods.
## [br]- Lock the Submit and Reset buttons while code is executing.
extends Control

## title label of this level
@onready var title_label: Label = %TitleLabel

## Runs the player's code. Disabled during execution to prevent double-submit.
@onready var submit_button: Button = %SubmitButton

## Resets the level to its starting state. Disabled during execution.
@onready var reset_button: Button = %ResetButton

## reset code entry box's content to default text
@onready var reset_code_button: Button = %ResetCodeButton


## Shows the next hint in the level's hint list.
@onready var hint_button: Button = %HintButton
@onready var stop_button: Button = %StopButton
@onready var output_text: TextEdit = %OutputText

@onready var exit_button: Button = %ExitButton

## The embedded level instance. Created in [method _ready]; do not access before then.
@onready var game_map_scene: GameMapScene

## The player's code input box.
@onready var code_text_edit: TextEdit = %CodeTextEdit

## Placeholder container that reserves screen space for the level scene.
## The level is added as its child, so the Panel's layout determines where the level appears.
@onready var panel: Panel = %Panel

## Displays hints and code-error / status messages.
## Passed to the level via [method GameMapScene.setup].
@onready var hint_label: Label = %HintLabel

@onready var confirm_modal: ConfirmationModal = %ConfirmationModal

const LEVEL_PATHS := {
	1: "res://game_map_scenes/game_map_scene_level1.tscn",
	
	#2: "res://game_map_scenes/game_map_scene_level2.tscn",
	#3: "res://game_map_scenes/game_map_scene_level3.tscn",
}

const LEVEL_SCRIPT_PATHS: Dictionary = {
	1: "res://game_map_script/game_map_scene_level_1.gd",
	
}

## default text in code entry box for each level
const DEFAULT_CODE_TEXT: Dictionary = {
	1: "for i in range(5):
    robot.move_right()

robot.move_down(4)
robot.rescue()
print(robot.position)",
	
}

## Builds the level UI: instantiates the level scene, embeds it, and connects
## the three buttons.
##
## Order matters:
## [br]1. Instantiate the level's [code].tscn[/code] (its root already carries the level script).
## [br]2. [method Node.add_child] into [member panel] — this triggers the level's [code]_ready[/code]
##    and resolves its @onready variables.
## [br]3. Call [method GameMapScene.setup] with parameter [member hint_label].
## [br]4. Connect the buttons.
func _ready() -> void:
	var current_level: int = SceneManager.selected_level
	
	# make an instance of level1 gameMapScene, set its script, 
	# so that it knows its a gameMapScene class, otherwise casting as gameMapScene will FAIL
	var scene_path = LEVEL_PATHS.get(current_level, "")
	var script_path = LEVEL_SCRIPT_PATHS.get(current_level, "")
	
	assert(scene_path != "", ".tscn not found in LEVEL_PATH")
	assert(script_path != "", ".gd not found in LEVEL_PATH")
	
	var inst : Node = load(scene_path).instantiate()
	inst.set_script(load(script_path))
	
	# set up the GameMapScene node
	game_map_scene = inst as GameMapScene
	panel.add_child(game_map_scene)

	game_map_scene.setup(hint_label)
	game_map_scene.level_completed.connect(confirm_modal.show)
	game_map_scene.execution_state_changed.connect(_on_execution_state_changed)
	game_map_scene.code_output.connect(_on_code_output)
	game_map_scene.code_error.connect(_on_code_error)
	game_map_scene.warning_raised.connect(_on_warning_raised)
	
	stop_button.disabled = true
	stop_button.pressed.connect(game_map_scene.stop_code)

	# initializing code input box to default text content
	reset_code_input(current_level)

	## Submit handler.
	## Resets the level, runs the player's code, and locks Submit + Reset for
	## the full duration of execution (including all awaited movement steps).
	## [code]await[/code] is required: [method GameMapScene.execute_code] is a
	## coroutine and returns at its first internal [code]await[/code].
	##
	## without await, while game_map_scene.execute_code(code_text_edit.text) is awaiting, the buttons will be enabled too soon (unintended
	submit_button.pressed.connect(
		func():
			game_map_scene.level_reset()
			output_text.text = ""
			code_text_edit.deselect()
			game_map_scene.execute_code(code_text_edit.text)
	)
	
	## Reset handler. Restores the level to its start state.
	reset_button.pressed.connect(
		game_map_scene.level_reset
	)
	
	reset_code_button.pressed.connect(
		reset_code_input.bind(SceneManager.selected_level)
	)
	
	## Hint handler. Cycles the level's hint list and shows the next hint entry.
	hint_button.pressed.connect(
		game_map_scene.refresh_hint
	)
	
	exit_button.pressed.connect(SceneManager.goto_level_select)
	
	confirm_modal.confirmed.connect(_on_confirmation_modal_confirmed)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_execution_state_changed(running: bool) -> void:
	submit_button.disabled = running
	reset_button.disabled = running
	reset_code_button.disabled = running
	stop_button.disabled = not running
	code_text_edit.editable = not running

func _on_code_output(text: String) -> void:
	output_text.text += text
	output_text.set_caret_line(output_text.get_line_count() - 1)

func _on_code_error(line: int) -> void:
	if line > 0 and line <= code_text_edit.get_line_count():
		code_text_edit.select(line - 1, 0, line - 1, code_text_edit.get_line(line - 1).length())
		code_text_edit.set_caret_line(line - 1)

func reset_code_input(selected_level: int) -> void:
	AudioManager.play_click()
	var default_code: String = DEFAULT_CODE_TEXT.get(selected_level, "")
	assert(default_code != "", "default code not defined, or empty")
	
	code_text_edit.text = default_code

func _on_confirmation_modal_confirmed(is_confirmed: bool) -> void:
	if is_confirmed:
		AudioManager.play_click()
		SceneManager.goto_level(SceneManager.selected_level + 1)
	else:
		AudioManager.play_click()
		confirm_modal.hide()


func _on_submit_button_pressed() -> void:
	AudioManager.play_click()


func _on_reset_button_pressed() -> void:
	AudioManager.play_click()


func _on_exit_button_pressed() -> void:
	AudioManager.play_click()
## this function is **NOT** for code compiler error in PYTHON
## this is for changing content of Hint Label in "Level"
## when player bumped into wall
## or other possible warnings in future levels
## e.g. failed boss fights/ caught by enemies/ etc.
func _on_warning_raised(message: String) -> void:
	hint_label.text = message
