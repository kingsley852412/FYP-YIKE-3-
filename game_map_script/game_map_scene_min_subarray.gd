extends GameMapSceneSearchSort

# how many walls does the player need to break?
const NUMEBR_OF_COLUMNS: int = 4
# what is the x coordinate of the right-most column? (the last wall to be broke)
# (assuming player break walls from left to right, the walls are Vertical)
const END_COLUMN_INDEX: int = 10
# what is the spacing between walls?
const WALL_SPACING: int = 2
# the Game Map's Height, determines how much number does each Wall has
const GAME_MAP_HEIGHT: int = 8

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	num_of_targets = GAME_MAP_HEIGHT * NUMEBR_OF_COLUMNS
	super._ready()
	
func _generate_question_answer() -> void:
	# 1. 生成随机数组（允许负数，且允许重复）
	array_values.clear()
	for i in range(num_of_targets):
		array_values.append(randi_range(-9, 10))
		
	# 2. calculate each walls' subarray with minimum sum, storing the sum, instead of [start, end] index, there could be multiple min subarray
	var expected_answers: Array[int] = []
	
	for wall_idx in range(NUMEBR_OF_COLUMNS):
		var start_idx: int = wall_idx * GAME_MAP_HEIGHT
		var end_idx: int = start_idx + GAME_MAP_HEIGHT - 1
		
		# 针对这一面墙单独运行 Min-Kadane
		var min_sum: int = 99999999
		var current_sum: int = 0
		
		for i in range(start_idx, end_idx + 1):
			current_sum += array_values[i]
			
			if current_sum < min_sum:
				min_sum = current_sum
				
			# 如果前缀和大于 0，说明前面都是累赘，从当前元素重新开始算
			if current_sum > 0:
				current_sum = 0
				
		expected_answers.append(min_sum)
		
	# 3. 设置答案
	# 我们把每一面墙对应的“最小和”存进 answer 数组
	robot_api.answer = expected_answers
	# let robot_api READ the array value, but robot API should never change array values
	robot_api.ARRAY_VALUES_REFERENCE = array_values
	# setup walls in robot API
	robot_api.setup_walls(NUMEBR_OF_COLUMNS)
	
	# 4. 设置限制
	# 如果想让玩家用 O(N) 解法，可以考虑把 max_array_access 限制为 num_of_targets * 2
	robot_api.max_array_access = 10000		
	robot_api.max_array_swap = 10000

func _generate_target_coordinate() -> void:
	target_coordinates = []
	
	for i in range(num_of_targets):
		var wall_idx: int = i / GAME_MAP_HEIGHT
		var row_idx: int = i % GAME_MAP_HEIGHT
		
		var x: int = END_COLUMN_INDEX - (NUMEBR_OF_COLUMNS - 1 - wall_idx) * WALL_SPACING
		
		var y: int = row_idx
		
		target_coordinates.append(Vector2(x, y))
		
func _generate_goto_coordinate() -> void:
	goto_coordinates.clear()
	for cord in target_coordinates:
		# 机器人在墙的左边一格读取 array
		goto_coordinates.append(Vector2(cord.x - 1, cord.y))
