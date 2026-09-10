class_name GameMapScene
extends Node2D

var compiler: Compiler = Compiler.new()

# "Level" node should pass the Hint Label to here, so that we can update HintLabel
# HintLabel is supposed to show both Hints, and code error warnings
var HintLabel: Label

# hints and hint index for looping the hints list to show to player
var current_hint_index: int = 0
var hints: Array[String] = [
	"click execute button to run your code!",
	"clicking hint button to get more hints!",
	"when you are stuck, hit reset button to reset level progress!",
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func setup(hintLabelInput: Label) -> void:
	HintLabel = hintLabelInput
	
func level_reset() -> void:
	assert(false, "Error, game_map_scene.gd level_reset(), not implemented by subclass yet")

func execute_code(code_text: String) -> void:
	assert(false, "Error, game_map_scene.gd execute_code(), not implemented by subclass yet")

func refresh_hint() -> void:
	assert(HintLabel != null, "HintLabel Not Initialized/ missing")
	
	# show the next hint in the list to the player
	current_hint_index += 1
	current_hint_index %= len(hints)
	
	HintLabel.text = hints[current_hint_index]
