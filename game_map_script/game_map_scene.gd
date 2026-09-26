## Abstract base class for a playable level.
##
## A level is a [Node2D] scene that:
## [br]- Owns a [Compiler] to turn player code into actions.
## [br]- Displays hints and code-error messages through [member HintLabel].
## [br]- Implements [method level_reset] and [method execute_code].
##
## Never instantiate this class directly. Subclass it (e.g. [code]GameMapSceneLevel1[/code]),
## attach the subclass script to a [code].tscn[/code] root, and instantiate that scene

class_name GameMapScene
extends Node2D

## this signal is to be used by external nodes
## e.g. Level.gd can use this to show notification/message/etc.
signal level_completed
signal execution_state_changed(running: bool)
signal code_output(text: String)
signal code_error(line: int)

## Converts player code text into a list of instructions.
var compiler: Compiler

## Label used to display hints and code-error messages.
## Set by the UI via [method setup]; must not be null before [method execute_code]
## or [method refresh_hint] is called.
var HintLabel: Label

## Index of the hint currently shown. Cycled by [method refresh_hint].
var current_hint_index: int = 0

## Hints shown to the player. Base entries are shared by all levels; subclasses append
## level-specific hints string in their own [method setup] override.
var hints: Array[String] = [
	"click execute button to run your code!",
	"clicking hint button to get more hints!",
	"when you are stuck, hit reset button to reset level progress!",
]

## this signal is **NOT** for code compiler error in PYTHON
## this is for changing content of Hint Label in "Level"
## when player bumped into wall
## or other possible warnings in future levels
## e.g. failed boss fights/ caught by enemies/ etc.
signal warning_raised(message: String)

## Called when the node enters the scene tree.
## Intentionally empty — subclass configuration happens in [method setup].
func _ready() -> void:
	compiler = Compiler.new()
	add_child(compiler)
	compiler.running_changed.connect(execution_state_changed.emit)
	compiler.output_received.connect(code_output.emit)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

## Stores the UI's [Label] so this level can write hints and error messages to it.
## Must be called by the UI after this node is added to the tree.
##
## [param hintLabelInput] The Hint Label owned by the UI scene.
func setup(hintLabelInput: Label) -> void:
	HintLabel = hintLabelInput

## Restores the level to its starting state.
## [b]Virtual — every subclass must override this.[/b]
func level_reset() -> void:
	assert(false, "Error, game_map_scene.gd level_reset(), not implemented by subclass yet")

## Compiles [param code_text] and performs the resulting actions.
## [b]Virtual — every subclass must override this.[/b]
## Subclass implementations maybe be coroutines (they may use [code]await[/code]);
## callers that need to sequence logic after execution must [code]await[/code] them.
func execute_code(code_text: String) -> void:
	assert(false, "Error, game_map_scene.gd execute_code(), not implemented by subclass yet")

func stop_code() -> void:
	compiler.cancel()


## increase [member current_hint_index] and displays the next hint in [member HintLabel].
## Requires [member HintLabel] to be set via [method setup].
func refresh_hint() -> void:
	assert(HintLabel != null, "HintLabel Not Initialized/ missing")
	
	# show the next hint in the list to the player
	current_hint_index += 1
	current_hint_index %= len(hints)
	
	HintLabel.text = hints[current_hint_index]
