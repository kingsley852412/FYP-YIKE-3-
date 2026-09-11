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

## Runs the player's code. Disabled during execution to prevent double-submit.
@onready var submit_button: Button = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/SubmitButton

## Resets the level to its starting state. Disabled during execution.
@onready var reset_button: Button = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/ResetButton

## Shows the next hint in the level's hint list.
@onready var hint_button: Button = $VBoxContainer/HBoxContainer/VBoxContainer/HBoxContainer/HintButton

## The embedded level instance. Created in [method _ready]; do not access before then.
@onready var game_map_scene: GameMapScene

## The player's code input box.
@onready var code_text_edit: TextEdit = $VBoxContainer/HBoxContainer/VBoxContainer/CodeTextEdit

## Placeholder container that reserves screen space for the level scene.
## The level is added as its child, so the Panel's layout determines where the level appears.
@onready var panel: Panel = $VBoxContainer/HBoxContainer/Panel

## Displays hints and code-error / status messages.
## Passed to the level via [method GameMapScene.setup].
@onready var hint_label: Label = $VBoxContainer/HBoxContainer/VBoxContainer/HintLabel

const LEVEL_PATHS := {
	1: "res://game_map_scenes/game_map_scene_level1.tscn",
	
	#2: "res://game_map_scenes/game_map_scene_level2.tscn",
	#3: "res://game_map_scenes/game_map_scene_level3.tscn",
}

const LEVEL_SCRIPT_PATHS: Dictionary = {
	1: "res://game_map_script/game_map_scene_level_1.gd",
	
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
	
	# make an instance of level1 gameMapScene, set its script, 
	# so that it knows its a gameMapScene class, otherwise casting as gameMapScene will FAIL
	var scene_path = LEVEL_PATHS.get(SceneManager.selected_level, "")
	var script_path = LEVEL_SCRIPT_PATHS.get(SceneManager.selected_level, "")
	
	assert(scene_path != "", ".tscn not found in LEVEL_PATH")
	assert(script_path != "", ".gd not found in LEVEL_PATH")
	
	var inst : Node = load(scene_path).instantiate()
	inst.set_script(load(script_path))
	
	# initiating the GameMapScene node
	game_map_scene = inst as GameMapScene
	
	panel.add_child(game_map_scene)

	game_map_scene.setup(hint_label)

	## Submit handler.
	## Resets the level, runs the player's code, and locks Submit + Reset for
	## the full duration of execution (including all awaited movement steps).
	## [code]await[/code] is required: [method GameMapScene.execute_code] is a
	## coroutine and returns at its first internal [code]await[/code].
	
	## without await, while game_map_scene.execute_code(code_text_edit.text) is awaiting, the buttons will be enabled too soon (unintended
	submit_button.pressed.connect(
		func():
			reset_button.disabled = true
			submit_button.disabled = true
			game_map_scene.level_reset()
			await game_map_scene.execute_code(code_text_edit.text)
			reset_button.disabled = false
			submit_button.disabled = false
	)
	
	## Reset handler. Restores the level to its start state.
	reset_button.pressed.connect(
		game_map_scene.level_reset
	)
	
	## Hint handler. Cycles the level's hint list and shows the next hint entry.
	hint_button.pressed.connect(
		game_map_scene.refresh_hint
	)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
