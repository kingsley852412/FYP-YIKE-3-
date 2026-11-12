extends GameMapScene

## The player-controlled robot. Handles grid-locked movement by using roadTileMapLayer.
@onready var mc_body: mcBody = $MCBody

@onready var road_tiles: TileMapLayer = $RoadTileMapLayer
@onready var fog_tiles: TileMapLayer = $FogTileMapLayer

@onready var items_container: Node2D = $Items
@onready var item_template: Sprite2D = $Items/ItemTemplate
@onready var exit_marker: Sprite2D = $ExitMarker

const START_CELL := Vector2i(0, 0)

## Temporarily fix the positions of five items.
## Ensure these tiles have roads on the RoadTileMapLayer.
const ITEM_CELLS: Array[Vector2i] = [
	Vector2i(10, 0),
	Vector2i(0, 2),
	Vector2i(2, 4),
	Vector2i(5, 5),
	Vector2i(10, 5),
]

const VISION_OFFSETS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]

const DIRECTION_VECTORS := {
	"up": Vector2i.UP,
	"down": Vector2i.DOWN,
	"left": Vector2i.LEFT,
	"right": Vector2i.RIGHT,
}

## For DEVELOPMENT TEST , you can change this boolen to true and skip the coding.
## true：Ignore the contents of the game's Code Editor and execute DFS_TEST_CODE.
## false：The program entered by the player in the Code Editor will be executed normally.
const USE_DFS_TEST_CODE: bool = true

var robot_api = preload("res://game_api/robot_api.gd").new()

var item_nodes: Array[Sprite2D] = []
var collected_items: int = 0
var exit_unlocked: bool = false
var level_finished: bool = false

## Store the original tiles of FogTileMapLayer
## so that they can be re-laid during a Reset.
var fog_template: Dictionary = {}

func _ready() -> void:
	super._ready()
	
	robot_api.body = mc_body
	
	# This level does not use regular targets.
	# However, the target_body that shares the robot_api has type requirements.
	# Temporarily points to mc_body; This level will disable target_position/rescue.
	robot_api.target_body = mc_body
	
	_cache_fog()
	_create_items()
	
	compiler.call_requested.connect(_on_call_requested)
	compiler.execution_failed.connect(_on_execution_failed)
	compiler.execution_finished.connect(_on_execution_finished)
	compiler.execution_cancelled.connect(_on_execution_cancelled)
	compiler.running_changed.connect(_on_running_changed)
	
	mc_body.movement_in_progress.connect(_on_robot_movement_in_progress)
	mc_body.updated_position.connect(_on_robot_updated_position)
	mc_body.bumped_into_wall.connect(_on_mc_bumped_wall)

func setup(hint_label_input: Label) -> void:
	super.setup(hint_label_input)
	
	hints.append_array([
		"Use robot.scan() to inspect the current and adjacent cells.",
		"Store visited positions in a set to prevent infinite loops.",
		"Explore one branch fully, then backtrack.",
		"When all fragments are collected, return to the starting cell.",
	])

func _create_items() -> void:
	item_template.visible = false
	
	for index in range(ITEM_CELLS.size()):
		var item := item_template.duplicate() as Sprite2D
		
		item.name = "DataFragment_%02d" % (index + 1)
		item.visible = true
		
		items_container.add_child(item)
		item_nodes.append(item)
	
	_set_item_positions()

func _set_item_positions() -> void:
	assert(
		item_nodes.size() == ITEM_CELLS.size(),
		"Item node count does not match ITEM_CELLS."
	)
	
	for index in range(item_nodes.size()):
		var cell := ITEM_CELLS[index]
		
		assert(
			road_tiles.get_cell_source_id(cell) != -1,
			"Item cell %s is not walkable." % cell
		)
		
		item_nodes[index].global_position = road_tiles.to_global(
			road_tiles.map_to_local(cell)
		)

