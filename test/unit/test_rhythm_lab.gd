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


func _event(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func test_starts_solo_with_rune_buttons_and_a_shield() -> void:
	assert_false(lab.two_players)
	assert_false(lab.panels[1].visible)
	assert_eq(lab.binding, lab.Binding.RUNE_BUTTONS)
	assert_true(lab.rules.shields)
	var pad: DirectionPad = lab.panels[0].get_node("%Pad")
	assert_string_contains(pad.rune_button(RuneCorner.Kind.PRAYER).text, "[Q]")
	assert_string_contains(pad.dir_button(Rune.Dir.UP).text, "W / ↑")


func test_direction_moves_the_hero_at_the_dum() -> void:
	lab.press_dir(0, Rune.Dir.UP, _period() * 3)
	lab._on_beat_closed(3)
	assert_eq(lab.rules.heroes[0].cell, Vector2i(1, 0))


func test_chord_casts_the_rune() -> void:
	var t: float = _period() * 3
	lab.press_dir(0, Rune.Dir.UP, t)
	lab.press_dir(0, Rune.Dir.RIGHT, t + 0.05)
	lab._on_beat_closed(3)
	assert_eq(lab.rules.heroes[0].charge, 1)
	assert_eq(lab.rules.heroes[0].cell, Vector2i(1, 1))


func test_rune_button_action_casts_directly() -> void:
	lab._unhandled_input(_event(RuneCorner.action_name(0, RuneCorner.Kind.PRAYER)))
	assert_eq(_presses(lab.panels[0]), 1)


func test_directions_binding_ignores_rune_buttons() -> void:
	lab.set_binding(lab.Binding.DIRECTIONS)
	lab._unhandled_input(_event(RuneCorner.action_name(0, RuneCorner.Kind.PRAYER)))
	assert_eq(_presses(lab.panels[0]), 0)
	assert_string_contains(lab.panels[0].get_node("%Pad").rune_button(RuneCorner.Kind.PRAYER).text, "[W+A]")


func test_solo_routes_both_input_sets_to_p1() -> void:
	lab.press_dir(0, Rune.Dir.LEFT, _period() * 2)
	lab._on_beat_closed(2)
	lab.press_dir(1, Rune.Dir.LEFT, _period() * 3)
	assert_eq(_presses(lab.panels[0]), 2)
	assert_eq(_presses(lab.panels[1]), 0)


func test_two_players_on_one_keyboard() -> void:
	lab.set_two_players(true)
	assert_true(lab.panels[1].visible)
	assert_eq(lab.rules.heroes.size(), 2)
	lab.press_dir(0, Rune.Dir.UP, _period() * 3)
	lab.press_dir(1, Rune.Dir.DOWN, _period() * 3)
	lab._on_beat_closed(3)
	assert_eq(lab.rules.heroes[0].cell, Vector2i(1, 0))
	assert_eq(lab.rules.heroes[1].cell, Vector2i(1, 2))


func test_shield_toggle_rebuilds_the_yard() -> void:
	lab.set_shields(false)
	assert_false(lab.rules.shields)
	assert_false(lab.get_node("%Shield").button_pressed)


func test_status_shows_charge_and_blessing() -> void:
	var t: float = _period() * 3
	lab.press_rune(0, RuneCorner.Kind.HEAVY, t)
	lab._on_beat_closed(3)
	lab.press_rune(0, RuneCorner.Kind.PRAYER, t + _period())
	lab._on_beat_closed(4)
	var status: String = lab.panels[0].get_node("%StatusLabel").text
	assert_string_contains(status, "Heavy x1")
	assert_string_contains(status, "Blessed")


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
	lab.press_rune(0, RuneCorner.Kind.FLOURISH, _period() * 3)
	lab._on_beat_closed(3)
	assert_gt(lab.get_node("%Arena").flash_count(), 0)


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


func test_arrow_is_drawn_where_it_stops() -> void:
	lab.rules.end_turn(2)
	lab.rules.end_turn(4)
	assert_eq(lab.get_node("%Arena").shot_count(), 1)
