extends GameMapSceneSearchSort

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	num_of_targets = 33		# init this before calling super._ready()
	
	super._ready()
	
func _generate_question_answer() -> void:
	# randomize random values in range (1, 100) inclusive
	# for array_values to be used by players
	
	array_values.clear()
	var pool: Array[int] = []
	pool.assign(range(1, num_of_targets + 1))   # 1..num_of_targets inclusive
	pool.shuffle()
	array_values.assign(pool.slice(0, num_of_targets))
	# -----------------------------------------------
	# setting Answer
	# the correct answer is the array index of the "number_to_find"
	const number_to_find := 1
	
	var answer_index: int = array_values.find(number_to_find)
	
	robot_api.answer = [answer_index]
	
	robot_api.max_array_access = num_of_targets
