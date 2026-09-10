extends GameMapScene

@onready var mc_body: mcBody = $MCBody
@onready var road_tiles:TileMapLayer = $RoadTileMapLayer
@onready var target_body: mcBody = $TargetBody

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func setup(hintLabelInput: Label) -> void:
	super.setup(hintLabelInput)
	
	hints.append_array(
		[
			"you can use robot.up/down/left/right to move around!",
		]
	)
	
	level_reset()

func level_reset() -> void:
	mc_body.snap_to_cell(Vector2i(0, 0))
	target_body.snap_to_cell(Vector2i(5, 4))

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
					await mc_body.tile_movement(Vector2.UP)
					
			compiler.Action.MOVE_DOWN:
				for j in range(i[1]):
					await mc_body.tile_movement(Vector2.DOWN)
					
			compiler.Action.MOVE_LEFT:
				for j in range(i[1]):
					await mc_body.tile_movement(Vector2.LEFT)
					
			compiler.Action.MOVE_RIGHT:
				for j in range(i[1]):
					await mc_body.tile_movement(Vector2.RIGHT)
					
			_:
				assert(false, "unknown instruction")
