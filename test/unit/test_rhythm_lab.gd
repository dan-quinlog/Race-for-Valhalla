extends GutTest

const LabScene: PackedScene = preload("res://scenes/rhythm_lab.tscn")

var lab: Control


func before_each() -> void:
	lab = LabScene.instantiate()
	add_child_autofree(lab)
	await wait_process_frames(2)


func _period() -> float:
	return lab.panels[0].input.judge.period


func _presses(panel: TurnPanel) -> int:
	var c: ComboTracker = panel.input.combo
	return c.perfects + c.goods + c.misses


func test_starts_solo_chord_hold_with_p2_hidden() -> void:
	assert_false(lab.two_players)
	assert_false(lab.panels[1].visible)
	assert_eq(lab.key_style, lab.KeyStyle.CHORD)
	assert_eq(lab.charge_mode, TurnInput.ChargeMode.HOLD)
	assert_string_contains(lab.panels[0].get_node("%RunePad").get_node("%Up").text, "[W]")


func test_chord_rune_with_held_direction() -> void:
	var t: float = _period() * 3
	lab.chord_dir(0, Rune.Dir.LEFT, true)
	lab.chord_rune(0, Rune.Dir.DOWN, true, t)
	lab._on_beat_closed(3)
	assert_eq(lab.rules.heroes[0].cell, Vector2i(0, 1))
	assert_eq(lab.rules.heroes[0].facing, SparringRules.LEFT)


func test_chord_direction_after_the_rune_steers_it() -> void:
	lab.chord_rune(0, Rune.Dir.DOWN, true, _period() * 3)
	lab.chord_dir(0, Rune.Dir.UP, true)
	lab._on_beat_closed(3)
	assert_eq(lab.rules.heroes[0].cell, Vector2i(1, 0))


func test_solo_routes_both_input_sets_to_p1() -> void:
	lab.chord_rune(0, Rune.Dir.LEFT, true, _period() * 2)
	lab.chord_rune(1, Rune.Dir.LEFT, true, _period() * 3)
	assert_eq(_presses(lab.panels[0]), 2)
	assert_eq(_presses(lab.panels[1]), 0)


func test_gallop_second_key_is_the_direction() -> void:
	lab.set_key_style(lab.KeyStyle.GALLOP)
	var t: float = _period() * 3
	lab.gallop_key(0, Rune.Dir.DOWN, true, t)
	lab.gallop_key(0, Rune.Dir.UP, true, t + 0.08)
	assert_eq(_presses(lab.panels[0]), 1, "the direction key isn't a press")
	lab._on_beat_closed(3)
	assert_eq(lab.rules.heroes[0].cell, Vector2i(1, 0))


func test_gallop_key_just_after_the_dum_is_ignored() -> void:
	lab.set_key_style(lab.KeyStyle.GALLOP)
	var t: float = _period() * 3
	lab.gallop_key(0, Rune.Dir.DOWN, true, t)
	lab._on_beat_closed(3)
	lab.gallop_key(0, Rune.Dir.UP, true, t + lab.panels[0].input.judge.window + 0.05)
	assert_eq(_presses(lab.panels[0]), 1)


func test_two_players_gallop_on_one_keyboard() -> void:
	lab.set_key_style(lab.KeyStyle.GALLOP)
	lab.set_two_players(true)
	assert_true(lab.panels[1].visible)
	assert_eq(lab.rules.heroes.size(), 2)
	lab.gallop_key(0, Rune.Dir.LEFT, true, _period() * 3)
	lab.gallop_key(1, Rune.Dir.LEFT, true, _period() * 3)
	assert_eq(_presses(lab.panels[0]), 1)
	assert_eq(_presses(lab.panels[1]), 1)


func test_hold_heavy_charges_then_fires_on_release() -> void:
	var p: float = _period()
	lab.chord_dir(0, Rune.Dir.UP, true)
	lab.chord_rune(0, Rune.Dir.LEFT, true, p * 3)
	lab._on_beat_closed(3)
	assert_true(lab.rules.heroes[0].charging)
	lab._on_beat_closed(4)
	lab.chord_rune(0, Rune.Dir.LEFT, false, p * 4.5)
	lab._on_beat_closed(5)
	assert_false(lab.rules.heroes[0].charging)
	assert_true(lab.rules.heroes[0].is_exposed(5))


func test_charge_mode_switch_reconfigures() -> void:
	lab.set_charge_mode(TurnInput.ChargeMode.REPEAT)
	assert_eq(lab.panels[0].input.charge_mode, TurnInput.ChargeMode.REPEAT)
	assert_eq(lab.get_node("%ChargeMode").selected, TurnInput.ChargeMode.REPEAT)


func test_bpm_change_reconfigures_players() -> void:
	lab.get_node("%Bpm").value = 120.0
	assert_almost_eq(lab.panels[0].input.judge.period, 0.5, 0.001)
	assert_almost_eq(lab.panels[1].input.judge.period, 0.5, 0.001)


func test_window_is_clamped_below_half_period() -> void:
	lab.get_node("%Bpm").value = 160.0
	lab.get_node("%WindowMs").value = 250.0
	var judge: BeatJudge = lab.panels[0].input.judge
	assert_lt(judge.window * 2.0, judge.period)


func test_attacks_flash_the_arena() -> void:
	lab.chord_rune(0, Rune.Dir.LEFT, true, _period() * 3)
	lab._on_beat_closed(3)
	assert_eq(lab.get_node("%Arena").flash_count(), 1)


func test_stage_button_opens_stage() -> void:
	var doubled: Control = partial_double(LabScene).instantiate()
	stub(doubled, "go_to_scene").to_do_nothing()
	add_child_autofree(doubled)
	doubled.get_node("%StageButton").pressed.emit()
	assert_called(doubled, "go_to_scene", ["res://scenes/stage.tscn"])


func test_ekg_wave_peaks_on_buh() -> void:
	var ekg: EkgDisplay = lab.get_node("%Ekg")
	assert_almost_eq(ekg.wave(0.0), 1.0, 0.05)
	assert_lt(ekg.wave(ekg.period * 0.5), 0.05)
	assert_gt(ekg.wave(0.0), ekg.wave(ekg.dum_delay))
