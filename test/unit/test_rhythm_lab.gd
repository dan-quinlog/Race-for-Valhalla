extends GutTest

const LabScene: PackedScene = preload("res://scenes/rhythm_lab.tscn")

var lab: Control


func before_each() -> void:
	lab = LabScene.instantiate()
	add_child_autofree(lab)
	await wait_process_frames(2)


func _period() -> float:
	return lab.judge.period


func test_starts_with_clean_state() -> void:
	assert_eq(lab.combo.combo, 0)
	assert_eq(lab.history.size(), 0)
	assert_eq(lab.get_node("%JudgmentLabel").text, "Press on the beat")


func test_on_beat_rune_is_perfect_and_logged() -> void:
	var j: BeatJudge.Judgment = lab.submit_rune(0, _period() * 3)
	assert_eq(j.grade, BeatJudge.Grade.PERFECT)
	assert_eq(lab.history, ["Fehu"])
	assert_string_starts_with(lab.get_node("%JudgmentLabel").text, "PERFECT")
	assert_eq(lab.get_node("%ComboLabel").text, "Combo 1   (best 1)")


func test_offbeat_rune_breaks_combo_without_logging() -> void:
	lab.submit_rune(0, _period() * 3)
	lab.submit_rune(1, _period() * 4)
	lab.submit_rune(2, _period() * 4.5)
	assert_eq(lab.combo.combo, 0)
	assert_eq(lab.combo.best, 2)
	assert_eq(lab.history, ["Fehu", "Uruz"])
	assert_string_starts_with(lab.get_node("%JudgmentLabel").text, "MISS")


func test_rune_buttons_submit_runes() -> void:
	lab.get_node("%Rune3").button_down.emit()
	assert_eq(lab.combo.perfects + lab.combo.goods + lab.combo.misses, 1)


func test_history_is_capped() -> void:
	for i: int in 12:
		lab.submit_rune(i % 4, _period() * (i + 1))
	assert_eq(lab.history.size(), lab.HISTORY_LENGTH)


func test_bpm_change_restarts_with_new_period() -> void:
	lab.submit_rune(0, _period())
	lab.get_node("%Bpm").value = 120.0
	assert_almost_eq(lab.judge.period, 0.5, 0.001)
	assert_eq(lab.combo.combo, 0)


func test_window_is_clamped_below_half_period() -> void:
	lab.get_node("%Bpm").value = 160.0
	lab.get_node("%WindowMs").value = 250.0
	assert_lt(lab.judge.window * 2.0, lab.judge.period)


func test_describe_reports_early_and_late() -> void:
	var early := BeatJudge.Judgment.new(BeatJudge.Grade.GOOD, 1, -0.08)
	assert_eq(lab.describe(early), "GOOD  (-80 ms early)")
	var dup := BeatJudge.Judgment.new(BeatJudge.Grade.MISS, 1, 0.0, true)
	assert_eq(lab.describe(dup), "MISS: one rune per beat")


func test_ekg_wave_peaks_on_buh() -> void:
	var ekg: EkgDisplay = lab.get_node("%Ekg")
	assert_almost_eq(ekg.wave(0.0), 1.0, 0.05)
	assert_lt(ekg.wave(ekg.period * 0.5), 0.05)
	assert_gt(ekg.wave(0.0), ekg.wave(ekg.dum_delay))
