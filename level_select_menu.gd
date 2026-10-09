extends Control

const CATEGORIES: Array[String] = ["BASIC", "MEDIUM", "HARD"]

const PAGE_COUNT: int = 3
const LEVELS_PER_PAGE: int = 10
const GRID_COLUMNS: int = 5

## Size of each level button.
const BUTTON_MIN_SIZE : Vector2 = Vector2(110, 60)

## Page transition animation time.
const PAGE_ANIMATION_DURATION: float = 0.32

## Number of pixels that the mouse drag to refresh the page.
const DRAG_THRESHOLD: float = 90.0

## When completing other levels, added their number here.
const IMPLEMENTED_LEVELS := {
	1: true,
	2: true,
	3: true,
}

@onready var left_arrow_button: Button = $VBoxContainer/NavigationRow/LeftArrowButton

@onready var category_label: Label = $VBoxContainer/NavigationRow/CategoryLabel

@onready var right_arrow_button: Button = $VBoxContainer/NavigationRow/RightArrowButton

@onready var page_viewport: Control = $VBoxContainer/PageViewport

@onready var page_strip: Control = $VBoxContainer/PageViewport/PageStrip

@onready var page_indicator_label: Label = $VBoxContainer/PageIndicatorLabel

@onready var back_button: Button = $VBoxContainer/BackButton

## Displayed current page number.
## 0 = Basic、1 = Medium、2 = Hard。
var current_page: int = 0

## Store three pages created during execution.
var pages: Array[Control] = []

## Page Animation.
var page_tween: Tween

## Mouse drag state.
var is_dragging: bool = false
var drag_start_x: float = 0.0
var drag_strip_start_x: float = 0.0

## Dragging the page to switch pages prevents the level button from being accidentally pressed.
var drag_consumed_click: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:	
	AudioManager.play_music("Title_bgm", 0, true)
	
	# Connect the left and right arrows.
	left_arrow_button.pressed.connect(_on_left_arrow_pressed)
	right_arrow_button.pressed.connect(_on_right_arrow_pressed)
	
	#connect back_button signal to "go to main menu" 
	back_button.pressed.connect(SceneManager.goto_start_menu)

	# When the window size changes, the position of each page is recalculated.
	page_viewport.resized.connect(_layout_pages)

	# Create pages and level buttons.
	_build_pages()

	# Waiting for Godot Container to complete its first layout.
	await get_tree().process_frame

	_layout_pages()
	_show_page(0, false)
		

## Automatically create pages of level buttons.
func _build_pages() -> void:
	for page_index in range(PAGE_COUNT):
		var page := Control.new()
		page.name = "Page%d" % (page_index + 1)
		page.mouse_filter = Control.MOUSE_FILTER_PASS

		page_strip.add_child(page)
		pages.append(page)

		# CenterContainer positions the GridContainer in the center of the page.
		var center_container := CenterContainer.new()
		center_container.name = "CenterContainer"
		page.add_child(center_container)

		center_container.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

		var grid := GridContainer.new()
		grid.name = "GridContainer"
		grid.columns = GRID_COLUMNS
		grid.add_theme_constant_override("h_separation", 20)
		grid.add_theme_constant_override("v_separation", 20)

		center_container.add_child(grid)

		# Page 1：1–10
		# Page 2：11–20
		# Page 3：21–30
		for local_level_index in range(LEVELS_PER_PAGE):
			var level_number := (page_index * LEVELS_PER_PAGE + local_level_index + 1)

			var level_button := Button.new()
			level_button.name = "LevelButton%d" % level_number
			level_button.custom_minimum_size = BUTTON_MIN_SIZE
			level_button.text = "Level %02d" % level_number

			var implemented := IMPLEMENTED_LEVELS.has(level_number)

			if not implemented:
				level_button.disabled = true
				level_button.text += "\nComing Soon"

			level_button.pressed.connect(_on_level_button_pressed.bind(level_number))

			grid.add_child(level_button)

## Arrange the pages according to the PageViewport size.
func _layout_pages() -> void:
	if pages.is_empty():
		return

	var page_size := page_viewport.size

	# The size of a container may be zero before the layout is complete.
	if page_size.x <= 0.0 or page_size.y <= 0.0:
		return

	# The width of PageStrip is equal to the combined width of total page.
	page_strip.size = Vector2(
		page_size.x * PAGE_COUNT,
		page_size.y
	)

	for page_index in range(pages.size()):
		var page := pages[page_index]

		page.position = Vector2(
			page_size.x * page_index,
			0.0
		)

		page.size = page_size

	# Resize stops the old animation and immediately aligns it to the current page.
	if page_tween != null and page_tween.is_valid():
		page_tween.kill()

	page_strip.position = Vector2(
		-current_page * page_size.x,
		0.0
	)


