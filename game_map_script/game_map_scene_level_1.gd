extends GameMapScene

@onready var compiler: Compiler = Compiler.new()
@onready var mcbody:= $MCBody

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func execute_code(code_text: String) -> String:
	print(code_text)
	
	mcbody.tile_movement(Vector2.RIGHT)
	mcbody.tile_movement(Vector2.DOWN)
	return "OK"
