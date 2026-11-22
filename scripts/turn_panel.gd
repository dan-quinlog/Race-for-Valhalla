class_name TurnPanel
extends VBoxContainer
## One player's rune pad and readout for the one-action-per-beat prototype
## (TurnInput): judgment, combo, the action just taken, glory, blessings and
## a short log. Touch: press a rune and drag to a direction (a tap uses the
## rune's own direction). While a rune is held the pad lists what each
## direction would do and outlines the chosen one.

signal judged(t: float, grade: BeatJudge.Grade, player: int)
signal acted(action: RuneAction, player: int)

const LOG_LENGTH: int = 5

@export var player_index: int = 0

var clock: BeatClock
var input: TurnInput
var log_lines: Array[String] = []

@onready var _pad: RunePad = %RunePad
@onready var _title: Label = %Title
@onready var _judgment: Label = %JudgmentLabel
@onready var _combo: Label = %ComboLabel
@onready var _action: Label = %ActionLabel
@onready var _status: Label = %StatusLabel
@onready var _log: Label = %LogLabel


func _ready() -> void:
	_title.text = "Player %d" % (player_index + 1)
	_pad.set_center_text("P%d" % (player_index + 1))
	_pad.rune_pressed.connect(_on_pad_pressed)
	_pad.pointed.connect(point)
	_pad.released.connect(_on_pad_released)


func configure(period: float, window: float, perfect_window: float, mode: TurnInput.ChargeMode) -> void:
	if input == null:
		input = TurnInput.new(period, window, perfect_window, mode)
	else:
		input.configure(period, window, perfect_window, mode)
	log_lines.clear()
	_pad.clear_pending()
	_judgment.text = "Press on the beat"
	_action.text = ""
	_refresh()


func set_key_hints(hints: Array[String]) -> void:
	_pad.set_key_hints(hints)


## A rune pressed at time `t`. Returns an action if it resolved right away
## (a press that arrived after its beat had already closed).
func press(rune: Rune.Dir, t: float) -> RuneAction:
	var j: BeatJudge.Judgment = input.press(rune, t)
	_pad.flash(rune, j.grade)
	_judgment.text = PlayerPanel.describe(j)
	judged.emit(t, j.grade, player_index)
	var done: RuneAction = null
	if j.grade != BeatJudge.Grade.MISS:
		if input.press_fires_charge():
			_action.text = "Heavy released!"
		elif input.rune != TurnInput.NO_RUNE:
			_pad.show_pending(rune)
			_pad.show_pointed(rune)
			if input.is_late():
				done = _finish(input.resolve_late())
	_refresh()
	return done


## Points the held rune in direction `d`.
func point(d: Rune.Dir) -> void:
	input.point(d)
	if input.rune != TurnInput.NO_RUNE:
		_pad.show_pointed(input.direction)


func release(t: float) -> void:
	input.release(t)


## Beat `n` closed: returns the action this player takes on it, or null.
func close_beat(n: int) -> RuneAction:
	return _finish(input.close_beat(n))


func _finish(a: RuneAction) -> RuneAction:
	_pad.clear_pending()
	if input.charging:
		_pad.show_pending(Rune.Dir.LEFT)
		_pad.show_pointed(Rune.Dir.UP)
	if a == null:
		_refresh()
		return null
	_action.text = a.describe()
	log_lines.push_front(_action.text)
	if log_lines.size() > LOG_LENGTH:
		log_lines.pop_back()
	acted.emit(a, player_index)
	_refresh()
	return a


func _refresh() -> void:
	var combo: ComboTracker = input.combo
	_combo.text = "Combo %d (best %d)   P %d  G %d  M %d" % [
		combo.combo, combo.best, combo.perfects, combo.goods, combo.misses]
	var blessed: Array[String] = []
	for d: Rune.Dir in Rune.ALL:
		if input.blessings[d]:
			blessed.append(Rune.ROLES[d])
	_status.text = "Glory %d   Blessed: %s" % [
		input.glory, ", ".join(blessed) if not blessed.is_empty() else "none"]
	_log.text = "\n".join(log_lines)


func _on_pad_pressed(d: Rune.Dir) -> void:
	if clock != null:
		press(d, clock.input_time())


func _on_pad_released() -> void:
	if clock != null:
		release(clock.input_time())
