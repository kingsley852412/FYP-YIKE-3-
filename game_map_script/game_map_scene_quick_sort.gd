extends GameMapSceneSearchSort

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	num_of_targets = 11
	super._ready()
	
func _generate_question_answer() -> void:
	# randomize random values in range (1, 100) inclusive
	# for array_values to be used by players
	
	array_values.clear()
	var pool: Array[int] = []
	pool.assign(range(1, 101))   # 1..100 inclusive
	pool.shuffle()
	array_values.assign(pool.slice(0, num_of_targets))
	# -----------------------------------------------
	# setting Answer
	# the correct answer is the sorted version of array_values
	var sorted_answer: Array = array_values.duplicate()
	sorted_answer.sort()
	robot_api.answer = [sorted_answer]
	
	# ==========================================
	# 动态计算 max_array_access 和 max_array_swap
	# ==========================================
	var n := float(num_of_targets)
	var log2_n := log(n) / log(2.0) # GDScript 的 log 默认是自然对数，需要转换为 log2
	
	# 1. 读取（比较）次数限制
	# 快排平均比较次数约为 1.4 * N * log2(N)。
	# 为了宽容一点，防止极端坏运气（比如选到不好的 Pivot），给到 2.5 倍系数 + 常数项
	robot_api.max_array_access = int(n * log2_n * 2.5) + 10
	
	# 2. 交换（swap）次数限制
	# 快排平均交换次数约为 0.35 * N * log2(N)。
	# 为了拦截冒泡排序（平均 N^2 / 4），给到 0.8 倍系数 + 常数项
	robot_api.max_array_swap = int(n * log2_n * 0.8) + 5
