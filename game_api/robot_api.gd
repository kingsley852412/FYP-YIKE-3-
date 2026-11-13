extends RefCounted
## Only this adapter knows about Godot nodes. Replies contain JSON-compatible data.

signal array_get_item(index: int)
signal array_set_item(index: int, value)
signal array_swap_item(index_I: int, index_J: int)

const DIRECTIONS := {
	"up": Vector2i.UP, "down": Vector2i.DOWN,
	"left": Vector2i.LEFT, "right": Vector2i.RIGHT,
}

var max_movement_steps: int
var max_array_access: int		# this is for Limiting Max number of access to the array, including value assignment, for setting time complexity limit for Sorting/Searching
var max_array_swap: int		# this is for Limiting Max number of Swap to the array, including value assignment, for setting time complexity limit for Sorting/Searching

var body: mcBody
var target_body: mcBody

# when initializing robot_api for target_bodies, use the setter function, DO NOT directly set value for this!!!
var _target_bodies: Array[mcBody]
var _target_bodies_collected: Array[bool] = []

# this is an array for storing the answer
# which user uses robot.submit() to submit their answer
var answer: Array = []

var array_access_used: int = 0
var array_swap_used: int = 0
var steps_used := 0
var _generation := 0


func _init(max_steps: int = 100, max_access: int = 1000) -> void:
	max_movement_steps = max_steps
	max_array_access = max_access
	
func set_target_bodies(input_target_bodies: Array[mcBody]):
	## Setting _target_bodies array in robot api.gd, and their "Collected" Boolean record
	_target_bodies = input_target_bodies
	_target_bodies_collected.resize(_target_bodies.size())
	_target_bodies_collected.fill(false)
	
	# they should have same size, 1-to-1 correspondence
	assert(_target_bodies.size() == _target_bodies_collected.size())

func begin_run() -> void:
	stop()
	steps_used = 0

func stop() -> void:
	_generation += 1
	body.cancel_pending_movement()


