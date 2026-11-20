extends GutTest


func test_three_stages_then_the_boss() -> void:
	var run := DrengRun.new(null, 3)
	assert_eq(run.stage_count(), 4)
	for i: int in DrengRun.STAGE_COUNT:
		assert_false(run.is_boss(i))
		assert_eq(StageMap.build(run.stage_chunks(i)).encounters.size(), 2)
	assert_true(run.is_boss(3))
	var boss: StageRules = StageRules.new(StageMap.build(run.stage_chunks(3)))
	assert_true(boss.enemies[0] is BossEnemy)


func test_stages_are_stable_for_a_seed() -> void:
	assert_eq(DrengRun.new(null, 9).stage_chunks(1), DrengRun.new(null, 9).stage_chunks(1))


func test_lineage_heroes_get_two_different_names() -> void:
	var run := DrengRun.new(Lineage.new("L", Oath.Kind.TYR), 1)
	assert_ne(run.hero_names[0], run.hero_names[1])
	assert_eq(run.oath(), Oath.Kind.TYR)


func test_quick_run_records_nothing() -> void:
	var run := DrengRun.new(null, 1)
	var heroes: Array[Hero] = [Hero.new(0, 60, Vector2i.ZERO)]
	assert_false(run.record(heroes, true, 3))


func test_records_each_hero_once() -> void:
	var run := DrengRun.new(Lineage.new("L"), 1)
	var alive := Hero.new(0, 60, Vector2i.ZERO)
	var dead := Hero.new(1, 60, Vector2i.ZERO)
	dead.hp = 0
	var heroes: Array[Hero] = [alive, dead]
	assert_true(run.record(heroes, true, 3))
	assert_false(run.record(heroes, true, 3))
	assert_eq(run.lineage.heroes.size(), 2)
	assert_eq(run.lineage.heroes[0].fate, Lineage.Fate.COMPLETED_DRENG)
	assert_eq(run.lineage.heroes[1].fate, Lineage.Fate.FELL)
	assert_eq(run.lineage.heroes[1].stage, 4)
