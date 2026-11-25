extends Control
## this script is to be used on the whole window.
## Code/Output/Hint Window shares this Window

## minimum size when Player Resize this Window
@export var min_size := Vector2(300, 200)
@export var max_size := Vector2(1200, 800)

var is_dragging := false
var is_resizing := false

## These are its Child Nodes, Remember to Set them on "Properties"!!!
@export var title_bar: Control
@export var resize_handle: Control
@export var close_button: Button

func _ready() -> void:
	assert(title_bar != null, "Internal Error: U forget to set the Title Bar!")
	assert(resize_handle != null, "Internal Error: U forget to set the resize_handle!")
	assert(close_button != null, "Internal Error: U forget to set the close_button!")
	
	# ensure default size is valid
	self.size.x = clamp(self.size.x, min_size.x, max_size.x)
	self.size.y = clamp(self.size.y, min_size.y, max_size.y)
	
	## set the Logic on Close Button
	if close_button != null:
		close_button.pressed.connect(_on_close_button_pressed)
		
	self.z_index = 101
	
func _input(event: InputEvent) -> void:
	# ================= 1. mouse Clicks processing =================
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:		
		# Get the Most Front UI
		var hovered_control = get_viewport().gui_get_hovered_control()
		# if self is Not the Most Front UI
		if not (hovered_control == self or (hovered_control != null and self.is_ancestor_of(hovered_control))):
			return	# dont do Anything
		
		if event.pressed:
			# if clicked on TitleBar -> begin Dragging
			if title_bar != null and title_bar.get_global_rect().has_point(event.position):
				is_dragging = true
			
			# if clicked on Resize Handle -> start resizing
			elif resize_handle != null and resize_handle.get_global_rect().has_point(event.position):
				is_resizing = true
			
			# if clicked anywhere on this Window
			if self.get_global_rect().has_point(event.position):
				self.move_to_front() # move window to Front
				
		else:
			# if released Mouse Key, Stop dragging/resizing
			is_dragging = false
			is_resizing = false

	# ================= 2. mouse Drags processing =================
	elif event is InputEventMouseMotion:
		var viewport_rect = get_viewport_rect()
		if not viewport_rect.has_point(event.position):
			is_dragging = false # when moving out of Game Window, Stop Dragging
			is_resizing = false	# and stops resizing
			return
		
		if is_dragging:			
			# moves entire Window
			self.position += event.relative
			
			# avoid Window be dragged too far
			var viewport_size = get_viewport_rect().size
			self.position.x = clamp(self.position.x, -self.size.x + 50, viewport_size.x - 50)
			self.position.y = clamp(self.position.y, 0, viewport_size.y - 50)
			
		elif is_resizing:
			# changes entire Window Size
			var new_size = self.size + event.relative
			
			# restrict min/max window size
			new_size.x = clamp(new_size.x, min_size.x, max_size.x)
			new_size.y = clamp(new_size.y, min_size.y, max_size.y)

			self.size = new_size

func _on_close_button_pressed() -> void:
	self.visible = false
	
