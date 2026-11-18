class_name ComboTracker
extends RefCounted
## Counts the current combo and per-grade totals. A miss breaks the combo.

var combo: int = 0
var best: int = 0
var perfects: int = 0
var goods: int = 0
var misses: int = 0


func record(grade: BeatJudge.Grade) -> void:
	match grade:
		BeatJudge.Grade.PERFECT:
			perfects += 1
			combo += 1
		BeatJudge.Grade.GOOD:
			goods += 1
			combo += 1
		BeatJudge.Grade.MISS:
			misses += 1
			combo = 0
	best = maxi(best, combo)


func reset() -> void:
	combo = 0
	best = 0
	perfects = 0
	goods = 0
	misses = 0