func dispatch(method: String, args: Array) -> Dictionary:
	if method == "robot.target_reached" and args.is_empty():
		return {"value": body.get_cell() == target_body.get_cell()}

	if method == "robot.goto":
		if args.size() != 1 or not (args[0] is Array) or args[0].size() != 2:
			return {"error": "robot.goto expects [x, y]"}
		
		# expects 1 arg, the position [x, y] stored in an array
		# make robot goto the given position in param
		assert (typeof(args[0]) == 28) 		# assert it is an array
		
		var goal_position: Vector2i = Vector2(args[0][0],args[0][1])
		
		while goal_position != Vector2i(body.get_cell()):
			var cur_mc_position: Vector2i = body.get_cell()
			
			if goal_position.x < body.get_cell().x:
				await body.tile_movement(Vector2(DIRECTIONS["left"]))

			elif goal_position.x > body.get_cell().x:
				await body.tile_movement(Vector2(DIRECTIONS["right"]))

			elif goal_position.y < body.get_cell().y:
				await body.tile_movement(Vector2(DIRECTIONS["up"]))

			elif goal_position.y > body.get_cell().y:
				await body.tile_movement(Vector2(DIRECTIONS["down"]))
				
			if cur_mc_position == Vector2i(body.get_cell()):
				# if didnt moved (e.g. due to bumping wall
				return {"value": false}
				
		return {"value": true}	
	
	if method == "robot.position" and args.is_empty():
		var cell := body.get_cell()
		return {"value": [cell.x, cell.y]}
		
	if method == "robot.target_position" and args.is_empty():
		var cell := target_body.get_cell()
		return {"value": [cell.x, cell.y]}
		
	if method == "robot.can_move":
		if args.size() != 1 or not args[0] is String or not DIRECTIONS.has(args[0]):
			return {"error": "can_move expects up, down, left, or right"}
		return {"value": body.can_move(DIRECTIONS[args[0]])}
	
	## terminating functions:
	## calling these functions may complete/fail the level

	if method == "robot.rescue" and args.is_empty():
		var cur_level: int = SceneManager.selected_level
		if cur_level == 7 or cur_level >= 11:
			# This function CAN NOT be used in level 7, multiple collection level
			return {"error": "robot.rescue NOT available in this Level"}
		
		if body.get_cell() != target_body.get_cell():
			return {"value": false, "rescued": false}
		body.rescue()
		return {"value": true, "rescued": true}

	if method == "robot.collect" and args.is_empty():
		# changed this to suit for multiple collection in target_bodies
		if SceneManager.selected_level != 7:
			# This function CAN ONLY be used in level 7, multiple collection level
			return {
				"error": "robot.collect() is not available in this level!"
			}
			
		assert (_target_bodies.size() == _target_bodies_collected.size())
		
		for i in range(_target_bodies.size()):
			var t = _target_bodies[i]
			
			if body.get_cell() == t.get_cell() and not _target_bodies_collected[i]:
				# if MC is standing on 1 of the Target Bodies,
				# and that target is NOT collected YET
				_target_bodies_collected[i] = true		# record
				_target_bodies[i].visible = false		# hide the target body after collection
				body.collect()
				return {
					"value": true, 
					"collected": true, 
					"all_collected": not _target_bodies_collected.has(false)
				}
		
		return {
			"value": false, 
			"collected": false, 
			"all_collected": not _target_bodies_collected.has(false)
		}

	if method == "robot.submit":
		var current_level = SceneManager.selected_level
		
		print(args)
		
		if args.size() != answer.size():
			return {"error": "expected {0} arguments, received {1}".format([answer.size(), args.size()])}
		
		match current_level:
			11, 12, 13, 14, 15, 16, 17, 18, 19, 20:
				var answer_is_correct: bool = _check_answer(args)
				return {"value": answer_is_correct}
			_:
				return {"error": "{0} NOT available in this Level".format([method])}

	#=====================================================
	
	#section for "array"
	
	if method == "array.__getitem__":
		if (args.size() != 1):
			return {"error": "expect only 1 arguments!!"}
			
		# 1. check if index is int OR float,
		# since Json Parsing will parse Interger Index to be float
		if not (args[0] is int or args[0] is float):
			return {"error": "index of array can only be int!"}
			
		# 2. check if index is a whole number, (can it be turned into INT safely???)
		if args[0] is float and args[0] != floor(args[0]):
			return {"error": "index of array can only be an integer!"}
		
		if array_access_used >= max_array_access:
			return {"error": "Max array Access Exceeded, make ur code more Efficient!"}
			
		# the validation checking is finished
		# we actually do things now
		
		# 3. covert to index to INT
		array_access_used += 1
		var index: int = int(args[0])
		
		array_get_item.emit(args[0])
		return {"value": true}
	
	if method == "array.__setitem__":
		if (args.size() != 2):
			return {"error": "expect 2 arguments!!"}
			
		# 1. check if index is int OR float,
		# since Json Parsing will parse Interger Index to be float
		if not (args[0] is int or args[0] is float):
			return {"error": "index of array can only be int!"}
			
		# 2. check if index is a whole number, (can it be turned into INT safely???)
		if args[0] is float and args[0] != floor(args[0]):
			return {"error": "index of array can only be an integer!"}
			
		if array_access_used >= max_array_access:
			return {"error": "Max array Access Exceeded, make ur code more Efficient!"}
			
		# the validation checking is finished
		# we actually do things now
		
		# 3. covert to index to INT
		array_access_used += 1
		var index: int = int(args[0])
		var value = args[1]			# this stores the value to be SET into the array
		
		array_set_item.emit(index, value)
		return {"value": true}
		
	if method == "array.swap":
		if args.size() != 2:
			return {"error": "swap expects 2 indices"}
		if array_swap_used >= max_array_swap:
			return {"error": "Max array SWAP Exceeded, make ur code more Efficient!"}
		
		var idx1 = int(args[0])
		var idx2 = int(args[1])
		
		# 发出信号，让关卡去更新数据并播放动画
		array_swap_item.emit(idx1, idx2)
		return {"value": true}
		
	
	#=====================================================
	
	#section for general Functions
		
	# private function, should NOT be used by players
	if method == "_wait":
		if args.size() not in [0, 1]:
			return {"error": "input only 0, or 1 argument!"}
		
		if args.size() == 1:
			# when has input param for WAITING_TIME
			if not (typeof(args[0]) in [TYPE_INT, TYPE_FLOAT]):
				return {"error": "enter a number!"}
				
			if args[0] < 0:
				return {"error": "enter positive waiting Time!!!"}
				
			# the await here uses "body", but it can also use any Node in the game node tree
			await body.get_tree().create_timer(args[0]).timeout	
		else:
			const DEFAULT_WAIT_TIME: int = 1
			await body.get_tree().create_timer(DEFAULT_WAIT_TIME).timeout	
		
		return {"value": true}	
		
		
	#=====================================================
	# Section Below is for robot.move_xxxx()
	
	var direction_name := method.trim_prefix("robot.move_")
	
	if not method.begins_with("robot.move_") or not DIRECTIONS.has(direction_name):
		return {"error": "Unknown game API: " + method}
	
	if args.size() != 1 or not (args[0] is int or args[0] is float):
		return {"error": "steps must be an integer"}
	
	var count := float(args[0])
	
	if not is_finite(count) or count != floor(count) or count < 0 or count > 100:
		return {"error": "steps must be an integer between 0 and 100"}
	
	var ticket := _generation
	
	for index in range(int(count)):
		if ticket != _generation:
			return {"error": "Execution cancelled"}
	
		if steps_used >= max_movement_steps:
			return {"error": "Movement limit exceeded ({0} steps per run)".format([max_movement_steps])}
	
		steps_used += 1
	
		var moved := await body.tile_movement(Vector2(DIRECTIONS[direction_name]))
	
		if ticket != _generation:
			return {"error": "Execution cancelled"}
	
		if not moved:
			return {"value": false}
	
	return {"value": true}


