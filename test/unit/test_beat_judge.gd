extends GutTest

const PERIOD: float = 0.6
const WINDOW: float = 0.15
const PERFECT: float = 0.04

var judge: BeatJudge


func before_each() -> void:
	judge = BeatJudge.new(PERIOD, WINDOW, PERFECT)


func test_exact_buh_is_perfect() -> void:
	var j: BeatJudge.Judgment = judge.judge(PERIOD * 3)
	assert_eq(j.grade, BeatJudge.Grade.PERFECT)
	assert_eq(j.beat, 3)
	assert_almost_eq(j.offset, 0.0, 0.0001)


func test_slightly_early_and_late_are_perfect() -> void:
	assert_eq(judge.judge(PERIOD * 2 - 0.03).grade, BeatJudge.Grade.PERFECT)
	assert_eq(judge.judge(PERIOD * 3 + 0.03).grade, BeatJudge.Grade.PERFECT)


func test_inside_window_outside_perfect_is_good() -> void:
	var early: BeatJudge.Judgment = judge.judge(PERIOD * 2 - 0.1)
	assert_eq(early.grade, BeatJudge.Grade.GOOD)
	assert_lt(early.offset, 0.0)
	var late: BeatJudge.Judgment = judge.judge(PERIOD * 3 + 0.1)
	assert_eq(late.grade, BeatJudge.Grade.GOOD)
	assert_gt(late.offset, 0.0)


func test_after_dum_is_miss() -> void:
	assert_eq(judge.judge(PERIOD * 2 + WINDOW + 0.01).grade, BeatJudge.Grade.MISS)


func test_before_window_opens_is_miss() -> void:
	assert_eq(judge.judge(PERIOD * 2 - WINDOW - 0.01).grade, BeatJudge.Grade.MISS)


func test_between_beats_is_miss() -> void:
	assert_eq(judge.judge(PERIOD * 2.5).grade, BeatJudge.Grade.MISS)


func test_second_input_on_same_beat_is_duplicate_miss() -> void:
	assert_eq(judge.judge(PERIOD * 4).grade, BeatJudge.Grade.PERFECT)
	var second: BeatJudge.Judgment = judge.judge(PERIOD * 4 + 0.05)
	assert_eq(second.grade, BeatJudge.Grade.MISS)
	assert_true(second.duplicate)


func test_next_beat_accepts_after_duplicate() -> void:
	judge.judge(PERIOD * 4)
	judge.judge(PERIOD * 4 + 0.05)
	assert_eq(judge.judge(PERIOD * 5).grade, BeatJudge.Grade.PERFECT)


func test_out_of_window_miss_does_not_claim_beat() -> void:
	assert_eq(judge.judge(PERIOD * 4 - WINDOW - 0.02).grade, BeatJudge.Grade.MISS)
	assert_eq(judge.judge(PERIOD * 4).grade, BeatJudge.Grade.PERFECT)


func test_reset_frees_claimed_beat() -> void:
	judge.judge(PERIOD * 4)
	judge.reset()
	assert_eq(judge.judge(PERIOD * 4).grade, BeatJudge.Grade.PERFECT)
