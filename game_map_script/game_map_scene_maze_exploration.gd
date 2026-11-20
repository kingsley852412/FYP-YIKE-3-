extends GameMapScene

## The player-controlled robot. Handles grid-locked movement by using roadTileMapLayer.
@onready var mc_body: mcBody = $MCBody

@onready var road_tiles: TileMapLayer = $RoadTileMapLayer
@onready var fog_tiles: TileMapLayer = $FogTileMapLayer

@onready var items_container: Node2D = $Items
@onready var item_template: Sprite2D = $Items/ItemTemplate
@onready var exit_marker: Sprite2D = $ExitMarker

## 6 × 4 rooms, connected by a road in the middle.
## The final actual size of the TileMap is 11 × 7.
const ROOM_COLUMNS: int = 6
const ROOM_ROWS: int = 4

const MAZE_WIDTH: int = ROOM_COLUMNS * 2 - 1
const MAZE_HEIGHT: int = ROOM_ROWS * 2 - 1

const ITEM_COUNT: int = 5
const MIN_ITEM_DISTANCE_FROM_START: int = 4
const MIN_DISTANCE_BETWEEN_ITEMS: int = 3

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
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

## Search Status
enum SearchVisualState {
	VISITED,
	ACTIVE,
	BACKTRACKED,
}

const VISITED_COLOR := Color(0.15, 0.55, 1.0, 0.32)
const ACTIVE_COLOR := Color(0.2, 1.0, 0.35, 0.48)
const BACKTRACKED_COLOR := Color(0.7, 0.3, 1.0, 0.32)

const SEARCH_MARKER_Y_OFFSET: float = 3.0

var search_states: Dictionary = {}
var search_path: Array[Vector2i] = []

## Search for the color of the grid cell currently occupied by the robot.
var search_visual_robot_cell: Vector2i = Vector2i.ZERO

## For DEVELOPMENT TEST , you can change this boolen to true and skip the coding.
## true：Ignore the contents of the game's Code Editor and execute DFS_TEST_CODE.
## false：The program entered by the player in the Code Editor will be executed normally.
const USE_DFS_TEST_CODE: bool = true

var robot_api = preload("res://game_api/robot_api.gd").new()

var item_nodes: Array[Sprite2D] = []
var collected_items: int = 0
var exit_unlocked: bool = false
var level_finished: bool = false

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## The seed for this random dungeon.
## When a bug is discovered, you can use it to reproduce the same map.
var maze_seed: int = 0

## All randomly generated road tiles.
var maze_cells: Array[Vector2i] = []

## Random starting point.
var start_cell: Vector2i = Vector2i.ZERO

## Random item locations.
var item_cells: Array[Vector2i] = []

## Record an original road tile, then use it to redraw the road.
var road_source_id: int = -1
var road_atlas_coords: Vector2i = Vector2i.ZERO
var road_alternative: int = 0

## Record a Fog tile, then use it to re-lay the Fog.
var fog_source_id: int = -1
var fog_atlas_coords: Vector2i = Vector2i.ZERO
var fog_alternative: int = 0

func _ready() -> void:
	super._ready()
	
	robot_api.body = mc_body
	
	# This level does not use regular targets.
	# However, the target_body that shares the robot_api has type requirements.
	# Temporarily points to mc_body; This level will disable target_position/rescue.
	robot_api.target_body = mc_body
	
	_cache_tile_samples()
	_generate_new_level()
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
		"Green shows the robot's current cell, blue shows visited cells, and purple shows completed branches.",
	])

