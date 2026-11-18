extends GutTest

var combo: ComboTracker


func before_each() -> void:
	combo = ComboTracker.new()


func test_hits_build_combo() -> void:
	combo.record(BeatJudge.Grade.PERFECT)
	combo.record(BeatJudge.Grade.GOOD)
	assert_eq(combo.combo, 2)
	assert_eq(combo.perfects, 1)
	assert_eq(combo.goods, 1)


func test_miss_breaks_combo_but_keeps_best() -> void:
	for i: int in 3:
		combo.record(BeatJudge.Grade.GOOD)
	combo.record(BeatJudge.Grade.MISS)
	combo.record(BeatJudge.Grade.PERFECT)
	assert_eq(combo.combo, 1)
	assert_eq(combo.best, 3)
	assert_eq(combo.misses, 1)


func test_reset_clears_everything() -> void:
	combo.record(BeatJudge.Grade.PERFECT)
	combo.record(BeatJudge.Grade.MISS)
	combo.reset()
	assert_eq(combo.combo, 0)
	assert_eq(combo.best, 0)
	assert_eq(combo.perfects, 0)
	assert_eq(combo.misses, 0)
