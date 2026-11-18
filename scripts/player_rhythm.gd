class_name PlayerRhythm
extends RefCounted
## One player's rhythm state: timing judge, combo, and command reader.
## Every player shares the BeatClock but judges and reads commands separately.

class Result:
	var judgment: BeatJudge.Judgment
	## Completed action, or null (miss, or first rune of a command).
	var action: RuneAction
	## True if the rune was accepted and is now pending as a command's first rune.
	var started_command: bool = false


var judge: BeatJudge
var combo := ComboTracker.new()
var reader := CommandReader.new()


func _init(period: float, window: float, perfect_window: float) -> void:
	configure(period, window, perfect_window)


func configure(period: float, window: float, perfect_window: float) -> void:
	judge = BeatJudge.new(period, window, perfect_window)
	combo.reset()
	reader.reset()


## Judges a rune pressed at time t. A miss breaks the combo but leaves any
## pending command alone.
func submit(rune: Rune.Dir, t: float) -> Result:
	var r := Result.new()
	r.judgment = judge.judge(t)
	combo.record(r.judgment.grade)
	if r.judgment.grade != BeatJudge.Grade.MISS:
		r.action = reader.feed(rune, r.judgment.beat, r.judgment.grade == BeatJudge.Grade.PERFECT)
		r.started_command = r.action == null
	return r
