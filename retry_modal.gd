class_name RetryModal
extends Control

@onready var header_label: Label = %HeaderLabel
@onready var message_label: Label = %MessageLabel
@onready var retry_button: Button = %RetryButton

## any node using this ConfirmationModal can use this confirmed signal to decide action
signal confirmed

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	retry_button.pressed.connect(
		_on_retry_button_pressed
	)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func set_up(
	header_text: String, 
	message_text: String, 
	retry_button_text: String
	) -> void:
	header_label.text = header_text
	message_label.text = message_text
	retry_button.text = retry_button_text

## external node uses this functionto set the retry button text
func set_message_text(message: String) -> void:
	message_label.text = message

func _on_retry_button_pressed() -> void:
	AudioManager.play_click()
	confirmed.emit()
