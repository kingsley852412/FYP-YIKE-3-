extends GameMapSceneSearchSort

const NUMBER_TO_FIND = 42

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	num_of_targets = 33		# init this before calling super._ready()
	
	super._ready()
	
func _generate_question_answer() -> void:
	array_values.clear()
	
	# 1. 生成一个 1 到 100 的数字池并打乱
	var pool: Array[int] = []
	pool.assign(range(1, 101))
	pool.shuffle()
	
	# 2. 从池中移除目标数字，避免随机生成的数字里出现重复的 42
	pool.erase(NUMBER_TO_FIND)
	
	# 3. 从池中取出 (num_of_targets - 1) 个不重复的数字
	array_values.assign(pool.slice(0, num_of_targets - 1))
	
	# 4. 把目标数字塞进去
	array_values.append(NUMBER_TO_FIND)
	
	# 5. 核心：sort the array（binary search的前提）
	array_values.sort()
	
	# -----------------------------------------------
	# 设置答案（目标数字所在的index）
	var answer_index: int = array_values.find(NUMBER_TO_FIND)
	robot_api.answer = [answer_index]
	
	robot_api.max_array_access = ceili(log(num_of_targets + 1) / log(2.0))
	# max number of Array Access Neeed for binary Search
	
