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

## title label of this level
@onready var title_label: Label = %TitleLabel

## Runs the player's code. Disabled during execution to prevent double-submit.
@onready var submit_button: Button = %SubmitButton

## Resets the level to its starting state. Disabled during execution.
@onready var reset_button: Button = %ResetButton

## reset code entry box's content to default text
@onready var reset_code_button: Button = %ResetCodeButton


## Shows the next hint in the level's hint list.
@onready var hint_button: Button = %HintButton
@onready var stop_button: Button = %StopButton
@onready var output_text: TextEdit = %OutputText

@onready var exit_button: Button = %ExitButton

## The embedded level instance. Created in [method _ready]; do not access before then.
@onready var game_map_scene: GameMapScene

## The player's code input box.
@onready var code_text_edit: CodeEdit = %CodeTextEdit

## Placeholder container that reserves screen space for the level scene.
## The level is added as its child, so the Panel's layout determines where the level appears.
@onready var panel: Panel = %Panel

## Displays hints and code-error / status messages.
## Passed to the level via [method GameMapScene.setup].
@onready var hint_label: Label = %HintLabel

@onready var confirm_modal: ConfirmationModal = %ConfirmationModal
@onready var retry_modal: RetryModal = %RetryModal

## Displays clouds transition while pressing the Reset button.
@onready var cloud_transition: Control = %CloudTransition
@onready var cloud_mover: Control = %CloudMover

var reset_clouds: Array[TextureRect] = []

## Load three Cloud images
const CLOUD_TEXTURES := [
	preload("res://asset/Cloud1.png"),
	preload("res://asset/Cloud2.png"),
	preload("res://asset/Cloud3.png"),
]

## Use AtlasTexture to crop out most of the transparent space of clouds.
const CLOUD_REGIONS := [
	Rect2(0, 240, 1920, 560),   # Cloud1
	Rect2(80, 20, 1840, 860),   # Cloud2
	Rect2(0, 260, 1660, 520),   # Cloud3
]

const CLOUD_ROWS: int = 6
const CLOUD_COLUMNS: int = 5

# The size of each Cloud, relative to the Map.

const CLOUD_HEIGHT_RATIO: float = 0.36

# The distance between clouds.
# The distance is smaller than the size of the cloud, so they will have a small amount of overlap.
const CLOUD_HORIZONTAL_STEP: float = 0.24
const CLOUD_VERTICAL_STEP: float = 0.16

const CLOUD_MOVE_TIME: float = 0.7
const CLOUD_COVER_HOLD_TIME: float = 0.12

## To prevent players from pressing Reset repeatedly.
var reset_transition_running: bool = false

const LEVEL_PATHS := {
	1: "res://game_map_scenes/game_map_scene_level1.tscn",
	2: "res://game_map_scenes/game_map_scene_var_arithemetic.tscn",
	3: "res://game_map_scenes/game_map_scene_if_else.tscn",
	4: "res://game_map_scenes/game_map_scene_mist_search.tscn",
	5: "res://game_map_scenes/game_map_scene_minimum_step.tscn",
	6: "res://game_map_scenes/game_map_scene_exploding_wall.tscn",
}

const LEVEL_SCRIPT_PATHS: Dictionary = {
	1: "res://game_map_script/game_map_scene_level_1.gd",
	2: "res://game_map_script/game_map_scene_var_arithmetic.gd",
	3: "res://game_map_script/game_map_scene_if_else.gd",
	4: "res://game_map_script/game_map_scene_mist_search.gd",
	5: "res://game_map_script/game_map_scene_minimum_step.gd",
	6: "res://game_map_script/game_map_scene_exploding_wall.gd",
}

