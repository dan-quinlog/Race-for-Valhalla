extends Control
## Rhythm Lab: the test bench for the heartbeat and the one-action-per-beat
## prototype (TurnInput), with a training yard (SparringRules) to try the
## actions on.
##
## Each beat takes one input, judged on its first press, and resolves at the
## dum. A direction moves (or attacks a foe there). Two neighbouring
## directions together cast the corner rune between them.
## Bindings:
## - Directions on both sets: WASD, the arrows, the d-pad and the face
##   buttons all move, and runes come from chords (or the touch corners).
## - Rune buttons: WASD / arrows / d-pad move, and Q/E/Z/C or the face
##   buttons cast runes directly (chords still work).
## P1 is WASD (+ Q/E/Z/C) and gamepad 1, P2 the arrows and gamepad 2. In
## single-player mode every input set drives P1.

enum Binding { DIRECTIONS, RUNE_BUTTONS }

const STAGE_SCENE: String = "res://scenes/stage.tscn"
const LOG_LENGTH: int = 7
const DIR_HINTS_P1: Array[String] = ["W", "S", "A", "D"]
const DIR_HINTS_P2: Array[String] = ["↑", "↓", "←", "→"]
const DIR_HINTS_SOLO: Array[String] = ["W / ↑", "S / ↓", "A / ←", "D / →"]
const RUNE_HINTS_KEYS: Array[String] = ["Q", "E", "Z", "C"]
const RUNE_HINTS_CHORD_P1: Array[String] = ["W+A", "W+D", "S+A", "S+D"]
const RUNE_HINTS_CHORD_P2: Array[String] = ["↑+←", "↑+→", "↓+←", "↓+→"]
const NO_HINTS: Array[String] = ["", "", "", ""]
const HELP: String = "One input per beat, resolved at the dum. A direction moves you, or attacks a foe standing there. Two neighbouring directions together cast the rune between them: ↖ Prayer, ↗ Heavy, ↙ Trip, ↘ Flourish."

var two_players: bool = false
var binding: Binding = Binding.RUNE_BUTTONS
var shields: bool = true
var yard: SparringRules.Yard = SparringRules.Yard.SPARRING
var rules: SparringRules
var log_lines: Array[String] = []

@onready var _clock: BeatClock = %BeatClock
@onready var _ekg: EkgDisplay = %Ekg
@onready var _arena: SparringView = %Arena
@onready var _log: Label = %YardLog
@onready var _help: Label = %Help
@onready var _bpm: SpinBox = %Bpm
@onready var _window_ms: SpinBox = %WindowMs
@onready var _perfect_ms: SpinBox = %PerfectMs
@onready var _latency_ms: SpinBox = %LatencyMs
@onready var _binding: OptionButton = %Binding
@onready var _shield_toggle: CheckButton = %Shield
@onready var _yard: OptionButton = %Yard
@onready var _wide_toggle: CheckButton = %WideView
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
	_binding.item_selected.connect(_on_binding_selected)
	_shield_toggle.toggled.connect(set_shields)
	_yard.item_selected.connect(_on_yard_selected)
	_wide_toggle.toggled.connect(set_wide_view)
	%RestartButton.pressed.connect(restart)
	%StageButton.pressed.connect(open_stage)
	_two_players_toggle.toggled.connect(set_two_players)
	_two_players_toggle.visible = not OS.has_feature("mobile")
	_help.text = HELP
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
		p.configure(_clock.period, window, perfect)
	_ekg.configure(_clock.period, window, window, perfect)
	rules = SparringRules.new(2 if two_players else 1, shields, yard)
	rules.logged.connect(_on_logged)
	_arena.rules = rules
	_arena.beat_index = -1
	log_lines.clear()
	_log.text = ""
	_refresh_status()
	for box: SpinBox in [_bpm, _window_ms, _perfect_ms, _latency_ms]:
		box.get_line_edit().release_focus()


