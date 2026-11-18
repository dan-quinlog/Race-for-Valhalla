class_name BeatJudge
extends RefCounted
## Grades rune inputs against the heartbeat.
##
## The "buh" of beat n is at n * period seconds. Inputs count from
## (buh - window) through (buh + window), where window is the buh-to-dum gap
## mirrored ahead of the buh. The dum is the cut-off. Each beat takes one rune,
## so a second input on a beat that already took one is a miss.

enum Grade { MISS, GOOD, PERFECT }

const _NO_BEAT: int = -(1 << 62)


class Judgment:
	var grade: BeatJudge.Grade
	## Nearest beat index to the input.
	var beat: int
	## Seconds from that beat's buh. Negative is early, positive is late.
	var offset: float
	## True when this was a second input on a beat that already took a rune.
	var duplicate: bool

	func _init(p_grade: BeatJudge.Grade, p_beat: int, p_offset: float, p_duplicate: bool = false) -> void:
		grade = p_grade
		beat = p_beat
		offset = p_offset
		duplicate = p_duplicate


var period: float
var window: float
var perfect_window: float

var _last_claimed_beat: int = _NO_BEAT


func _init(p_period: float, p_window: float, p_perfect_window: float) -> void:
	assert(p_period > 0.0, "period must be positive")
	assert(p_window * 2.0 < p_period, "windows of neighbouring beats must not overlap")
	assert(p_perfect_window <= p_window, "perfect window must fit inside the hit window")
	period = p_period
	window = p_window
	perfect_window = p_perfect_window


func judge(time: float) -> Judgment:
	var beat: int = roundi(time / period)
	var offset: float = time - beat * period
	if absf(offset) > window:
		return Judgment.new(Grade.MISS, beat, offset)
	if beat == _last_claimed_beat:
		return Judgment.new(Grade.MISS, beat, offset, true)
	_last_claimed_beat = beat
	var grade: Grade = Grade.PERFECT if absf(offset) <= perfect_window else Grade.GOOD
	return Judgment.new(grade, beat, offset)


func reset() -> void:
	_last_claimed_beat = _NO_BEAT