## Storing Fog raw data
func _cache_fog() -> void:
	fog_template.clear()
	
	for cell in fog_tiles.get_used_cells():
		fog_template[cell] = {
			"source_id": fog_tiles.get_cell_source_id(cell),
			"atlas_coords": fog_tiles.get_cell_atlas_coords(cell),
			"alternative": fog_tiles.get_cell_alternative_tile(cell),
		}

## Reset restores Fog
func _restore_fog() -> void:
	fog_tiles.clear()
	
	for cell_value in fog_template:
		var cell: Vector2i = cell_value
		var tile_data: Dictionary = fog_template[cell]
		
		fog_tiles.set_cell(
			cell,
			tile_data["source_id"],
			tile_data["atlas_coords"],
			tile_data["alternative"]
		)

## Show the current position and four adjacent cells.
func _reveal_around(center_cell: Vector2i) -> void:
	for offset in VISION_OFFSETS:
		fog_tiles.erase_cell(center_cell + offset)

## Restores the level to its starting state.
func level_reset() -> void:
	compiler.cancel()
	robot_api.stop()
	
	collected_items = 0
	exit_unlocked = false
	level_finished = false
	
	mc_body.snap_to_cell(START_CELL)
	
	var robot_sprite := $MCBody/AnimatedSprite2D as AnimatedSprite2D
	robot_sprite.play("default")
	
	for item in item_nodes:
		item.visible = true
	
	_set_item_positions()
	
	exit_marker.visible = false
	exit_marker.global_position = road_tiles.to_global(
		road_tiles.map_to_local(START_CELL)
	)
	
	_restore_fog()
	_reveal_around(START_CELL)
	
	HintLabel.text = (
		"Explore the maze and collect all Data Fragments. "
		+ "Fragments: 0/%d" % ITEM_CELLS.size()
	)

## Called while the Robot is moving between two cells.
func _on_robot_movement_in_progress(target_cell: Vector2i) -> void:
	_reveal_around(target_cell)
	
## The robot handles Fog and items when it enters a grid.
func _on_robot_updated_position(grid_coordinate: Vector2) -> void:
	var cell := Vector2i(grid_coordinate)
	
	_reveal_around(cell)
	_collect_item_at(cell)
	
	if exit_unlocked and cell == START_CELL and not level_finished:
		level_finished = true
		call_deferred("_complete_level")

## Collect items
func _collect_item_at(cell: Vector2i) -> void:
	
	for index in range(ITEM_CELLS.size()):
		
		if ITEM_CELLS[index] != cell:
			continue
		
		var item := item_nodes[index]
		
		# If it has already been collected, it cannot be counted again.
		if not item.visible:
			return
		
		item.visible = false
		collected_items += 1
		
		var total := ITEM_CELLS.size()
		
		HintLabel.text = (
			"Data Fragment collected! %d/%d"
			% [collected_items, total]
		)
		
		if collected_items == total:
			_unlock_exit()
		
		return

## After collecting all items
func _unlock_exit() -> void:
	exit_unlocked = true
	exit_marker.visible = true
	
	# Show the full map.
	fog_tiles.clear()
	
	HintLabel.text = (
		"All Data Fragments collected! "
		+ "The complete map is restored. Return to the starting cell."
	)

## Complete the level
func _complete_level() -> void:
	if not level_finished:
		return
	
	level_completed.emit()
	stop_code()

## To implement robot.scan()
## Establish a method to describe the grid
func _describe_cell(cell: Vector2i) -> String:
	if road_tiles.get_cell_source_id(cell) == -1:
		return "wall"
	
	for index in range(ITEM_CELLS.size()):
		if ITEM_CELLS[index] == cell and item_nodes[index].visible:
			return "item"
	
	if exit_unlocked and cell == START_CELL:
		return "exit"
	
	return "floor"

