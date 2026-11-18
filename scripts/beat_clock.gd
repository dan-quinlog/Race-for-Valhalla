class_name BeatClock
extends Node
## Master heartbeat clock, locked to audio playback rather than frame time.
##
## `time` is in seconds since start() and matches what the player is hearing
## right now (output latency is subtracted). The buh of beat n is at n * period.
## `beat` fires on the buh. `beat_closed` fires at the dum, when beat n's input
## window has shut, so anything resolved there sees every input for that beat.

signal beat(index: int)
signal beat_closed(index: int)

@export var bpm: float = 90.0
## Gap between buh and dum, in seconds. This is also the input window half-width.
@export var dum_delay: float = 0.15
## Calibration: seconds subtracted from input timestamps. Positive means the
## player's inputs register late (input or display lag).
@export var input_latency: float = 0.0

var period: float = 1.0
var time: float = 0.0
var running: bool = false

var _player: AudioStreamPlayer
var _loops: int = 0
var _last_raw_pos: float = 0.0
var _last_beat: int = -1
var _last_closed: int = -1


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "HeartbeatPlayer"
	add_child(_player)


func _exit_tree() -> void:
	# Silence the heartbeat when the clock leaves (scene change). At engine
	# shutdown Godot still reports a looping stream's playback as leaked; that
	# warning is harmless and happens even with a bare AudioStreamPlayer.
	stop()


func start() -> void:
	period = HeartbeatAudio.actual_period(60.0 / bpm)
	_player.stream = HeartbeatAudio.build_loop(period, dum_delay)
	_loops = 0
	_last_raw_pos = 0.0
	_last_beat = -1
	_last_closed = -1
	time = 0.0
	running = true
	play_audio()


func stop() -> void:
	running = false
	_player.stop()


## Side-effect wrapper so tests can stub out playback.
func play_audio() -> void:
	_player.play()


## Current audio-aligned time, sampled now (not just once per frame).
func now() -> float:
	if not running or not _player.playing:
		return time
	var compensation: float = AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return advance(_player.get_playback_position(), compensation)


## Timestamp to judge an input pressed now.
func input_time() -> float:
	return now() - input_latency


## Feeds a raw loop position into the clock. Detects loop wraps and keeps
## time from going backwards (playback position only updates per mix chunk).
func advance(raw_pos: float, compensation: float) -> float:
	if raw_pos < _last_raw_pos - period * 0.5:
		_loops += 1
	_last_raw_pos = raw_pos
	time = maxf(time, _loops * period + raw_pos + compensation)
	return time


func emit_due_beats() -> void:
	var current: int = floori(time / period)
	while _last_beat < current:
		_last_beat += 1
		beat.emit(_last_beat)
	var closed: int = floori((time - dum_delay) / period)
	while _last_closed < closed:
		_last_closed += 1
		beat_closed.emit(_last_closed)


func _process(_delta: float) -> void:
	if running:
		now()
		emit_due_beats()
