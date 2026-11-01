extends RefCounted
## Only this adapter knows about Godot nodes. Replies contain JSON-compatible data.

const DIRECTIONS := {
	"up": Vector2i.UP, "down": Vector2i.DOWN,
	"left": Vector2i.LEFT, "right": Vector2i.RIGHT,
}

var max_movement_steps: int

var body: mcBody
var target_body: mcBody

# when initializing robot_api for target_bodies, use the setter!!!
var _target_bodies: Array[mcBody]
var _target_bodies_collected: Array[bool] = []


var steps_used := 0
var _generation := 0

signal array_get_item(index: int)
signal array_set_item(index: int, value)

func _init(max_steps: int = 100) -> void:
	max_movement_steps = max_steps
	
func set_max_movement_steps(new_max_movement_steps: int):
	max_movement_steps = new_max_movement_steps

func set_target_bodies(input_target_bodies: Array[mcBody]):
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
	
	if method == "robot.rescue" and args.is_empty():
		if SceneManager.selected_level in [7, 11]:
			# This function CAN NOT be used in level 7, multiple collection level
			return {"value": false, "rescued": false}
		
		if body.get_cell() != target_body.get_cell():
			return {"value": false, "rescued": false}
		body.rescue()
		return {"value": true, "rescued": true}

	if method == "robot.collect" and args.is_empty():
		# TODO: change this to suit for multiple collection in target_bodies
		if SceneManager.selected_level != 7:
			# This function CAN ONLY be used in level 7, multiple collection level
			return {
				"value": false, 
				"collected": false, 
				"all_collected": not _target_bodies_collected.has(false)
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
			
		# 3. covert to index to INT
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
			
		# 3. covert to index to INT
		var index: int = int(args[0])
		var value = args[1]			# this stores the value to be SET into the array
		
		array_set_item.emit(index, value)
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
		
		
	
	## Section Below is for robot.move_xxxx()
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
