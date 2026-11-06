## This script must be attached to the root node of
## [code]res://game_map_scenes/game_map_scene_level1.tscn[/code].
## If the script is missing or fails to parse, [method GameMapScene.execute_code]
## cannot be reached and casting the instance to [GameMapScene] will return
## null.
extends GameMapScene

## The player-controlled robot. Handles grid-locked movement by using roadTileMapLayer.
@onready var mc_body: mcBody = $MCBody

## The goal marker the player must move [member mc_body] onto.
## in this level, target_body is used as a template to duplicate multiple target_bodies
## since this level has multiple target to collect
@onready var target_body: mcBody = $TargetBody

## this array stores the multiple target bodies
@onready var target_bodies: Array[mcBody] = []

# num of targets to collect, (including the initial target_body, that is used as template for duplication
var num_of_targets: int = 11
# for storing Randomized Spawn Points of targets, used in execute code to initialize namespace
var target_coordinates: Array[Vector2] = []
# for storing array values to be used by player
var array_values: Array[int] = []


var robot_api = preload("res://game_api/robot_api.gd").new()

## Called when the node enters the scene tree.
## Intentionally empty — all setup is deferred to [method setup], which is
## called by the [Level] UI after this node is added as a child.
func _ready() -> void:
	super._ready()
	
	# also uses the initial target_body that is used as template
	target_bodies.append(target_body)
	
	# add (num_of_targets - 1) duplicate of target_body and add them to the node tree
	for i in range(num_of_targets - 1):
		var new_target: mcBody = target_body.duplicate()
		new_target.name = "TargetBody_%d" % (i + 1)
		add_child(new_target)
		
		# Place all Humans in front of the MCBody.
		# When the Robot and Human have the same Y-position, the Robot will be drawn in front.
		move_child(new_target, mc_body.get_index())
		
		target_bodies.append(new_target)
	
	robot_api.body = mc_body
	robot_api.target_body = target_body
	robot_api.set_target_bodies(target_bodies)
	robot_api.array_get_item.connect(_on_array_get_item)
	robot_api.array_set_item.connect(_on_array_set_item)
	
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
			"click execute button to run your code!",
			"try clicking hint button to get more hints!",
			"when you are stuck, hit reset button to reset level progress",
			"click code reset button resets your codes.",
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
	
	var mc_body_spawn_point: Vector2i = Vector2i(5, 3)
	mc_body.snap_to_cell(mc_body_spawn_point)
	var mc_animated_sprite: AnimatedSprite2D = $MCBody/AnimatedSprite2D
	mc_animated_sprite.play("default")
	
	robot_api.set_target_bodies(target_bodies)	# this is called to reset "Collected" Boolean record in robot_api 
	target_coordinates = []
	# generate a vec2 coordinate for each target
	var start_row = 0
	var row_margin = 1
	var board_width = 11

	# randomize random values in range (1, 100) inclusive
	# for array_values to be used by players
	array_values.clear()
	var pool: Array[int] = []
	pool.assign(range(1, 101))   # 1..100 inclusive
	pool.shuffle()
	array_values.assign(pool.slice(0, num_of_targets))
	# -----------------------------------------------

	# the correct answer is the sorted version of array_values
	var sorted_answer: Array = array_values.duplicate()
	sorted_answer.sort()
	robot_api.answer = [sorted_answer]
	robot_api.max_array_access = 4 * num_of_targets * (num_of_targets - 1)
	
	for i in range(num_of_targets):
		var row_group: int = i / board_width          # int division in GDScript 4
		var col:       int = i % board_width
		var box_row:   int = start_row + row_group * (row_margin + 1)
		target_coordinates.append(Vector2(col, box_row))

	assert (len(target_bodies) == len(target_coordinates))
	assert (len(target_bodies) == len(array_values))
	
	# move all targets to their position
	for i in range(len(target_bodies)):
		var t = target_bodies[i]
		var pos = target_coordinates[i]
		t.snap_to_cell(pos)
			
		# get TargetBody's NumberTag node's Text Label
		var number_tag_label: Label = t.get_node("NumberTag/TextureRect/Label")
		
		# change numberTag number
		number_tag_label.text = str(array_values[i])
	
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
	compiler.run_code(
		code_text, 
		{
			"array" : array_values,		# this part initializes what variables are AVAILABLE to player
		},
	)

func _on_call_requested(method: String, args: Array, request_id: int, ticket: int) -> void:
	var result: Dictionary = await robot_api.dispatch(method, args)
	
	if method == "robot.rescue" and not result.has("error"):
		if result["rescued"]:
			level_completed.emit()
		elif not result["rescued"]:
			level_failed.emit("Target not Rescued!")
		else:
			assert(false, "unexpected value: non-bool value on result['rescued']")
			
		stop_code()
		
	## assuming "rescued" and "collected" would appear in the same level code result
	elif method == "robot.collect" and not result.has("error"):
		if not result["collected"]:
			level_failed.emit("Error!\nBattery not collected!")
		else:
			pass #does nothing if fails to collect Battery

		if result["all_collected"]:
			level_completed.emit()
			
	elif method == "robot.submit" and not result.has("error"):
		if result["value"]:
			level_completed.emit()
		else:
			level_failed.emit("Incorrect Answer!")
			
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

func _on_array_get_item(index: int) -> void:
	mc_body.get_array_element()

func _on_array_set_item(index: int, value) -> void:
	# 1. 断言：确保传进来的是数字 (兼容 JSON 带来的 float)
	if not typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		warning_raised.emit("Value must be a number!")
		return
	assert(typeof(value) in [TYPE_INT, TYPE_FLOAT], "Value must be a number!")
	
	# 2. 断言：如果是浮点数，确保它是个整数（例如 3.0 可以，3.5 不行）
	if not value == floor(value):
		warning_raised.emit("Value must be an integer, not a decimal!")
		return
	assert(value == floor(value), "Value must be an integer, not a decimal!")
	
	# 3. 安全转换
	value = int(value)		# the value in THIS level is supposed to be INT
	
	array_values[index] = value
	
	var value_label: Label = target_bodies[index].get_node("NumberTag/TextureRect/Label")
	value_label.text = str(value)
	mc_body.set_array_element()