## Create scan data
func _get_scan_data() -> Dictionary:
	var current := mc_body.get_cell()
	
	return {
		"position": [current.x, current.y],
		"current": _describe_cell(current),
		"up": _describe_cell(current + Vector2i.UP),
		"down": _describe_cell(current + Vector2i.DOWN),
		"left": _describe_cell(current + Vector2i.LEFT),
		"right": _describe_cell(current + Vector2i.RIGHT),
		"items_remaining": ITEM_CELLS.size() - collected_items,
		"exit_unlocked": exit_unlocked,
	}

## Handling Python api requests
func _on_call_requested(
	method: String,
	args: Array,
	request_id: int,
	ticket: int
) -> void:
	var result: Dictionary
	
	match method:
		"robot.scan":
			if not args.is_empty():
				result = {"error": "scan() does not accept arguments"}
			else:
				result = {"value": _get_scan_data()}
		
		"robot.items_remaining":
			result = {
				"value": ITEM_CELLS.size() - collected_items
			}
		
		"robot.exit_unlocked":
			result = {"value": exit_unlocked}
		
		"robot.goto", "robot.target_position", "robot.rescue":
			result = {
				"error": (
					"%s is unavailable in the maze exploration level. "
					+ "Use local scanning and one-cell movement."
				) % method
			}
		
		_:
			# Maze exploration requires observing each square one by one.
			if method.begins_with("robot.move_"):
				if args.size() != 1 or int(args[0]) != 1:
					result = {
						"error": (
							"Move one cell at a time in this level. "
							+ "Use robot.move_up(), move_down(), "
							+ "move_left(), or move_right()."
						)
					}
				else:
					result = await robot_api.dispatch(method, args)
			else:
				result = await robot_api.dispatch(method, args)
	
	compiler.reply(
		request_id,
		ticket,
		result.get("value"),
		result.get("error", "")
	)


func execute_code(code_text: String) -> void:
	if compiler.is_running:
		return
	robot_api.begin_run()
	
	# Default: Player's input is used .
	var source_code: String = code_text
	
	if USE_DFS_TEST_CODE and OS.is_debug_build():
		# Test mode: Switch to using the built-in DFS answer.
		source_code = DFS_TEST_CODE
		HintLabel.text = "Running built-in DFS test solution..."
		print("WARNING: Running DFS_TEST_CODE instead of player code.")
	else:
		# Normal mode: Use the player program within the Code Editor.
		HintLabel.text = "Running..."
		
	compiler.run_code(source_code)

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
	


## A complete DFS solution used only during development.
##
## Important:
## Top-level Python lines inside this multiline String must not
## contain leading tabs or spaces, otherwise Python may report
## "unexpected indent".
const DFS_TEST_CODE: String = """
visited = set()


def explore():
    position = robot.position

    if position in visited:
        return False

    visited.add(position)

    print(
        "Visiting:",
        position,
        "Items remaining:",
        robot.items_remaining
    )

    # After collecting the final item, every recursive call
    # returns True and backtracks towards the starting cell.
    if robot.exit_unlocked:
        print("All items collected. Backtracking to exit.")
        return True

    view = robot.scan()
    x, y = position

    directions = [
        (
            "up",
            (x, y - 1),
            robot.move_up,
            robot.move_down
        ),
        (
            "right",
            (x + 1, y),
            robot.move_right,
            robot.move_left
        ),
        (
            "down",
            (x, y + 1),
            robot.move_down,
            robot.move_up
        ),
        (
            "left",
            (x - 1, y),
            robot.move_left,
            robot.move_right
        ),
    ]

    for direction_name, next_position, move_forward, move_back in directions:
        if view[direction_name] == "wall":
            continue

        if next_position in visited:
            continue

        print(
            "Moving",
            direction_name,
            "from",
            position,
            "to",
            next_position
        )

        if move_forward():
            found_everything = explore()

            print(
                "Backtracking from",
                robot.position,
                "to",
                position
            )

            move_back()

            if found_everything:
                return True

    return False


explore()
"""