func set_two_players(on: bool) -> void:
	two_players = on
	panels[1].visible = on
	if _two_players_toggle.button_pressed != on:
		_two_players_toggle.set_pressed_no_signal(on)
	_refresh_hints()
	restart()


func set_binding(b: Binding) -> void:
	binding = b
	if _binding.selected != b:
		_binding.select(b)
	_refresh_hints()


func set_shields(on: bool) -> void:
	shields = on
	if _shield_toggle.button_pressed != on:
		_shield_toggle.set_pressed_no_signal(on)
	restart()


## Which training yard to fight in: the sparring foes, or the boss.
func set_yard(y: SparringRules.Yard) -> void:
	yard = y
	if _yard.selected != y:
		_yard.select(y)
	restart()


## Side-view yards: always show the whole yard (players feel small) instead
## of the camera following the heroes and zooming out as they spread.
func set_wide_view(on: bool) -> void:
	_arena.always_wide = on
	if _wide_toggle.button_pressed != on:
		_wide_toggle.set_pressed_no_signal(on)


func _on_yard_selected(index: int) -> void:
	set_yard(index as SparringRules.Yard)


func _refresh_hints() -> void:
	var runes_on_keys: bool = binding == Binding.RUNE_BUTTONS
	if two_players:
		panels[0].set_hints(DIR_HINTS_P1, RUNE_HINTS_KEYS if runes_on_keys else RUNE_HINTS_CHORD_P1)
		panels[1].set_hints(DIR_HINTS_P2, RUNE_HINTS_CHORD_P2)
	else:
		panels[0].set_hints(DIR_HINTS_SOLO, RUNE_HINTS_KEYS if runes_on_keys else RUNE_HINTS_CHORD_P1)
		panels[1].set_hints(DIR_HINTS_P2, NO_HINTS)


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
	var t: float = _clock.input_time()
	for ip: int in 2:
		if binding == Binding.RUNE_BUTTONS:
			for k: RuneCorner.Kind in RuneCorner.ALL:
				if event.is_action_pressed(RuneCorner.action_name(ip, k)):
					press_rune(ip, k, t)
					get_viewport().set_input_as_handled()
					return
		for d: Rune.Dir in Rune.ALL:
			if event.is_action_pressed(Rune.action_name(ip, d)):
				press_dir(ip, d, t)
				get_viewport().set_input_as_handled()
				return


func press_dir(input_player: int, d: Rune.Dir, t: float) -> void:
	panels[panel_for_input(input_player)].press_dir(d, t)


func press_rune(input_player: int, k: RuneCorner.Kind, t: float) -> void:
	panels[panel_for_input(input_player)].press_rune(k, t)


func _on_beat(index: int) -> void:
	_arena.on_beat(index)


## The dum: each player's action for the beat resolves, then the dummies act.
func _on_beat_closed(index: int) -> void:
	for p: int in panels.size():
		if p == 0 or two_players:
			panels[p].close_beat(index)
	rules.end_turn(index)
	_refresh_status()


func _on_acted(action: TurnAction, player: int) -> void:
	rules.act(player, action)


func _refresh_status() -> void:
	for h: SparringRules.Fighter in rules.heroes:
		var bits: Array[String] = ["Glory %d" % h.glory, "HP %d" % h.hp]
		if h.blessed:
			bits.append("Blessed")
		if h.charge > 0:
			bits.append("Heavy x%d" % h.charge)
		panels[h.player].set_status("   ".join(bits))


func _on_judged(t: float, grade: BeatJudge.Grade, player: int) -> void:
	_ekg.add_marker(t, grade, player)


func _on_logged(text: String) -> void:
	log_lines.push_front(text)
	if log_lines.size() > LOG_LENGTH:
		log_lines.pop_back()
	_log.text = "\n".join(log_lines)


func _on_binding_selected(index: int) -> void:
	set_binding(index as Binding)


func _on_setting_changed(_value: float) -> void:
	restart()
