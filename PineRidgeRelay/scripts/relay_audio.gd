class_name RelayAudio
extends Node3D
## Routes world sounds to position-aware voices and local damage to a separate channel.

enum Cue { ROCK, BLADE, SWING, REPORT, FOOTSTEP }

const CLIPS := [
	[preload("res://assets/audio/rock_1.wav"), preload("res://assets/audio/rock_2.wav"), preload("res://assets/audio/rock_3.wav")],
	[preload("res://assets/audio/blade_hit_1.wav"), preload("res://assets/audio/blade_hit_2.wav")],
	[preload("res://assets/audio/swing_1.wav"), preload("res://assets/audio/swing_2.wav")],
	[preload("res://assets/audio/report.wav")],
	[preload("res://assets/audio/step_1.wav"), preload("res://assets/audio/step_2.wav"), preload("res://assets/audio/step_3.wav")],
]
const HURT := [preload("res://assets/audio/hurt_1.wav"), preload("res://assets/audio/hurt_2.wav")]
const LEVELS := [-4.0, -3.0, -8.0, -2.0, -10.0]
const VOICE_COUNT := 10

var _voices: Array[AudioStreamPlayer3D] = []
var _local_hit := AudioStreamPlayer.new()


func _ready() -> void:
	add_child(_local_hit)
	_local_hit.volume_db = -5.0
	for i in range(VOICE_COUNT):
		var voice := AudioStreamPlayer3D.new()
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.max_db = 0.0
		add_child(voice)
		_voices.append(voice)


func play_at(cue: Cue, point: Vector3, gain := 0.0) -> void:
	# Footsteps use their own channel so quick strides cannot crowd out impacts.
	if cue == Cue.FOOTSTEP:
		_play_voice(_voices[0], cue, point, gain)
		return
	for i in range(1, _voices.size()):
		if not _voices[i].playing:
			_play_voice(_voices[i], cue, point, gain)
			return


func _play_voice(voice: AudioStreamPlayer3D, cue: Cue, point: Vector3, gain: float) -> void:
	voice.global_position = point
	voice.stream = CLIPS[cue].pick_random()
	voice.volume_db = LEVELS[cue] + gain
	voice.pitch_scale = randf_range(0.91, 1.08)
	var carries := cue == Cue.REPORT
	voice.unit_size = 4.0 if carries else 2.4
	voice.max_distance = 24.0 if carries else 17.0
	voice.play()


func play_damage() -> void:
	_local_hit.stream = HURT.pick_random()
	_local_hit.pitch_scale = randf_range(0.94, 1.05)
	_local_hit.play()


func _exit_tree() -> void:
	_local_hit.stop()
	for voice in _voices:
		voice.stop()
