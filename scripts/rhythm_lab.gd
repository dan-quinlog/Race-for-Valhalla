extends Control
## Rhythm Lab: the test bench for the heartbeat and the one-action-per-beat
## prototype (TurnInput), with a training yard (SparringRules) to try the
## actions on.
##
## Each beat takes one rune press, judged on the buh. The direction locks at
## the dum, when the turn resolves. Input styles:
## - Touch: press a rune button and drag onto a direction (a tap uses the
##   rune's own direction).
## - Chord (keyboard or gamepad): press a rune (arrow keys or I/J/K/L, or the
##   face buttons) and hold a direction (WASD, or the d-pad). P2 is gamepad 2.
## - Gallop (keyboard, an option): the rune key on the buh, then a direction
##   key before the dum, on the same four keys. P1 WASD, P2 the arrows, so
##   two players can share a keyboard. Gamepads always use chord.
## Heavy charges in either HOLD or REPEAT mode (see TurnInput).
## In single-player mode every input set drives P1.

enum KeyStyle { CHORD, GALLOP }

const STAGE_SCENE: String = "res://scenes/stage.tscn"
const LOG_LENGTH: int = 6
const CHORD_HINTS: Array[String] = ["↑ / I", "↓ / K", "← / J", "→ / L"]
const GALLOP_HINTS_P1: Array[String] = ["W", "S", "A", "D"]
const GALLOP_HINTS_P2: Array[String] = ["↑", "↓", "←", "→"]
const GALLOP_HINTS_SOLO: Array[String] = ["W / ↑", "S / ↓", "A / ←", "D / →"]
const PAD_HINTS: Array[String] = ["pad", "pad", "pad", "pad"]
const HELP_CHORD: String = "Chord: press a rune (arrows or IJKL / face buttons) on the beat and hold a direction (WASD / d-pad). A rune alone uses its own direction. Touch: press a rune and drag."
const HELP_GALLOP: String = "Gallop: rune key on the buh, direction key before the dum (P1 WASD, P2 arrows). A rune alone uses its own direction. Touch: press a rune and drag."

var two_players: bool = false
var key_style: KeyStyle = KeyStyle.CHORD
var charge_mode: TurnInput.ChargeMode = TurnInput.ChargeMode.HOLD
var rules: SparringRules
var log_lines: Array[String] = []
## Per panel: the chord direction held down (-1 for none).
var _held_dir: Array[int] = [-1, -1]
## Per panel: the gallop key held as the press (-1 for none).
var _gallop_key: Array[int] = [-1, -1]

@onready var _clock: BeatClock = %BeatClock
@onready var _ekg: EkgDisplay = %Ekg
@onready var _arena: SparringView = %Arena
@onready var _log: Label = %YardLog
@onready var _help: Label = %Help
@onready var _bpm: SpinBox = %Bpm
@onready var _window_ms: SpinBox = %WindowMs
@onready var _perfect_ms: SpinBox = %PerfectMs
@onready var _latency_ms: SpinBox = %LatencyMs
@onready var _key_style: OptionButton = %KeyStyle
@onready var _charge_mode: OptionButton = %ChargeMode
@onready var _two_players_toggle: CheckButton = %TwoPlayers
@onready var panels: Array[TurnPanel] = [%Player1, %Player2]


func _ready() -> void:
	for p: TurnPanel in panels:
		p.clock = _clock
		p.judged.connect(_on_judged)
		p.acted.connect(_on_acted)
	_clock.beat.connect(_on_beat)
	_clock.beat_closed.connect(_on_beat_closed)
	for box: SpinBox in [_bpm, _window_ms, _perfect_ms, _latency_ms]:
		box.value_changed.connect(_on_setting_changed)
	_key_style.item_selected.connect(func(i: int) -> void: set_key_style(i as KeyStyle))
	_charge_mode.item_selected.connect(func(i: int) -> void: set_charge_mode(i as TurnInput.ChargeMode))
	%RestartButton.pressed.connect(restart)
	%StageButton.pressed.connect(open_stage)
	_two_players_toggle.toggled.connect(set_two_players)
	_two_players_toggle.visible = not OS.has_feature("mobile")
	set_two_players(false)


func restart() -> void:
	_clock.bpm = _bpm.value
	var period: float = HeartbeatAudio.actual_period(60.0 / _clock.bpm)
	# Keep neighbouring beats' windows from overlapping, and Perfect inside the window.
	var window: float = minf(_window_ms.value / 1000.0, period * 0.5 - 0.01)
	var perfect: float = minf(_perfect_ms.value / 1000.0, window)
	_clock.dum_delay = window
	_clock.input_latency = _latency_ms.value / 1000.0
	_clock.start()
	for p: TurnPanel in panels:
		p.configure(_clock.period, window, perfect, charge_mode)
	_ekg.configure(_clock.period, window, window, perfect)
	rules = SparringRules.new(2 if two_players else 1)
	rules.logged.connect(_on_logged)
	_arena.rules = rules
	_arena.beat_index = -1
	log_lines.clear()
	_log.text = ""
	_held_dir = [-1, -1]
	_gallop_key = [-1, -1]
	for box: SpinBox in [_bpm, _window_ms, _perfect_ms, _latency_ms]:
		box.get_line_edit().release_focus()


