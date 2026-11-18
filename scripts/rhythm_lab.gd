extends Control
## Rhythm Lab: a test bench for the heartbeat and rune commands.
## P1 uses WASD, P2 the arrow keys, and gamepads 1 and 2 their own pads.
## In single-player mode every input set drives P1. Mobile is single-player
## with on-screen rune pads only.

const FIGHT_SCENE: String = "res://scenes/fight.tscn"
const KEY_HINTS_P1: Array[String] = ["W", "S", "A", "D"]
const KEY_HINTS_P2: Array[String] = ["↑", "↓", "←", "→"]
const KEY_HINTS_SOLO: Array[String] = ["W / ↑", "S / ↓", "A / ←", "D / →"]

var two_players: bool = false

@onready var _clock: BeatClock = %BeatClock
@onready var _ekg: EkgDisplay = %Ekg
@onready var _bpm: SpinBox = %Bpm
@onready var _window_ms: SpinBox = %WindowMs
@onready var _perfect_ms: SpinBox = %PerfectMs
@onready var _latency_ms: SpinBox = %LatencyMs
@onready var _two_players_toggle: CheckButton = %TwoPlayers
@onready var panels: Array[PlayerPanel] = [%Player1, %Player2]


func _ready() -> void:
	for p: PlayerPanel in panels:
		p.clock = _clock
		p.judged.connect(_on_judged)
	_clock.beat.connect(_on_beat)
	for box: SpinBox in [_bpm, _window_ms, _perfect_ms, _latency_ms]:
		box.value_changed.connect(_on_setting_changed)
	%RestartButton.pressed.connect(restart)
	%FightButton.pressed.connect(open_fight)
	_two_players_toggle.toggled.connect(set_two_players)
	_two_players_toggle.visible = not OS.has_feature("mobile")
	set_two_players(false)
	restart()


func restart() -> void:
	_clock.bpm = _bpm.value
	var period: float = HeartbeatAudio.actual_period(60.0 / _clock.bpm)
	# Keep neighbouring beats' windows from overlapping, and Perfect inside the window.
	var window: float = minf(_window_ms.value / 1000.0, period * 0.5 - 0.01)
	var perfect: float = minf(_perfect_ms.value / 1000.0, window)
	_clock.dum_delay = window
	_clock.input_latency = _latency_ms.value / 1000.0
	_clock.start()
	for p: PlayerPanel in panels:
		p.configure(_clock.period, window, perfect)
	_ekg.configure(_clock.period, window, window, perfect)
	for box: SpinBox in [_bpm, _window_ms, _perfect_ms, _latency_ms]:
		box.get_line_edit().release_focus()


func set_two_players(on: bool) -> void:
	two_players = on
	panels[1].visible = on
	panels[0].set_key_hints(KEY_HINTS_P1 if on else KEY_HINTS_SOLO)
	panels[1].set_key_hints(KEY_HINTS_P2)
	if _two_players_toggle.button_pressed != on:
		_two_players_toggle.set_pressed_no_signal(on)


func open_fight() -> void:
	go_to_scene(FIGHT_SCENE)


## Side-effect wrapper so tests can stub out scene changes.
func go_to_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


## Which panel an input set drives. Solo mode routes every set to P1.
func panel_for_input(input_player: int) -> int:
	return input_player if two_players else 0


func _process(_delta: float) -> void:
	_ekg.set_time(_clock.now())


func _unhandled_input(event: InputEvent) -> void:
	for input_player: int in 2:
		for d: Rune.Dir in Rune.ALL:
			if event.is_action_pressed(Rune.action_name(input_player, d)):
				panels[panel_for_input(input_player)].submit(d, _clock.input_time())
				get_viewport().set_input_as_handled()
				return


func _on_beat(index: int) -> void:
	for p: PlayerPanel in panels:
		p.on_beat(index)


func _on_judged(t: float, grade: BeatJudge.Grade, player: int) -> void:
	_ekg.add_marker(t, grade, player)


func _on_setting_changed(_value: float) -> void:
	restart()