## Display the page.
func _show_page(page_index: int, animate: bool = true) -> void:
	current_page = clampi(
		page_index,
		0,
		PAGE_COUNT - 1
	)

	_update_page_header()

	if animate:
		_animate_to_current_page()
	else:
		page_strip.position = Vector2(
			-current_page * page_viewport.size.x,
			0.0
		)


## PageStrip left and right movement animation.
func _animate_to_current_page() -> void:
	if page_tween != null and page_tween.is_valid():
		page_tween.kill()

	var target_position := Vector2(
		-current_page * page_viewport.size.x,
		0.0
	)

	page_tween = create_tween()

	page_tween.tween_property(
		page_strip,
		"position",
		target_position,
		PAGE_ANIMATION_DURATION
	).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## Update category names, arrows, and page dots.
func _update_page_header() -> void:
	category_label.text = CATEGORIES[current_page]

	## Hide the left arrow on the leftmost page.
	_set_arrow_displayed(left_arrow_button, current_page > 0)
	
	## Hide the right arrow on the rightmost page.
	_set_arrow_displayed(right_arrow_button,current_page < PAGE_COUNT - 1)


	## Show the current page by dot
	var indicator_text := ""

	for page_index in range(PAGE_COUNT):
		if page_index > 0:
			indicator_text += "   "

		if page_index == current_page:
			indicator_text += "●"
		else:
			indicator_text += "○"

	page_indicator_label.text = indicator_text

## Show or hide the arrow, but retain its space within the HBoxContainer.
func _set_arrow_displayed(button: Button, should_display: bool) -> void:
	# Transparency 1 = Show; 0 = Completely transparent.
	button.modulate.a = 1.0 if should_display else 0.0

	# Cannot be pressed when hidden.
	button.disabled = not should_display

	# Do not receive mouse events when hidden.
	button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if should_display
		else Control.MOUSE_FILTER_IGNORE
	)

	# Cannot be selected using the Tab key or keyboard when hidden
	button.focus_mode = (
		Control.FOCUS_ALL
		if should_display
		else Control.FOCUS_NONE
	)

func _on_left_arrow_pressed() -> void:
	AudioManager.play_click()
	_show_page(current_page - 1)


func _on_right_arrow_pressed() -> void:
	AudioManager.play_click()
	_show_page(current_page + 1)


func _on_level_button_pressed(level_number: int) -> void:
	# Do not enter the level if you have just performed a drag.
	if drag_consumed_click:
		return

	AudioManager.play_click()
	SceneManager.goto_level(level_number)


## Receives mouse clicks, moves, and releases.
## Use _input instead of PageViewport.gui_input as the mouse might be pressed on the level button and dragged.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)

	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		# Drag only begins when you press a button in PageViewport.
		if not page_viewport.get_global_rect().has_point(event.position):
			return

		# If the previous page-slicing animation is still in progress, stop it
		if page_tween != null and page_tween.is_valid():
			page_tween.kill()

		is_dragging = true
		drag_start_x = event.position.x
		drag_strip_start_x = page_strip.position.x
		drag_consumed_click = false

	else:
		if not is_dragging:
			return

		var drag_distance := event.position.x - drag_start_x
		is_dragging = false

		if absf(drag_distance) >= DRAG_THRESHOLD:
			# Tell the level button: This time it's drag, not click.
			drag_consumed_click = true

			var old_page := current_page

			if drag_distance < 0.0:
				# Drag to the left to go to the next page.
				_show_page(current_page + 1)
			else:
				# Drag to the right to go to the previous page.
				_show_page(current_page - 1)

			if current_page != old_page:
				AudioManager.play_click()

			# Clicks will only be accepted again after this mouse release is complete.
			get_tree().create_timer(0.10).timeout.connect(
				_clear_drag_click_guard
			)

		else:
			# If insufficient drag distance, return to the original page.
			_animate_to_current_page()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not is_dragging:
		return

	var drag_distance := event.position.x - drag_start_x

	var minimum_x := (-page_viewport.size.x * (PAGE_COUNT - 1))

	var proposed_x := drag_strip_start_x + drag_distance

	# PageStrip must not be dragged off the first or last page.
	proposed_x = clampf(proposed_x, minimum_x, 0.0)

	page_strip.position = Vector2(proposed_x, 0.0)


func _clear_drag_click_guard() -> void:
	drag_consumed_click = false


func _on_back_button_pressed() -> void:
	AudioManager.play_click()