## 在清除 TileMap 前，記錄 Road 和 Fog 使用的 tile。
func _cache_tile_samples() -> void:
	var existing_road_cells: Array[Vector2i] = road_tiles.get_used_cells()
	var existing_fog_cells: Array[Vector2i] = fog_tiles.get_used_cells()

	assert(
		not existing_road_cells.is_empty(),
		"RoadTileMapLayer must contain at least one sample tile."
	)

	assert(
		not existing_fog_cells.is_empty(),
		"FogTileMapLayer must contain at least one sample tile."
	)

	var road_sample: Vector2i = existing_road_cells[0]

	road_source_id = road_tiles.get_cell_source_id(road_sample)
	road_atlas_coords = road_tiles.get_cell_atlas_coords(road_sample)
	road_alternative = road_tiles.get_cell_alternative_tile(road_sample)

	var fog_sample: Vector2i = existing_fog_cells[0]

	fog_source_id = fog_tiles.get_cell_source_id(fog_sample)
	fog_atlas_coords = fog_tiles.get_cell_atlas_coords(fog_sample)
	fog_alternative = fog_tiles.get_cell_alternative_tile(fog_sample)


## 產生本次關卡使用的迷宮、起點和道具。
func _generate_new_level() -> void:
	maze_seed = int(Time.get_ticks_usec())
	rng.seed = maze_seed

	_generate_random_maze()
	_choose_random_start_and_items()
	_restore_fog()

	print("Level 20 maze seed: ", maze_seed)


## Use randomized DFS to generate a perfect maze.
## All roads must be interconnected.
func _generate_random_maze() -> void:
	road_tiles.clear()
	maze_cells.clear()

	var start_room := Vector2i(
		rng.randi_range(0, ROOM_COLUMNS - 1) * 2,
		rng.randi_range(0, ROOM_ROWS - 1) * 2
	)

	var visited_rooms: Dictionary = {}
	visited_rooms[start_room] = true

	var stack: Array[Vector2i] = [start_room]

	_carve_road(start_room)

	while not stack.is_empty():
		var current_room: Vector2i = stack.back()
		var possible_rooms: Array[Vector2i] = []

		for direction in CARDINAL_DIRECTIONS:
			var next_room: Vector2i = current_room + direction * 2

			if next_room.x < 0 or next_room.x >= MAZE_WIDTH:
				continue

			if next_room.y < 0 or next_room.y >= MAZE_HEIGHT:
				continue

			if visited_rooms.has(next_room):
				continue

			possible_rooms.append(next_room)

		if possible_rooms.is_empty():
			stack.pop_back()
			continue

		var random_index: int = rng.randi_range(0, possible_rooms.size() - 1)

		var next_room: Vector2i = possible_rooms[random_index]

		## The space between current_room and next_room is the passageway.
		var corridor: Vector2i = (current_room + next_room) / 2

		_carve_road(corridor)
		_carve_road(next_room)

		visited_rooms[next_room] = true
		stack.append(next_room)


func _carve_road(cell: Vector2i) -> void:
	if maze_cells.has(cell):
		return

	maze_cells.append(cell)

	road_tiles.set_cell(
		cell,
		road_source_id,
		road_atlas_coords,
		road_alternative
	)
	
func _choose_random_start_and_items() -> void:
	var possible_start_cells: Array[Vector2i] = []

	## For the starting point, select only the room cells; do not select the passages between the rooms.
	for cell in maze_cells:
		if cell.x % 2 == 0 and cell.y % 2 == 0:
			possible_start_cells.append(cell)

	assert(not possible_start_cells.is_empty(), "No valid start cells were generated.")

	var start_index: int = rng.randi_range(0, possible_start_cells.size() - 1)

	start_cell = possible_start_cells[start_index]

	var distances: Dictionary = _calculate_distances(start_cell)
	var candidates: Array[Vector2i] = []

	## Prioritize squares that are at a certain distance from the starting point.
	for cell in maze_cells:
		if cell == start_cell:
			continue

		var distance: int = int(distances.get(cell, 0))

		if distance >= MIN_ITEM_DISTANCE_FROM_START:
			candidates.append(cell)

	item_cells.clear()

	## Randomly determine the positions of the items, ensuring they are not all clustered together.
	while (item_cells.size() < ITEM_COUNT and not candidates.is_empty()):
		var candidate_index: int = rng.randi_range(0, candidates.size() - 1)

		var candidate: Vector2i = candidates[candidate_index]
		candidates.remove_at(candidate_index)

		if _is_far_enough_from_other_items(candidate):
			item_cells.append(candidate)

	## If the distance restrictions are too strict, resulting in fewer than five, use other roads to make up the number.
	if item_cells.size() < ITEM_COUNT:
		for cell in maze_cells:
			if item_cells.size() >= ITEM_COUNT:
				break

			if cell == start_cell:
				continue

			if item_cells.has(cell):
				continue

			item_cells.append(cell)

	assert(
		item_cells.size() == ITEM_COUNT,
		"Not enough road cells to place all items."
	)


