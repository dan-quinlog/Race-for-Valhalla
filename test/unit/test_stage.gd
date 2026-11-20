extends GutTest

const StageScene: PackedScene = preload("res://scenes/stage.tscn")
const StageScript: GDScript = preload("res://scripts/stage.gd")

var stage: Control


func before_each() -> void:
	stage = partial_double(StageScene).instantiate()
	stub(stage, "go_to_scene").to_do_nothing()
	stub(stage, "schedule_next_stage").to_do_nothing()
	add_child_autofree(stage)
	await wait_process_frames(2)


func _period() -> float:
	return stage.panels[0].rhythm.judge.period


## Submits a two-rune command for a panel on beats `beat` and `beat + 1`.
func _command(panel: int, first: Rune.Dir, second: Rune.Dir, beat: int) -> void:
	stage.panels[panel].submit(first, _period() * beat)
	stage.panels[panel].submit(second, _period() * (beat + 1))


func _kill_all() -> void:
	for e: Enemy in stage.rules.enemies:
		e.hp = 0
	stage.rules._update_clears()


func test_first_stage_chunks_are_valid() -> void:
	for chunk: StageChunk in StageScript.FIRST_STAGE:
		assert_eq(chunk.validate(), "")


func test_first_stage_layout() -> void:
	var map: StageMap = stage.rules.map
	assert_eq(map.width, 9)
	assert_eq(map.encounters.size(), 2)
	assert_eq(map.encounters[0].end - StageRules.VIEW_COLS, 1, "one column of scroll to the first lock")
	assert_eq(map.encounters[1].end - map.encounters[0].end, StageRules.VIEW_COLS, "then a full screen to the second")
	assert_eq(stage.rules.enemies.size(), 4)
	assert_eq(stage.rules.fires.size(), 1)
	assert_eq(map.door, Vector2i(8, 2))


func test_starts_solo_with_one_hero() -> void:
	assert_false(stage.two_players)
	assert_false(stage.panels[1].visible)
	assert_eq(stage.rules.heroes.size(), 1)
	assert_eq(stage.get_node("%StageView").rules, stage.rules)


func test_completed_command_moves_the_hero() -> void:
	_command(0, Rune.Dir.DOWN, Rune.Dir.RIGHT, 1)
	assert_eq(stage.rules.heroes[0].cell, Vector2i(1, 1))
	assert_string_contains(stage.get_node("%StageLog").text, "moves right")


func test_beat_closing_advances_the_stage() -> void:
	stage._on_beat_closed(3)
	assert_eq(stage.rules.closed_through, 3)


func test_two_players_gives_two_heroes() -> void:
	stage.set_two_players(true)
	assert_true(stage.panels[1].visible)
	assert_eq(stage.rules.heroes.size(), 2)
	_command(1, Rune.Dir.DOWN, Rune.Dir.RIGHT, 1)
	assert_eq(stage.rules.heroes[1].cell, Vector2i(1, 2))
	assert_eq(stage.rules.heroes[0].cell, Vector2i(0, 1))


func test_door_opening_updates_banner() -> void:
	_kill_all()
	assert_string_contains(stage.get_node("%Banner").text, "door is open")


func test_reaching_the_door_clears_the_stage() -> void:
	stage.rules.camera_col = 5
	stage.rules.heroes[0].cell = Vector2i(8, 2)
	_kill_all()
	assert_true(stage.rules.won)
	assert_string_starts_with(stage.get_node("%Banner").text, "Through the door")
	assert_called(stage, "schedule_next_stage")


func test_next_stage_is_the_boss_and_carries_heroes_over() -> void:
	stage.rules.heroes[0].hp = 33
	stage.rules.heroes[0].glory = 7
	stage.advance_stage()
	assert_eq(stage.stage_index, 1)
	assert_true(stage.rules.enemies[0] is BossEnemy)
	assert_eq(stage.rules.heroes[0].hp, 33)
	assert_eq(stage.rules.heroes[0].glory, 7)
	assert_string_contains(stage.get_node("%Banner").text, "Jötunn")


func test_boss_button_starts_the_arena_fresh() -> void:
	stage.rules.heroes[0].hp = 5
	stage.get_node("%BossButton").pressed.emit()
	assert_eq(stage.stage_index, 1)
	assert_eq(stage.rules.heroes[0].hp, StageRules.HERO_HP)
	assert_eq(stage.rules.map.width, StageRules.VIEW_COLS, "a single screen")


