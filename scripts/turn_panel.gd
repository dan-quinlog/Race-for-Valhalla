class_name TurnPanel
extends VBoxContainer
## One player's direction pad and readout for the one-action-per-beat
## prototype (TurnInput): judgment, combo, the action just taken, a status
## line the lab fills in (glory, blessing, charge) and a short log.

signal judged(t: float, grade: BeatJudge.Grade, player: int)
signal acted(action: TurnAction, player: int)

const LOG_LENGTH: int = 5

@export var player_index: int = 0

var clock: BeatClock
var input: TurnInput
var log_lines: Array[String] = []

@onready var _pad: DirectionPad = %Pad
@onready var _title: Label = %Title
@onready var _judgment: Label = %JudgmentLabel
@onready var _combo: Label = %ComboLabel
@onready var _action: Label = %ActionLabel
@onready var _status: Label = %StatusLabel
@onready var _log: Label = %LogLabel


func _ready() -> void:
	_title.text = "Player %d" % (player_index + 1)
	_pad.set_center_text("P%d" % (player_index + 1))
	_pad.direction_pressed.connect(_on_pad_direction)
	_pad.rune_pressed.connect(_on_pad_rune)


func configure(period: float, window: float, perfect_window: float) -> void:
	if input == null:
		input = TurnInput.new(period, window, perfect_window)
	else:
		input.configure(period, window, perfect_window)
	log_lines.clear()
	_judgment.text = "Press on the beat"
	_action.text = ""
	_status.text = ""
	_refresh()


func set_hints(dirs: Array[String], runes: Array[String]) -> void:
	_pad.set_hints(dirs, runes)


func set_status(text: String) -> void:
	_status.text = text


func press_dir(d: Rune.Dir, t: float) -> void:
	var j: BeatJudge.Judgment = input.press_dir(d, t)
	if j == null:
		if input.rune >= 0:
			_pad.flash_rune(input.rune as RuneCorner.Kind, BeatJudge.Grade.GOOD)
		return
	_pad.flash_dir(d, j.grade)
	_judged(j, t)


func press_rune(k: RuneCorner.Kind, t: float) -> void:
	var j: BeatJudge.Judgment = input.press_rune(k, t)
	if j == null:
		return
	_pad.flash_rune(k, j.grade)
	_judged(j, t)


## Beat `n` closed: returns this player's action for it, or null.
func close_beat(n: int) -> TurnAction:
	return _finish(input.close_beat(n))


func _judged(j: BeatJudge.Judgment, t: float) -> void:
	_judgment.text = PlayerPanel.describe(j)
	judged.emit(t, j.grade, player_index)
	if input.is_late():
		_finish(input.resolve_late())
	_refresh()


func _finish(a: TurnAction) -> TurnAction:
	if a == null:
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
	_log.text = "\n".join(log_lines)


func _on_pad_direction(d: Rune.Dir) -> void:
	if clock != null:
		press_dir(d, clock.input_time())


func _on_pad_rune(k: RuneCorner.Kind) -> void:
	if clock != null:
		press_rune(k, clock.input_time())
