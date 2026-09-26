## Level 1 implementation of [GameMapScene].
##
## A single-screen puzzle level: the player types movement commands into
## the [Level] UI's code editor, and [MCBody] walks the robot across a
## [TileMapLayer]-based grid. The objective is to reach [member target_body].
##
## Responsibilities:
## - Own the level-1 scene nodes ([MCBody], [TargetBody], [RoadTileMapLayer]).
## - Provide level-1-specific hints.
## - Reset the robot and target to their starting cells.
## - Translate the compiled action list into [MCBody] movements.
##
## This script must be attached to the root node of
## [code]res://game_map_scenes/game_map_scene_level1.tscn[/code].
## If the script is missing or fails to parse, [method GameMapScene.execute_code]
## cannot be reached and casting the instance to [GameMapScene] will return
## null.
extends GameMapScene

## The player-controlled robot. Handles grid-locked movement by using roadTileMapLayer.
@onready var mc_body: mcBody = $MCBody

## The goal marker the player must move [member mc_body] onto.
@onready var target_body: mcBody = $TargetBody
var robot_api = preload("res://game_api/robot_api.gd").new()

## Called when the node enters the scene tree.
## Intentionally empty — all setup is deferred to [method setup], which is
## called by the [Level] UI after this node is added as a child.
func _ready() -> void:
	super._ready()
	robot_api.body = mc_body
	robot_api.target_body = target_body
	compiler.call_requested.connect(_on_call_requested)
	compiler.execution_failed.connect(_on_execution_failed)
	compiler.execution_finished.connect(_on_execution_finished)
	compiler.execution_cancelled.connect(_on_execution_cancelled)
	compiler.running_changed.connect(_on_running_changed)
	
	mc_body.bumped_into_wall.connect(_on_mc_bumped_wall)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
## Binds the UI hint label, extends the base hint list with hints specific for level-1,
## then resets the level.
##
## Called by [Level] (the UI scene) immediately after this scene is added
## to the tree. Must not be called before [method Node.add_child] — the
## @onready variables ([member mc_body], [member target_body])
## are null until then.
##
## [param hintLabelInput] The Label node owned by the UI that displays hints
## and status messages. Stored as [member GameMapScene.HintLabel].
func setup(hintLabelInput: Label) -> void:
	super.setup(hintLabelInput)
	
	hints.append_array(
		[
			"Use robot.move_right(5) and robot.move_down(4) to move!",
			"Use robot.rescue() when you stand on the target.",
			"hint1",
			"hint2",
			"hint3",
			"hint4",
		]
	)
	
	level_reset()


## Restores the level to its starting state.
##
## Places the robot at cell (0, 0) and the target at (5, 4).
## Called on first entry via [method setup], and every
## time the player presses the Reset button in the UI.
##
## See [method mcBody.snap_to_cell] for the instant-teleport behaviour, which is used here
## (as opposed to the animated [method mcBody.tile_movement]).
func level_reset() -> void:
	compiler.cancel()
	robot_api.stop()
	mc_body.snap_to_cell(Vector2i(0, 0))
	var mc_animated_sprite: AnimatedSprite2D = $MCBody/AnimatedSprite2D
	mc_animated_sprite.play("default")
	
	target_body.snap_to_cell(Vector2i(5, 4))
	target_body.global_position.y += 20
	HintLabel.text = "Ready. Write Python code and press Submit."


## Compiles [param code_text] and performs each resulting action, one instruction at a time.
##
## This is a coroutine: it uses await internally on
## [method mcBody.tile_movement] so each tile move plays out over its
## animation time. Callers in the UI must await this
## method if they need to know when execution has finished — otherwise the
## call returns at the first await and any code after it runs
## prematurely (e.g. re-enabling buttons mid-run).
##
## Behaviour by instruction:
## - [constant Compiler.ErrorCode.EMPTY_CODE] — writes "empty Code!!!"
##   to [member GameMapScene.HintLabel].
## - [constant Compiler.Action.MOVE_UP] / [code]DOWN[/code] /
##   [code]LEFT[/code] / [code]RIGHT[/code] — moves [member mc_body] one
##   tile per count, awaiting each step.
## - Any other value trips an assert (indicates a compiler/level mismatch).
##
## [param code_text] The raw text from the UI code editor.
func execute_code(code_text: String) -> void:
	if compiler.is_running:
		return
	robot_api.begin_run()
	HintLabel.text = "Running..."
	compiler.run_code(code_text)

func _on_call_requested(method: String, args: Array, request_id: int, ticket: int) -> void:
	var result: Dictionary = await robot_api.dispatch(method, args)
	if result.get("rescued", false):
		level_completed.emit()
	compiler.reply(request_id, ticket, result.get("value"), result.get("error", ""))

func _on_running_changed(running: bool) -> void:
	if not running:
		robot_api.stop()

func _on_execution_failed(error: Dictionary) -> void:
	var line := int(error.get("line", 0))
	var location := "Line %d: " % line if line > 0 else ""
	HintLabel.text = location + str(error.get("name", "Error")) + ": " + str(error.get("message", "Unknown error"))
	code_error.emit(line)

func _on_execution_finished() -> void:
	HintLabel.text = "Program finished."

func _on_execution_cancelled() -> void:
	HintLabel.text = "Stopped."

func _on_mc_bumped_wall() -> void:
	warning_raised.emit("Bumped Into Wall!")
	
