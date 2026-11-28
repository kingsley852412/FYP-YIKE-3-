extends Node2D
## 挂载在背景父节点上，无需 Camera2D 即可实现鼠标视差

# list of Node2d to be moved with parallax w.r.t. Mouse position
@export var layer_list: Array[Node2D] = []
# strength of Moving, Higher value = moves more
@export var strength_list: Array[float] = []

# 用于存储每个节点在场景里的初始位置
var initial_positions: Array[Vector2] = []

# 平滑系数，让视差移动更丝滑（0.05 表示比较慢，1.0 表示瞬间跟随）
@export var smoothness := 0.1

func _ready() -> void:
	assert(layer_list.size() == strength_list.size(), 'Incompatible sizes on Layers and Strength!')
	
	# record each layer's initial position
	initial_positions.clear()
	for layer in layer_list:
		if layer != null:
			initial_positions.append(layer.position)
		else:
			initial_positions.append(Vector2.ZERO)
			push_warning("Layer list contains a null element!")

func _process(delta: float) -> void:
	if layer_list.is_empty():
		return
		
	# 1. 获取鼠标在视口中的位置
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_size = get_viewport_rect().size
	
	# 2. 将鼠标坐标转化为 -1 到 1 之间的偏移量
	var center_offset = (mouse_pos / viewport_size) * 2.0 - Vector2(1.0, 1.0)
	
	# 3. 遍历所有图层并应用视差
	for i in range(layer_list.size()):
		var layer: Node2D = layer_list[i]
		if layer == null:
			continue
			
		var strength: float = strength_list[i]
		
		# 目标位置 = 初始位置 + 偏移量（注意反向 * -1）
		var target_position: Vector2 = initial_positions[i] + (-center_offset * strength)
		
		# 4. 平滑插值移动，并赋值给 position！
		# 这里的权重用了一个和帧率无关的平滑公式，保证在不同刷新率的屏幕上手感一致
		var weight: float = 1.0 - exp(-smoothness * 60.0 * delta)
		layer.position = layer.position.lerp(target_position, weight)