func set_two_players(on: bool) -> void:
	two_players = on
	panels[1].visible = on
	if _two_players_toggle.button_pressed != on:
		_two_players_toggle.set_pressed_no_signal(on)
	_refresh_hints()
	restart()


func set_key_style(style: KeyStyle) -> void:
	key_style = style
	if _key_style.selected != style:
		_key_style.select(style)
	_refresh_hints()
	restart()


func set_charge_mode(mode: TurnInput.ChargeMode) -> void:
	charge_mode = mode
	if _charge_mode.selected != mode:
		_charge_mode.select(mode)
	restart()


func _refresh_hints() -> void:
	if key_style == KeyStyle.CHORD:
		panels[0].set_key_hints(CHORD_HINTS)
		panels[1].set_key_hints(PAD_HINTS)
		_help.text = HELP_CHORD
	else:
		panels[0].set_key_hints(GALLOP_HINTS_P1 if two_players else GALLOP_HINTS_SOLO)
		panels[1].set_key_hints(GALLOP_HINTS_P2)
		_help.text = HELP_GALLOP


func open_stage() -> void:
	go_to_scene(STAGE_SCENE)


## Side-effect wrapper so tests can stub out scene changes.
func go_to_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


## Which panel an input set drives. Solo mode routes every set to P1.
func panel_for_input(input_player: int) -> int:
	return input_player if two_players else 0


func _process(_delta: float) -> void:
	_ekg.set_time(_clock.now())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and key_style == KeyStyle.GALLOP:
		for ip: int in 2:
			for d: Rune.Dir in Rune.ALL:
				var action: StringName = Rune.action_name(ip, d)
				if event.is_action_pressed(action) or event.is_action_released(action):
					gallop_key(ip, d, event.is_pressed(), _clock.input_time())
					get_viewport().set_input_as_handled()
					return
		return
	for ip: int in 2:
		for d: Rune.Dir in Rune.ALL:
			var rune_action := StringName("p%d_rune_%s" % [ip + 1, Rune.ACTION_SUFFIXES[d]])
			var dir_action := StringName("p%d_dir_%s" % [ip + 1, Rune.ACTION_SUFFIXES[d]])
			if event.is_action_pressed(rune_action) or event.is_action_released(rune_action):
				chord_rune(ip, d, event.is_pressed(), _clock.input_time())
			elif event.is_action_pressed(dir_action) or event.is_action_released(dir_action):
				chord_dir(ip, d, event.is_pressed())
			else:
				continue
			get_viewport().set_input_as_handled()
			return


## Chord: a rune button went down or up.
func chord_rune(input_player: int, d: Rune.Dir, down: bool, t: float) -> void:
	var p: int = panel_for_input(input_player)
	if not down:
		panels[p].release(t)
		return
	panels[p].press(d, t)
	if _held_dir[p] >= 0:
		panels[p].point(_held_dir[p] as Rune.Dir)


## Chord: a direction went down or up. The held direction steers the open press.
func chord_dir(input_player: int, d: Rune.Dir, down: bool) -> void:
	var p: int = panel_for_input(input_player)
	if down:
		_held_dir[p] = d
		panels[p].point(d)
	elif _held_dir[p] == d:
		_held_dir[p] = -1


## Gallop: the first key on a beat is the rune, a second key before the dum
## is the direction. A key just after the dum that was meant as a direction
## is ignored instead of counting as a missed press.
func gallop_key(input_player: int, d: Rune.Dir, down: bool, t: float) -> void:
	var p: int = panel_for_input(input_player)
	var input: TurnInput = panels[p].input
	if not down:
		if _gallop_key[p] == d:
			_gallop_key[p] = -1
			panels[p].release(t)
		return
	if input.rune != TurnInput.NO_RUNE:
		panels[p].point(d)
		_gallop_key[p] = d
		return
	if _is_late_direction(input, t):
		return
	panels[p].press(d, t)
	_gallop_key[p] = d


## True if `t` falls just after a beat's dum (within one window of it),
## where a gallop key is a late direction rather than a new press.
static func _is_late_direction(input: TurnInput, t: float) -> bool:
	var period: float = input.judge.period
	var window: float = input.judge.window
	var since_buh: float = fposmod(t, period)
	return since_buh > window and since_buh <= window * 2.0


func _on_beat(index: int) -> void:
	_arena.on_beat(index)


## The dum: each player's action for the beat resolves, then the dummies act.
func _on_beat_closed(index: int) -> void:
	for p: int in panels.size():
		if p == 0 or two_players:
			panels[p].close_beat(index)
	rules.end_turn(index)


func _on_acted(action: RuneAction, player: int) -> void:
	rules.act(player, action)


func _on_judged(t: float, grade: BeatJudge.Grade, player: int) -> void:
	_ekg.add_marker(t, grade, player)


func _on_logged(text: String) -> void:
	log_lines.push_front(text)
	if log_lines.size() > LOG_LENGTH:
		log_lines.pop_back()
	_log.text = "\n".join(log_lines)


func _on_setting_changed(_value: float) -> void:
	restart()
