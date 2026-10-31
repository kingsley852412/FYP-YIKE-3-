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
		if body.get_cell() != target_body.get_cell():
			return {"value": false, "rescued": false}
		body.rescue()
		return {"value": true, "rescued": true}

	if method == "robot.collect" and args.is_empty():
		# TODO: change this to suit for multiple collection in target_bodies
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