## default text in code entry box for each level
const DEFAULT_CODE_TEXT: Dictionary = {
	1: "# TUTORIAL
# try using codes to move the Robot!
# Objective: 
# move to Target
# rescue Target

# use these statements to move to other tiles
robot.move_right()
robot.move_down()
robot.move_left()
robot.move_up()
robot.rescue()",

	2: "# TUTORIAL
# try using Variables to move multiple tiles
# Objective: 
# move to Target
# rescue Target

# this line create a Variable!
a = 4

# Put Number in ()
# to move multiple times
robot.move_right(a)
robot.move_down(2)
robot.move_left(1)
robot.move_up(1)
robot.rescue()",

	3: "# TUTORIAL
# try using if/else to detect Target!
# Objective: 
# Fix the Wrong Code!!!
# move to Target
# rescue Target

# robot.target_reached()
# returns true when you reached target
# return false otherwise
robot.move_left(2)

if not robot.target_reached():
    robot.rescue()
else:
	robot.move_up()",
	
	4: "# CHALLENGE
# TARGET'S LOCATION IS UNKNOWN!!!

# Objective: 
# move to Target
# rescue Target

robot.move_right(2)
robot.move_down(3)

if robot.target_reached():
	robot.rescue()",
	
	5: "# CHALLENGE
# TARGET'S LOCATION IS UNKNOWN!!!

# Objective: 
# move to Target
# rescue Target

robot.move_right(2)
robot.move_down(3)

if robot.target_reached():
	robot.rescue()",
	
	6: "# CHALLENGE
# tips: step on blue tile to open a tunnel

# Objective: 
# move to Target
# rescue Target

robot.move_right(1)
robot.move_down(4)

robot.move_up()
robot.move_right(6)
robot.move_down()


if robot.target_reached():
	robot.rescue()",
	
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
	_create_reset_clouds()
	cloud_transition.hide()
	
	var current_level: int = SceneManager.selected_level
	
	# make an instance of level1 gameMapScene, set its script, 
	# so that it knows its a gameMapScene class, otherwise casting as gameMapScene will FAIL
	var scene_path = LEVEL_PATHS.get(current_level, "")
	var script_path = LEVEL_SCRIPT_PATHS.get(current_level, "")
	
	assert(scene_path != "", ".tscn not found in LEVEL_PATH")
	assert(script_path != "", ".gd not found in LEVEL_SCRIPT_PATH")
	
	var inst : Node = load(scene_path).instantiate()
	inst.set_script(load(script_path))
	
	# set up the GameMapScene node
	game_map_scene = inst as GameMapScene
	panel.add_child(game_map_scene)

	game_map_scene.setup(hint_label)
	game_map_scene.level_completed.connect(confirm_modal.show)
	game_map_scene.level_failed.connect(_on_level_failed)
	game_map_scene.execution_state_changed.connect(_on_execution_state_changed)
	game_map_scene.code_output.connect(_on_code_output)
	game_map_scene.code_error.connect(_on_code_error)
	game_map_scene.warning_raised.connect(_on_warning_raised)
	
	stop_button.disabled = true
	stop_button.pressed.connect(game_map_scene.stop_code)

	# initializing code input box to default text content
	reset_code_input(current_level)

	## Submit handler.
	## Resets the level, runs the player's code, and locks Submit + Reset for
	## the full duration of execution (including all awaited movement steps).
	## [code]await[/code] is required: [method GameMapScene.execute_code] is a
	## coroutine and returns at its first internal [code]await[/code].
	##
	## without await, while game_map_scene.execute_code(code_text_edit.text) is awaiting, the buttons will be enabled too soon (unintended
	submit_button.pressed.connect(
		func():
			game_map_scene.level_reset()
			output_text.text = ""
			code_text_edit.deselect()
			game_map_scene.execute_code(code_text_edit.text)
	)
	
	## Reset handler. Restores the level to its start state.
	reset_button.pressed.connect(
		_play_reset_transition
	)
	
	reset_code_button.pressed.connect(
		reset_code_input.bind(SceneManager.selected_level)
	)
	
	## Hint handler. Cycles the level's hint list and shows the next hint entry.
	hint_button.pressed.connect(
		game_map_scene.refresh_hint
	)
	
	exit_button.pressed.connect(SceneManager.goto_level_select)
	
	confirm_modal.confirmed.connect(_on_confirmation_modal_confirmed)
	retry_modal.confirmed.connect(_on_retry_modal_confirmed)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
	
func _create_reset_clouds() -> void:
	# Prevent duplicate creation.
	if not reset_clouds.is_empty():
		return
	
	var grid_cloud_count: int = CLOUD_ROWS * CLOUD_COLUMNS
	# Create another Cloud instance specifically to fill the top left corner.
	var cloud_count: int = grid_cloud_count + 1
	
	for index in range(cloud_count):
		var texture_index: int
		
		if index == grid_cloud_count:
			# Additional top-left corner fill Cloud using Cloud2.
			texture_index = 1
		else:
			texture_index = index % CLOUD_TEXTURES.size()
	
		# AtlasTexture only displays the area of ​​the cloud that is actually present in the PNG, 
		# avoiding the appearance of a huge cloud due to a lot of transparent space.
		var atlas_texture := AtlasTexture.new()
		atlas_texture.atlas = CLOUD_TEXTURES[texture_index]
		atlas_texture.region = CLOUD_REGIONS[texture_index]
	
		var cloud := TextureRect.new()
		cloud.name = "ResetCloud_%02d" % index
		cloud.texture = atlas_texture
	
		cloud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cloud.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
		cloud_mover.add_child(cloud)
		reset_clouds.append(cloud)
	
# Set the position of each cloud
func _layout_reset_clouds(map_size: Vector2) -> void:

	var cloud_height: float = map_size.y * CLOUD_HEIGHT_RATIO
	
	var index: int = 0
	
	for row in range(CLOUD_ROWS):
		# Even-numbered rows and odd-numbered rows use different starting points, 
		# forming a staggered arrangement like bricks.
		var row_start_x: float
		
		if row % 2 == 0:
			row_start_x = map_size.x * -0.12
		else:
			row_start_x = map_size.x * -0.28
		
		var row_y: float = map_size.y * (-0.08 + row * CLOUD_VERTICAL_STEP)
		
		for column in range(CLOUD_COLUMNS):
			var cloud: TextureRect = reset_clouds[index]
			
			var texture_index: int = index % CLOUD_REGIONS.size()
			var region_size: Vector2 = CLOUD_REGIONS[texture_index].size
			var cloud_aspect_ratio: float = region_size.x / region_size.y
			var cloud_width: float = cloud_height * cloud_aspect_ratio
			var cloud_x: float = row_start_x + (map_size.x * column *CLOUD_HORIZONTAL_STEP)
			
			cloud.position = Vector2(cloud_x, row_y)
			cloud.size = Vector2(cloud_width, cloud_height)
			
			index += 1
	
	# Add an additional Cloud2 of same size, and use its thicker middle section to fill the top left corner.
	var corner_cloud_index: int = CLOUD_ROWS * CLOUD_COLUMNS
	var corner_cloud: TextureRect = reset_clouds[corner_cloud_index]
	
	# This additional Cloud uses Cloud2.
	var corner_texture_index: int = 1
	var corner_region_size: Vector2 = CLOUD_REGIONS[corner_texture_index].size
	
	var corner_aspect_ratio: float = corner_region_size.x / corner_region_size.y

	# The altitude is exactly the same as other Clouds.
	var corner_cloud_height: float = map_size.y *CLOUD_HEIGHT_RATIO
	var corner_cloud_width: float = corner_cloud_height * corner_aspect_ratio
	
	corner_cloud.size = Vector2(corner_cloud_width, corner_cloud_height)
	
	# Place the solid central part of Cloud2 in the top left corner of the Map.
	corner_cloud.position = Vector2(
		map_size.x * 0.20 - corner_cloud_width * 0.50, 
		corner_cloud_height * -0.30
	)
	
	# It is placed behind other clouds and is only responsible for filling gaps.
	corner_cloud.z_index = -1
	
func _get_cloud_horizontal_bounds() -> Vector2:
	assert(not reset_clouds.is_empty(), "Reset clouds have not been created.")
	
	var first_cloud: TextureRect = reset_clouds[0]
	
	var minimum_x: float = first_cloud.position.x
	var maximum_x: float = first_cloud.position.x + first_cloud.size.x
	
	for cloud in reset_clouds:
		var cloud_left: float = cloud.position.x
		var cloud_right: float = cloud.position.x + cloud.size.x
		
		minimum_x = min(minimum_x, cloud_left) 
		maximum_x = max(maximum_x, cloud_right)
		
	# x stores the leftmost position, and y stores the rightmost position.
	return Vector2(minimum_x, maximum_x)
	
func _play_reset_transition() -> void:
	if reset_transition_running:
		return
	
	reset_transition_running = true
	
	game_map_scene.stop_code()
	
	hint_button.disabled = true
	exit_button.disabled = true
	_on_execution_state_changed(false)
	
	cloud_transition.show()
	
	# Waiting for the Layout to calculate the Map size.
	await get_tree().process_frame
	
	var map_size: Vector2 = cloud_transition.size
	var map_width: float = map_size.x
	
	# Arrange the small clouds.
	_layout_reset_clouds(map_size)
	
	# Calculate the actual left and right range of the entire Cloud group.
	var cloud_bounds: Vector2 = _get_cloud_horizontal_bounds()
	
	var cloud_left: float = cloud_bounds.x
	var cloud_right: float = cloud_bounds.y
	
	# The true center of the computing cloud cluster.
	var cloud_group_center_x: float = (cloud_left + cloud_right) * 0.5
	var map_center_x: float = map_width * 0.5
	
	# When aligning the Cloud cluster center with the Map center, CloudMover should stop at X.
	var cover_position_x: float = map_center_x - cloud_group_center_x
	
	# Leave a little extra space to ensure that the object is completely out of the frame before entering the scene.
	var outside_margin: float = map_width * 0.05
	
	# Make sure the rightmost Cloud is also completely on the left side of the Map.
	var start_position_x: float = -cloud_right - outside_margin
	
	# Make sure the leftmost Cloud is also completely off the right side of the Map.
	var leave_position_x: float = map_width - cloud_left + outside_margin
	
	cloud_mover.position = Vector2(start_position_x, 0.0)
	
	# Cloud enters from the left at the same time.
	var enter_tween: Tween = create_tween()
	enter_tween.set_trans(Tween.TRANS_SINE)
	enter_tween.set_ease(Tween.EASE_IN_OUT)
	
	enter_tween.tween_property(cloud_mover, "position:x", cover_position_x, CLOUD_MOVE_TIME)
	
	await enter_tween.finished
	
	# Reset when the small cloud cluster fully covers the map.
	game_map_scene.level_reset()
	
	await get_tree().process_frame
	await get_tree().create_timer(CLOUD_COVER_HOLD_TIME).timeout
	
	# The Cloud group continues to move to the right.
	var leave_tween: Tween = create_tween()
	leave_tween.set_trans(Tween.TRANS_SINE)
	leave_tween.set_ease(Tween.EASE_IN_OUT)
	
	leave_tween.tween_property(cloud_mover, "position:x", leave_position_x, CLOUD_MOVE_TIME)
	
	await leave_tween.finished
	
	cloud_transition.hide()
	
	cloud_mover.position = Vector2(start_position_x, 0.0)
	
	reset_transition_running = false
	
	hint_button.disabled = false
	exit_button.disabled = false
	_on_execution_state_changed(false)

func _on_execution_state_changed(running: bool) -> void:
	# All operations must remain locked during the cloud transition.
	if reset_transition_running:
		submit_button.disabled = true
		reset_button.disabled = true
		reset_code_button.disabled = true
		stop_button.disabled = true
		code_text_edit.editable = false
		return
		
	submit_button.disabled = running
	reset_button.disabled = running
	reset_code_button.disabled = running
	stop_button.disabled = not running
	code_text_edit.editable = not running

func _on_code_output(text: String) -> void:
	output_text.text += text
	output_text.set_caret_line(output_text.get_line_count() - 1)

func _on_code_error(line: int) -> void:
	if line > 0 and line <= code_text_edit.get_line_count():
		code_text_edit.select(line - 1, 0, line - 1, code_text_edit.get_line(line - 1).length())
		code_text_edit.set_caret_line(line - 1)

func _on_level_failed(fail_message: String) -> void:
	retry_modal.set_message_text(fail_message)
	retry_modal.show()

func reset_code_input(selected_level: int) -> void:
	var default_code: String = DEFAULT_CODE_TEXT.get(selected_level, "")
	assert(default_code != "", "default code not defined, or empty")
	
	code_text_edit.text = default_code

func _on_confirmation_modal_confirmed(is_confirmed: bool) -> void:
	if is_confirmed:
		SceneManager.goto_level(SceneManager.selected_level + 1)
	else:
		confirm_modal.hide()

func _on_retry_modal_confirmed() -> void:
	retry_modal.hide()

func _on_submit_button_pressed() -> void:
	AudioManager.play_click()


func _on_reset_button_pressed() -> void:
	AudioManager.play_click()


func _on_exit_button_pressed() -> void:
	AudioManager.play_click()
	

## this function is **NOT** for code compiler error in PYTHON
## this is for changing content of Hint Label in "Level"
## when player bumped into wall
## or other possible warnings in future levels
## e.g. failed boss fights/ caught by enemies/ etc.
func _on_warning_raised(message: String) -> void:
	hint_label.text = message


func _on_reset_code_button_pressed() -> void:
	AudioManager.play_click()


func _on_stop_button_pressed() -> void:
	AudioManager.play_click()
	

func _on_hint_button_pressed() -> void:
	AudioManager.play_click()
