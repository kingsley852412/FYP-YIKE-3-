extends RefCounted
## Only this adapter knows about Godot nodes. Replies contain JSON-compatible data.

const DIRECTIONS := {
	"up": Vector2i.UP, "down": Vector2i.DOWN,
	"left": Vector2i.LEFT, "right": Vector2i.RIGHT,
}
const MAX_MOVEMENT_STEPS := 100

var body: mcBody
var target_body: mcBody
var steps_used := 0
var _generation := 0


func begin_run() -> void:
	stop()
	steps_used = 0


func stop() -> void:
	_generation += 1
	body.cancel_pending_movement()


func dispatch(method: String, args: Array) -> Dictionary:
	if method == "robot.position" and args.is_empty():
		var cell := body.get_cell()
		return {"value": [cell.x, cell.y]}
		
	if method == "robot.can_move":
		if args.size() != 1 or not args[0] is String or not DIRECTIONS.has(args[0]):
			return {"error": "can_move expects up, down, left, or right"}
		return {"value": body.can_move(DIRECTIONS[args[0]])}
	
	if method == "robot.rescue" and args.is_empty():
		if body.get_cell() != target_body.get_cell():
			return {"value": false}
		body.rescue()
		return {"value": true, "rescued": true}
	
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
	
		if steps_used >= MAX_MOVEMENT_STEPS:
			return {"error": "Movement limit exceeded (100 steps per run)"}
	
		steps_used += 1
	
		var moved := await body.tile_movement(Vector2(DIRECTIONS[direction_name]))
	
		if ticket != _generation:
			return {"error": "Execution cancelled"}
	
		if not moved:
			return {"value": false}
	
	return {"value": true}
