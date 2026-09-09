extends GameMapScene

var compiler: Compiler = Compiler.new()
@onready var mcbody:= $MCBody

# "Level" node should pass the Hint Label to here, so that we can update HintLabel
var HintLabel: Label

# hints and hint index for looping the hints list to show to player
var current_hint_index: int = 0
var hints: Array[String] = [
	"click execute button to run your code!",
	"clicking hint button to get more hints!",
	"when you are stuck, hit reset button to reset level progress!",
	"you can use robot.up/down/left/right to move around!",
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func level_reset() -> void:
	pass

func execute_code(code_text: String) -> void:
	# get list of instructions from compiler
	var instructions: Array = compiler.process_code(code_text)
	
	# HintLabel should be provided from Level node!
	assert(HintLabel != null, "HintLabel Not Initialized/ missing")
	
	# read instructions 1-by-1 to perform actions
	for i in instructions:
		match i[0]:
			compiler.ErrorCode.EMPTY_CODE:
				HintLabel.text = "empty Code!!!"
			
			compiler.Action.MOVE_UP:
				for j in range(i[1]):
					await mcbody.tile_movement(Vector2.UP)
					
			compiler.Action.MOVE_DOWN:
				for j in range(i[1]):
					await mcbody.tile_movement(Vector2.DOWN)
					
			compiler.Action.MOVE_LEFT:
				for j in range(i[1]):
					await mcbody.tile_movement(Vector2.LEFT)
					
			compiler.Action.MOVE_RIGHT:
				for j in range(i[1]):
					await mcbody.tile_movement(Vector2.RIGHT)
					
			_:
				assert(false, "unknown instruction")

func refresh_hint() -> void:
	assert(HintLabel != null, "HintLabel Not Initialized/ missing")
	
	# show the next hint in the list to the player
	current_hint_index += 1
	current_hint_index %= len(hints)
	
	HintLabel.text = hints[current_hint_index]
