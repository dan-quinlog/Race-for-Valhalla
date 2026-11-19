class_name PlayerPanel
extends VBoxContainer
## One player's rune pad and readout: judgment, combo, last action, glory,
## blessings, and a short action log.

signal judged(t: float, grade: BeatJudge.Grade, player: int)
signal acted(action: RuneAction, player: int)
## A fallen player's final strike rune, accepted on their final beat.
signal final_struck(dir: Rune.Dir, beat: int, perfect: bool, blessed: bool, player: int)

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
	_pad.clear_final()
	_judgment.text = "Press on the beat"
	_action.text = ""
	_refresh()


func set_key_hints(hints: Array[String]) -> void:
	_pad.set_key_hints(hints)


## Labels like "Throw 30" for each final strike, and the strongest one.
static func final_labels(damage: Array[int]) -> Array[String]:
	var out: Array[String] = []
	for d: Rune.Dir in Rune.ALL:
		out.append("%s %d" % [StageRules.FINAL_NAMES[d], damage[d]])
	return out


static func best_final(damage: Array[int]) -> int:
	var best: int = Rune.Dir.DOWN
	for d: Rune.Dir in Rune.ALL:
		if damage[d] > damage[best]:
			best = d
	return best


## The hero fell. The pad shows the final strikes with their damage until
## the final beat.
func begin_final(final_beat: int, damage: Array[int]) -> void:
	rhythm.begin_final(final_beat)
	update_final(damage)
	_action.text = "FALLEN! Final strike in %d" % StageRules.SILENT_BEATS
	_judgment.text = "Your heart falls silent..."


func update_final(damage: Array[int]) -> void:
	if rhythm.final_beat != Hero.NONE:
		_pad.show_final(final_labels(damage), best_final(damage))


func end_final() -> void:
	rhythm.mark_fallen()
	_pad.clear_final()
	_action.text = "Fallen. Valhalla awaits."


## For a hero who starts a stage already fallen.
func mark_fallen() -> void:
	rhythm.mark_fallen()
	_pad.clear_final()
	_action.text = "Fallen. Valhalla awaits."


func submit(rune: Rune.Dir, t: float) -> PlayerRhythm.Result:
	var r: PlayerRhythm.Result = rhythm.submit(rune, t)
	_pad.flash(rune, r.judgment.grade)
	if rhythm.fallen:
		if r.final_dir >= 0:
			_judgment.text = describe(r.judgment)
			_action.text = "Final %s!" % StageRules.FINAL_NAMES[r.final_dir]
			final_struck.emit(r.final_dir as Rune.Dir, r.judgment.beat, r.final_perfect, r.final_blessed, player_index)
		judged.emit(t, r.judgment.grade, player_index)
		return r
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
	if rhythm != null and rhythm.final_beat != Hero.NONE:
		var left: int = rhythm.final_beat - beat
		_action.text = "FINAL STRIKE NOW!" if left == 0 else "FALLEN! Final strike in %d" % left
		return
	if rhythm != null and rhythm.reader.on_beat(beat):
		_pad.clear_pending()
		_action.text = "Beat skipped: rune cleared, combo kept"


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