func _is_far_enough_from_other_items(candidate: Vector2i) -> bool:
	for existing_item in item_cells:
		var separation: int = (absi(candidate.x - existing_item.x)
			+ absi(candidate.y - existing_item.y)
		)

		if separation < MIN_DISTANCE_BETWEEN_ITEMS:
			return false

	return true


## BFS calculates the true maze distance from the origin to every cell.
func _calculate_distances(origin: Vector2i) -> Dictionary:
	var distances: Dictionary = {}
	var queue: Array[Vector2i] = [origin]
	var queue_index: int = 0

	distances[origin] = 0

	while queue_index < queue.size():
		var current: Vector2i = queue[queue_index]
		queue_index += 1

		var current_distance: int = int(distances[current])

		for direction in CARDINAL_DIRECTIONS:
			var next_cell: Vector2i = current + direction

			if road_tiles.get_cell_source_id(next_cell) == -1:
				continue

			if distances.has(next_cell):
				continue

			distances[next_cell] = current_distance + 1
			queue.append(next_cell)

	return distances
	
func _create_items() -> void:
	item_template.visible = false
	
	for index in range(ITEM_COUNT):
		var item := item_template.duplicate() as Sprite2D
		
		item.name = "DataFragment_%02d" % (index + 1)
		item.visible = true
		
		items_container.add_child(item)
		item_nodes.append(item)
	
	_set_item_positions()

func _set_item_positions() -> void:
	assert(
		item_nodes.size() == item_cells.size(),
		"Item node count does not match random item cells."
	)

	for index in range(item_nodes.size()):
		var cell: Vector2i = item_cells[index]

		assert(
			road_tiles.get_cell_source_id(cell) != -1,
			"Item cell %s is not walkable." % cell
		)

		item_nodes[index].global_position = road_tiles.to_global(
			road_tiles.map_to_local(cell)
		)

## Reset restores Fog
func _restore_fog() -> void:
	fog_tiles.clear()

	## -1 and MAZE_WIDTH/HEIGHT represent a ring of fog around the perimeter of the map.
	for y in range(-1, MAZE_HEIGHT + 1):
		for x in range(-1, MAZE_WIDTH + 1):
			fog_tiles.set_cell(
				Vector2i(x, y),
				fog_source_id,
				fog_atlas_coords,
				fog_alternative
			)

## Show the current position and four adjacent cells.
func _reveal_around(center_cell: Vector2i) -> void:
	for offset in VISION_OFFSETS:
		fog_tiles.erase_cell(center_cell + offset)

## Display the DFS search process by colours
func _draw() -> void:
	if road_tiles == null or road_tiles.tile_set == null:
		return
	
	var tile_size: Vector2 = (
		Vector2(road_tiles.tile_set.tile_size)
		* road_tiles.scale
		* 0.72
	)
	
	for cell_value in search_states:
		var cell: Vector2i = cell_value
		var state: int = int(search_states[cell])
		var color: Color = VISITED_COLOR
		
		match state:
			SearchVisualState.ACTIVE:
				color = ACTIVE_COLOR
			
			SearchVisualState.BACKTRACKED:
				color = BACKTRACKED_COLOR
		
		var cell_center: Vector2 = road_tiles.transform * road_tiles.map_to_local(cell)
		
		cell_center.y += (SEARCH_MARKER_Y_OFFSET * road_tiles.scale.y)

		var marker_rect := Rect2(cell_center - tile_size * 0.5, tile_size)

		draw_rect(marker_rect, color, true)