#=====================================================
# Section for "robot.submit" — answer checking

# Deep-compare `expected` (the authoritative Godot-side answer) with
# `actual` (the user's answer, arriving through JSON where every number
# has been turned into a float).
func _deep_equal(expected, actual) -> bool:
	var e_type := typeof(expected)
	var a_type := typeof(actual)

	# Both arrays → element-wise recursive comparison (handles 2D arrays,
	# and arrays containing mixed scalar/array elements).
	if e_type == TYPE_ARRAY and a_type == TYPE_ARRAY:
		if expected.size() != actual.size():
			return false
		for i in range(expected.size()):
			if not _deep_equal(expected[i], actual[i]):
				return false
		return true

	# One is an array, the other isn't → not equal.
	if e_type == TYPE_ARRAY or a_type == TYPE_ARRAY:
		return false

	# Bools must match bools exactly.
	# We must NOT let `true == 1` slip through (GDScript's == coerces),
	# so this branch is handled explicitly before the numeric one.
	if e_type == TYPE_BOOL or a_type == TYPE_BOOL:
		return e_type == TYPE_BOOL and a_type == TYPE_BOOL and expected == actual

	# Numbers: compare numerically so an int in `answer` (e.g. 5) still
	# matches a float coming out of JSON (5.0).
	var e_is_num := e_type == TYPE_INT or e_type == TYPE_FLOAT
	var a_is_num := a_type == TYPE_INT or a_type == TYPE_FLOAT
	if e_is_num and a_is_num:
		return float(expected) == float(actual)

	# Mixed number / non-number → not equal.
	if e_is_num != a_is_num:
		return false

	# Fallback for strings / other value types.
	return expected == actual

# Takes the user-submitted answer as `args` (a flat array whose items can be
# bool / int / float / Array / nested Array) and compares it with `answer`.
# Returns true iff the two match structurally and by value.
func _check_answer(user_args: Array) -> bool:
	return _deep_equal(answer, user_args)
