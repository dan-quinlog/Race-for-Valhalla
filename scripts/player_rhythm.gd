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
	## A fallen hero's final strike rune (Rune.Dir), or -1.
	var final_dir: int = -1
	var final_perfect: bool = false
	## An unspent Attack blessing powers up the final strike.
	var final_blessed: bool = false


var judge: BeatJudge
var combo := ComboTracker.new()
var reader := CommandReader.new()
## The hero has fallen. Runes no longer make commands.
var fallen: bool = false
## Beat of a pending final strike, or Hero.NONE.
var final_beat: int = Hero.NONE


func _init(period: float, window: float, perfect_window: float) -> void:
	configure(period, window, perfect_window)


func configure(period: float, window: float, perfect_window: float) -> void:
	judge = BeatJudge.new(period, window, perfect_window)
	combo.reset()
	reader.reset()
	fallen = false
	final_beat = Hero.NONE


## The hero fell: from now on runes are ignored, except one accepted rune
## on `beat`, which becomes the final strike.
func begin_final(beat: int) -> void:
	fallen = true
	final_beat = beat
	reader.pending = CommandReader.NO_RUNE


func mark_fallen() -> void:
	fallen = true
	final_beat = Hero.NONE
	reader.pending = CommandReader.NO_RUNE


## Judges a rune pressed at time t. A miss breaks the combo but leaves any
## pending command alone.
func submit(rune: Rune.Dir, t: float) -> Result:
	var r := Result.new()
	r.judgment = judge.judge(t)
	if fallen:
		if final_beat != Hero.NONE and r.judgment.grade != BeatJudge.Grade.MISS and r.judgment.beat == final_beat:
			r.final_dir = rune
			r.final_perfect = r.judgment.grade == BeatJudge.Grade.PERFECT
			r.final_blessed = reader.blessings[Rune.Dir.LEFT]
			reader.blessings[Rune.Dir.LEFT] = false
			final_beat = Hero.NONE
		return r
	combo.record(r.judgment.grade)
	if r.judgment.grade != BeatJudge.Grade.MISS:
		r.action = reader.feed(rune, r.judgment.beat, r.judgment.grade == BeatJudge.Grade.PERFECT)
		r.started_command = r.action == null
	return r
