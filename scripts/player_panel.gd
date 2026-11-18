class_name PlayerPanel
extends VBoxContainer
## One player's rune pad and readout: judgment, combo, last action, glory,
## blessings, and a short action log.

signal judged(t: float, grade: BeatJudge.Grade, player: int)
signal acted(action: RuneAction, player: int)

const LOG_LENGTH: int = 5

@export var player_index: int = 0

var clock: BeatClock
var rhythm: PlayerRhythm
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


func configure(period: float, window: float, perfect_window: float) -> void:
	if rhythm == null:
		rhythm = PlayerRhythm.new(period, window, perfect_window)
	else:
		rhythm.configure(period, window, perfect_window)
	log_lines.clear()
	_pad.clear_pending()
	_judgment.text = "Press on the beat"
	_action.text = ""
	_refresh()


func set_key_hints(hints: Array[String]) -> void:
	_pad.set_key_hints(hints)


func submit(rune: Rune.Dir, t: float) -> PlayerRhythm.Result:
	var r: PlayerRhythm.Result = rhythm.submit(rune, t)
	_pad.flash(rune, r.judgment.grade)
	_judgment.text = describe(r.judgment)
	if r.started_command:
		_pad.show_pending(rune)
		_action.text = "%s..." % Rune.ROLES[rune]
	elif r.action != null:
		_pad.clear_pending()
		_action.text = r.action.describe()
		log_lines.push_front(_action.text)
		if log_lines.size() > LOG_LENGTH:
			log_lines.pop_back()
		acted.emit(r.action, player_index)
	judged.emit(t, r.judgment.grade, player_index)
	_refresh()
	return r


func on_beat(beat: int) -> void:
	if rhythm != null and rhythm.reader.on_beat(beat):
		_pad.clear_pending()
		_action.text = "(command dropped: beat skipped)"


static func describe(j: BeatJudge.Judgment) -> String:
	var ms: int = roundi(j.offset * 1000.0)
	match j.grade:
		BeatJudge.Grade.PERFECT:
			return "PERFECT (%+d ms)" % ms
		BeatJudge.Grade.GOOD:
			return "GOOD (%+d ms %s)" % [ms, "early" if ms < 0 else "late"]
		_:
			if j.duplicate:
				return "MISS: one rune per beat"
			return "MISS (%+d ms)" % ms


func _refresh() -> void:
	var combo: ComboTracker = rhythm.combo
	_combo.text = "Combo %d (best %d)   P %d  G %d  M %d" % [
		combo.combo, combo.best, combo.perfects, combo.goods, combo.misses]
	var blessed: Array[String] = []
	for d: Rune.Dir in Rune.ALL:
		if rhythm.reader.blessings[d]:
			blessed.append(Rune.ROLES[d])
	_status.text = "Glory %d   Blessed: %s" % [
		rhythm.reader.glory, ", ".join(blessed) if not blessed.is_empty() else "none"]
	_log.text = "\n".join(log_lines)


func _on_pad_pressed(d: Rune.Dir) -> void:
	if clock != null:
		submit(d, clock.input_time())
