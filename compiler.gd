class_name Compiler
extends RefCounted

# this Action enum defined the type of instruction
# that can be sent to main game logic script
# to perform character move up/down/left/right in grid map levels
# or future action such as highlight a data entry in KNN level
enum Action{
	MOVE_UP,
	MOVE_DOWN,
	MOVE_LEFT,
	MOVE_RIGHT,
	RESCUE,
}

# !!!!Important!!!!
# plz ensure ErrorCode doesnt have actual value same as any of the Action,
# otherwise it would crash
enum ErrorCode{
	OK = 1000,              # 无错误
	EMPTY_CODE,          # 输入为空
	SYNTAX_ERROR,        # 语法错误
	UNKNOWN_ACTION,      # 未知指令	
	TIMEOUT_ERROR,		#時間過長，防止無限循環
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func process_code(input_code: String) -> Array:
	if input_code.length() == 0:
		return [
			[ErrorCode.EMPTY_CODE]
		]
	
	return [
		[Action.MOVE_RIGHT, 5],
		[Action.MOVE_DOWN, 4],
	]