func _reset_search_visualization() -> void:
	search_states.clear()
	search_path.clear()
	
	search_path.append(start_cell)
	search_states[start_cell] = SearchVisualState.ACTIVE
	
	search_visual_robot_cell = start_cell
	
	queue_redraw()

## Restores the level to its starting state.
func level_reset() -> void:
	compiler.cancel()
	robot_api.stop()
	
	collected_items = 0
	exit_unlocked = false
	level_finished = false
	
	mc_body.snap_to_cell(start_cell)
	_reset_search_visualization()
	
	var robot_sprite := $MCBody/AnimatedSprite2D as AnimatedSprite2D
	robot_sprite.play("default")
	
	for item in item_nodes:
		item.visible = true
	
	_set_item_positions()
	
	exit_marker.visible = false
	exit_marker.global_position = road_tiles.to_global(
		road_tiles.map_to_local(start_cell)
	)
	
	_restore_fog()
	_reveal_around(start_cell)
	
	HintLabel.text = (
		"Explore the random maze and collect all Data Fragments. "
		+ "Green: current, Blue: visited, Purple: backtracked. "
		+ "Fragments: 0/%d | Seed: %d"
		% [item_cells.size(), maze_seed]
	)

## Update search status while the robot is moving
func _record_search_move(cell: Vector2i) -> void:
	if search_path.is_empty():
		search_path.append(cell)
		search_states[cell] = SearchVisualState.ACTIVE
		queue_redraw()
		return

	var previous_cell: Vector2i = search_path.back()

	if previous_cell == cell:
		return

	## Moving back one step along the search path indicates that DFS is backtracking.
	if (
		search_path.size() >= 2
		and cell == search_path[search_path.size() - 2]
	):
		var completed_cell: Vector2i = search_path.pop_back()

		search_states[completed_cell] = (
			SearchVisualState.BACKTRACKED
		)

	## Otherwise, it means the DFS has entered a new branch.
	else:
		search_states[previous_cell] = SearchVisualState.VISITED

		if not search_path.has(cell):
			search_path.append(cell)

	search_states[cell] = SearchVisualState.ACTIVE
	queue_redraw()

## Called while the Robot is moving between two cells.
func _on_robot_movement_in_progress(target_cell: Vector2i) -> void:
	_reveal_around(target_cell)
	
## The robot handles Fog and items when it enters a grid.
func _on_robot_updated_position(grid_coordinate: Vector2) -> void:
	var cell := Vector2i(grid_coordinate)
	
	_reveal_around(cell)
	_collect_item_at(cell)
	
	if exit_unlocked and cell == start_cell and not level_finished:
		level_finished = true
		call_deferred("_complete_level")

## Collect items
func _collect_item_at(cell: Vector2i) -> void:
	
	for index in range(item_cells.size()):
		
		if item_cells[index] != cell:
			continue
		
		var item := item_nodes[index]
		
		# If it has already been collected, it cannot be counted again.
		if not item.visible:
			return
		
		item.visible = false
		collected_items += 1
		
		var total : int = item_cells.size()
		
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

func _process(_delta: float) -> void:
	if not is_instance_valid(mc_body):
		return

	if search_path.is_empty():
		return

	## get_cell() determines which cell the Robot is currently in, based on its current position.
	var robot_cell: Vector2i = mc_body.get_cell()

	## Updates occur only when the robot moves into a different cell.
	if robot_cell == search_visual_robot_cell:
		return

	search_visual_robot_cell = robot_cell
	_record_search_move(robot_cell)

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
	
	for index in range(item_cells.size()):
		if item_cells[index] == cell and item_nodes[index].visible:
			return "item"
	
	if exit_unlocked and cell == start_cell:
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
		"items_remaining": item_cells.size() - collected_items,
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
				"value": item_cells.size() - collected_items
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
