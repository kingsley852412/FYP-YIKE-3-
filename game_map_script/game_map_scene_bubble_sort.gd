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
	
	robot_api.max_array_access = 10000 		# No limit in practice
