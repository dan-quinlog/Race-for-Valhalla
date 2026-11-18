extends GutTest

const LabScene: PackedScene = preload("res://scenes/rhythm_lab.tscn")

var lab: Control


func before_each() -> void:
	lab = LabScene.instantiate()
	add_child_autofree(lab)
	await wait_process_frames(2)


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	lab._unhandled_input(ev)


func _presses(panel: PlayerPanel) -> int:
	var c: ComboTracker = panel.rhythm.combo
	return c.perfects + c.goods + c.misses


func test_starts_solo_with_p2_hidden() -> void:
	assert_false(lab.two_players)
	assert_false(lab.panels[1].visible)
	assert_string_contains(lab.panels[0].get_node("%RunePad").get_node("%Up").text, "W / ↑")


func test_solo_routes_both_key_sets_to_p1() -> void:
	_press(&"p1_left")
	_press(&"p2_left")
	assert_eq(_presses(lab.panels[0]), 2)
	assert_eq(_presses(lab.panels[1]), 0)


func test_two_players_route_separately() -> void:
	lab.set_two_players(true)
	assert_true(lab.panels[1].visible)
	_press(&"p1_down")
	_press(&"p2_up")
	assert_eq(_presses(lab.panels[0]), 1)
	assert_eq(_presses(lab.panels[1]), 1)
	assert_eq(lab.get_node("%TwoPlayers").button_pressed, true)


func test_players_judge_the_same_beat_independently() -> void:
	lab.set_two_players(true)
	var period: float = lab.panels[0].rhythm.judge.period
	assert_eq(lab.panels[0].submit(Rune.Dir.LEFT, period * 3).judgment.grade, BeatJudge.Grade.PERFECT)
	assert_eq(lab.panels[1].submit(Rune.Dir.LEFT, period * 3).judgment.grade, BeatJudge.Grade.PERFECT)


func test_bpm_change_reconfigures_players() -> void:
	lab.panels[0].submit(Rune.Dir.DOWN, lab.panels[0].rhythm.judge.period)
	lab.get_node("%Bpm").value = 120.0
	assert_almost_eq(lab.panels[0].rhythm.judge.period, 0.5, 0.001)
	assert_almost_eq(lab.panels[1].rhythm.judge.period, 0.5, 0.001)
	assert_eq(lab.panels[0].rhythm.reader.pending, CommandReader.NO_RUNE)


func test_window_is_clamped_below_half_period() -> void:
	lab.get_node("%Bpm").value = 160.0
	lab.get_node("%WindowMs").value = 250.0
	var judge: BeatJudge = lab.panels[0].rhythm.judge
	assert_lt(judge.window * 2.0, judge.period)


func test_beats_expire_pending_commands() -> void:
	lab.panels[0].submit(Rune.Dir.RIGHT, lab.panels[0].rhythm.judge.period)
	lab._on_beat(3)
	assert_eq(lab.panels[0].rhythm.reader.pending, CommandReader.NO_RUNE)


func test_ekg_wave_peaks_on_buh() -> void:
	var ekg: EkgDisplay = lab.get_node("%Ekg")
	assert_almost_eq(ekg.wave(0.0), 1.0, 0.05)
	assert_lt(ekg.wave(ekg.period * 0.5), 0.05)
	assert_gt(ekg.wave(0.0), ekg.wave(ekg.dum_delay))
