extends GameMapScene

## The player-controlled robot. Handles grid-locked movement by using roadTileMapLayer.
@onready var mc_body: mcBody = $MCBody

## The goal marker the player must move [member mc_body] onto.
@onready var target_body: mcBody = $TargetBody
var robot_api = preload("res://game_api/robot_api.gd").new()

@onready var road_tile_map_layer: TileMapLayer = $RoadTileMapLayer
@onready var mountain_tile_map_layer: TileMapLayer = $MountainTileMapLayer

var _road_pattern: TileMapPattern
var _mountain_pattern: TileMapPattern

const _pressure_plate_position: Vector2 = Vector2(1, 4)

const _tunnel_upper_left_corner_position: Vector2 = Vector2(4, 2)
const _tunnel_size: Vector2 = Vector2(3, 2)

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
	mc_body.updated_position.connect(_on_mc_updated_position)
	
	_road_pattern = road_tile_map_layer.get_pattern(road_tile_map_layer.get_used_cells())
	_mountain_pattern = mountain_tile_map_layer.get_pattern(mountain_tile_map_layer.get_used_cells())
	
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
			"click execute button to run your code!",
			"try clicking hint button to get more hints!",
			"when you are stuck, hit reset button to reset level progress",
			"click code reset button resets your codes.",
			"Use robot.rescue() when you stand on the target.",
		]
	)
	


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
	
	target_body.snap_to_cell(Vector2i(7, 4))
	
	road_tile_map_layer.set_pattern(Vector2i(0, 0), _road_pattern)
	mountain_tile_map_layer.set_pattern(Vector2i(4, 0), _mountain_pattern)
	
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
	
	if result.has("rescued"):
		if result["rescued"] == true:
			level_completed.emit()
		elif result["rescued"] == false:
			level_failed.emit("Target not Rescued!")
		else:
			assert(false, "unexpected value: non-bool value on result['rescued']")
			
		stop_code()

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
	

## this function is for detecting if mc_body reached certain grid,
## in this level, when mc steps on pressure plate, the wall explodes,
## opening the path to target
##
## param: mc_position is mc_body's grid coordinate in road tile map layer
func _on_mc_updated_position(mc_position: Vector2) -> void:
	if mc_position == _pressure_plate_position:
		for dx in _tunnel_size.x:
			for dy in _tunnel_size.y:
				# remove wall tiles from 	$MountainTileMapLayer
				# add road tiles to 		$RoadTileMapLayer
				
				var cell := _tunnel_upper_left_corner_position + Vector2(dx, dy)
				road_tile_map_layer.set_cell(cell, 1, Vector2(0, 0))
				mountain_tile_map_layer.set_cell(cell, -1)
