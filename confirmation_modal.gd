class_name ConfirmationModal
extends Control

@onready var header_label: Label = %HeaderLabel
@onready var message_label: Label = %MessageLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton

## any node using this ConfirmationModal can use this confirmed signal to decide action
signal confirmed(is_confirmed: bool)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	confirm_button.pressed.connect(
		confirmed.emit.bind(true)
	)
	cancel_button.pressed.connect(
		confirmed.emit.bind(false)
	)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func set_up(
	header_text: String, 
	message_text: String, 
	confirm_button_text: String, 
	cancel_button_text: String
	) -> void:
	header_label.text = header_text
	message_label.text = message_text
	confirm_button.text = confirm_button_text
	cancel_button.text = cancel_button_text
