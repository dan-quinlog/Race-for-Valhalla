extends GutTest

var stage: StageRules
var varg: VargEnemy


func _setup(rows: Array[String], cell: Vector2i) -> void:
	var map: StageMap = StageMap.build([StageChunk.from_rows(rows)])
	varg = VargEnemy.new(cell)
	stage = StageRules.new(map, 1, [varg])


func test_lopes_two_zones_toward_a_distant_hero() -> void:
	_setup(["1...", "....", "...."], Vector2i(3, 2))
	varg.try_act(0, stage)
	assert_false(varg.is_winding())
	assert_eq(StageRules._distance(varg.cell, Vector2i(0, 0)), 3, "two steps closer")


func test_pounces_on_a_hero_within_range_and_leaps_in() -> void:
	_setup(["....", "1...", "...."], Vector2i(2, 1))
	varg.try_act(0, stage)
	assert_true(varg.is_winding())
	assert_eq(varg.current.display_name, "Pounce")
	assert_eq(varg.targets, [Vector2i(0, 1)])
	stage.heroes[0].cell = Vector2i(0, 0)
	stage.close_beat(varg.hit_beat)
	assert_eq(stage.heroes[0].hp, StageRules.HERO_HP, "dodged")
	assert_eq(varg.cell, Vector2i(0, 1), "lands in the zone it pounced on")


func test_pounce_hits_a_hero_who_stays() -> void:
	_setup(["....", "1...", "...."], Vector2i(1, 1))
	stage.close_beat(0)
	stage.close_beat(2)
	assert_eq(stage.heroes[0].hp, StageRules.HERO_HP - VargEnemy.POUNCE_DAMAGE)
	assert_eq(varg.cell, Vector2i(0, 1))


func test_spawned_from_chunk() -> void:
	var map: StageMap = StageMap.build([StageChunk.from_rows(["1..V", "...S", "...."], true)])
	var rules := StageRules.new(map)
	assert_true(rules.enemies[0] is VargEnemy)
	assert_true(rules.enemies[1] is ShieldThrallEnemy)