func test_fallen_hero_gets_final_strike_pad_and_ekg_heart() -> void:
	stage.start_stage(1)
	var hero: Hero = stage.rules.heroes[0]
	hero.cell = Vector2i(2, 1)
	hero.hp = 0
	stage.rules._fall(hero, 4)
	var panel: PlayerPanel = stage.panels[0]
	assert_eq(panel.rhythm.final_beat, 7)
	assert_false(panel.get_node("%RunePad").final_labels.is_empty())
	assert_eq(stage.get_node("%Ekg").final_marker_count(), 1)
	stage.rules.closed_through = 6
	panel.submit(Rune.Dir.DOWN, _period() * 7)
	assert_eq(stage.rules.enemies[0].hp, 300 - roundi(StageRules.STRIKE_DAMAGE * 1.5), "Perfect Strike on the body")
	assert_false(hero.has_final_strike())
	assert_true(panel.get_node("%RunePad").final_labels.is_empty())


func test_final_strike_victory_banner() -> void:
	stage.start_stage(1)
	var hero: Hero = stage.rules.heroes[0]
	hero.cell = Vector2i(2, 1)
	stage.rules.enemies[0].hp = 5
	hero.hp = 0
	stage.rules._fall(hero, 4)
	stage.rules.closed_through = 6
	stage.panels[0].submit(Rune.Dir.DOWN, _period() * 7)
	assert_true(stage.rules.won)
	assert_string_starts_with(stage.get_node("%Banner").text, "Victory in death")


func test_restart_resets_stage() -> void:
	stage.rules.heroes[0].hp = 1
	stage.restart()
	assert_eq(stage.rules.heroes[0].hp, StageRules.HERO_HP)
	assert_eq(stage.get_node("%StageLog").text, "")


func test_lab_button_changes_scene() -> void:
	stage.get_node("%LabButton").pressed.emit()
	assert_called(stage, "go_to_scene", ["res://scenes/rhythm_lab.tscn"])


func test_view_tags_show_hero_state() -> void:
	var hero := Hero.new(0, 60, Vector2i.ZERO)
	assert_eq(StageView.hero_tags(hero, 3), "")
	hero.brace_until = 4
	hero.brace_dir = Rune.Dir.RIGHT
	hero.brace_blessed = true
	hero.exposed = true
	assert_eq(StageView.hero_tags(hero, 3), "BRACE+→ EXPOSED")
	hero.hp = 0
	assert_eq(StageView.hero_tags(hero, 3), "FALLEN")
	hero.final_beat = 6
	assert_eq(StageView.hero_tags(hero, 3), "FINAL STRIKE")


func test_view_splits_into_four_columns_and_three_lanes() -> void:
	var view: StageView = stage.get_node("%StageView")
	var z: Vector2 = view.zone_size()
	assert_almost_eq(z.x * StageRules.VIEW_COLS, view.size.x, 0.5)
	assert_almost_eq(z.y * StageMap.LANES, view.size.y, 0.5)
	assert_almost_eq(view.cell_rect(Vector2i(1, 2)).position.x, z.x + StageView.GAP * 0.5, 0.5)


func test_first_rune_lights_hero_aura_until_the_command_ends() -> void:
	var view: StageView = stage.get_node("%StageView")
	var hero: Hero = stage.rules.heroes[0]
	stage.panels[0].submit(Rune.Dir.LEFT, _period() * 3)
	assert_eq(view.auras[0], Rune.Dir.LEFT)
	assert_eq(view.aura_color(hero).a, 1.0)
	stage.panels[0].submit(Rune.Dir.LEFT, _period() * 4)
	assert_eq(view.auras[0], CommandReader.NO_RUNE)
	view._process(StageView.AURA_FADE)
	assert_eq(view.aura_color(hero).a, 0.0, "faded back to neutral")


func test_skipped_beat_clears_aura() -> void:
	var view: StageView = stage.get_node("%StageView")
	stage.panels[0].submit(Rune.Dir.RIGHT, _period() * 3)
	stage._on_beat_closed(4)
	assert_eq(view.auras[0], CommandReader.NO_RUNE)
	assert_eq(stage.panels[0].rhythm.reader.pending, CommandReader.NO_RUNE)


func test_fallen_hero_glows_white() -> void:
	var view: StageView = stage.get_node("%StageView")
	var hero: Hero = stage.rules.heroes[0]
	hero.hp = 0
	var c: Color = view.aura_color(hero)
	assert_eq([c.r, c.g, c.b], [1.0, 1.0, 1.0])
	assert_gt(c.a, 0.0)
