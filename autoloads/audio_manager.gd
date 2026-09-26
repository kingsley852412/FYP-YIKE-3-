extends Node

var active_music_stream: AudioStreamPlayer

@export_group("Title_bgm")
@export var music: Node
@export var se: Node
@export var sound_effect_scene: PackedScene
@export var click: AudioStream
@export var rescue: AudioStream
@export var robot_walk: AudioStream



func play_music(audio_name: String, from_position: float = 0.0, restart: bool = false) -> void:
	if restart and active_music_stream and active_music_stream.name == audio_name:
		return
	if active_music_stream and active_music_stream.name != audio_name:
		active_music_stream.stop()
	active_music_stream = music.get_node(audio_name)
	active_music_stream.play(from_position)

func play_audio_once(audio_stream: AudioStream, volume_db: float = 0.0, from_position: float = 0.0) -> SoundEffect:
	var sound_effect: SoundEffect = sound_effect_scene.instantiate()
	sound_effect.stream = audio_stream
	sound_effect.volume_db = volume_db
	sound_effect.from_position = from_position
	
	se.add_child(sound_effect)
	return sound_effect
	
func play_click() -> void:
	play_audio_once(click, 0, 0.02)
	
func play_rescue() -> void:
	play_audio_once(rescue, 0, 0)
	
func play_robot_walk() -> void:
	play_audio_once(robot_walk, 0, 0.02)
	
