extends GutTest

var rules: SparringRules
var hero: SparringRules.Fighter


func before_each() -> void:
	rules = SparringRules.new(1)
	hero = rules.heroes[0]


func _action(kind: RuneAction.Kind, dir: Rune.Dir, beat: int, attack: RuneAction.Attack = RuneAction.Attack.STANDARD) -> RuneAction:
	var a := RuneAction.new()
	a.kind = kind
	a.dir = dir
	a.attack = attack
	a.beat = beat
	return a


func _dummy(kind: SparringRules.Dummy.Kind) -> SparringRules.Dummy:
	for d: SparringRules.Dummy in rules.dummies:
		if d.kind == kind:
			return d
	return null


func test_moving_and_bracing_left_right_turn_the_hero() -> void:
	assert_eq(hero.facing, SparringRules.RIGHT)
	rules.act(0, _action(RuneAction.Kind.MOVE, Rune.Dir.LEFT, 1))
	assert_eq(hero.facing, SparringRules.LEFT)
	assert_eq(hero.cell, Vector2i(0, 1))
	rules.act(0, _action(RuneAction.Kind.BRACE, Rune.Dir.RIGHT, 2))
	assert_eq(hero.facing, SparringRules.RIGHT)
	rules.act(0, _action(RuneAction.Kind.MOVE, Rune.Dir.UP, 3))
	assert_eq(hero.facing, SparringRules.RIGHT, "up/down moves keep the facing")


func test_blocked_move_still_turns() -> void:
	hero.cell = Vector2i(0, 1)
	rules.act(0, _action(RuneAction.Kind.MOVE, Rune.Dir.LEFT, 1))
	assert_eq(hero.cell, Vector2i(0, 1))
	assert_eq(hero.facing, SparringRules.LEFT)


func test_heroes_cannot_enter_a_dummy_zone() -> void:
	hero.cell = Vector2i(2, 1)
	rules.act(0, _action(RuneAction.Kind.MOVE, Rune.Dir.RIGHT, 1))
	assert_eq(hero.cell, Vector2i(2, 1))


func test_standard_and_heavy_hit_front_above_and_below() -> void:
	hero.cell = Vector2i(2, 1)
	var cells: Array[Vector2i] = SparringRules.attack_cells(hero, RuneAction.Attack.STANDARD)
	assert_eq(cells, [Vector2i(3, 1), Vector2i(2, 0), Vector2i(2, 2)] as Array[Vector2i])
	assert_eq(SparringRules.attack_cells(hero, RuneAction.Attack.HEAVY).size(), 3)


func test_trip_and_defensive_hit_only_the_front() -> void:
	hero.cell = Vector2i(2, 1)
	hero.facing = SparringRules.LEFT
	assert_eq(SparringRules.attack_cells(hero, RuneAction.Attack.TRIP), [Vector2i(1, 1)] as Array[Vector2i])
	assert_eq(SparringRules.attack_cells(hero, RuneAction.Attack.DEFENSIVE), [Vector2i(1, 1)] as Array[Vector2i])


func test_attack_cells_stay_on_the_grid() -> void:
	hero.cell = Vector2i(2, 0)
	assert_eq(SparringRules.attack_cells(hero, RuneAction.Attack.STANDARD).size(), 2)


func test_standard_hits_the_post_in_front() -> void:
	var post: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.POST)
	hero.cell = post.cell + Vector2i(-1, 0)
	rules.act(0, _action(RuneAction.Kind.ATTACK, Rune.Dir.LEFT, 1))
	assert_eq(post.hp, SparringRules.DUMMY_HP - SparringRules.STANDARD_DAMAGE)


func test_trip_roots_and_sets_up_a_bigger_heavy() -> void:
	var walker: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.WALKER)
	walker.cell = Vector2i(4, 1)
	_dummy(SparringRules.Dummy.Kind.POST).hp = 0
	hero.cell = Vector2i(3, 1)
	rules.act(0, _action(RuneAction.Kind.ATTACK, Rune.Dir.DOWN, 1, RuneAction.Attack.TRIP))
	assert_true(walker.is_rooted(2))
	assert_false(walker.is_rooted(3))
	assert_true(walker.is_vulnerable(3))
	rules.end_turn(1)
	rules.end_turn(2)
	assert_eq(walker.cell, Vector2i(4, 1), "rooted on the trip beat and the next")
	var hp: int = walker.hp
	rules.act(0, _action(RuneAction.Kind.ATTACK, Rune.Dir.UP, 3, RuneAction.Attack.HEAVY))
	assert_eq(hp - walker.hp, roundi(SparringRules.HEAVY_DAMAGE * SparringRules.BONUS))


func test_charging_and_landing_a_heavy_expose_the_hero() -> void:
	rules.act(0, _action(RuneAction.Kind.CHARGE, Rune.Dir.UP, 1))
	assert_true(hero.charging)
	assert_true(hero.is_exposed(1))
	rules.act(0, _action(RuneAction.Kind.ATTACK, Rune.Dir.UP, 2, RuneAction.Attack.HEAVY))
	assert_false(hero.charging)
	assert_true(hero.is_exposed(2))
	assert_false(hero.is_exposed(3))


func test_walker_patrols_and_turns_at_the_ends() -> void:
	var walker: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.WALKER)
	walker.cell = Vector2i(walker.min_col, 0)
	walker.walk_dir = SparringRules.LEFT
	rules.end_turn(1)
	assert_eq(walker.cell, Vector2i(walker.min_col + 1, 0))


func _sparrer_setup() -> SparringRules.Dummy:
	var s: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.SPARRER)
	hero.cell = s.cell + Vector2i(-1, 0)
	rules.end_turn(4)
	assert_eq(s.strike_beat, 4 + SparringRules.SPAR_WINDUP)
	return s


func test_sparrer_telegraphs_then_hits_its_neighbours() -> void:
	var s: SparringRules.Dummy = _sparrer_setup()
	assert_true(hero.cell in s.targets)
	rules.end_turn(5)
	assert_eq(hero.hp, SparringRules.HERO_HP)
	rules.end_turn(6)
	assert_eq(hero.hp, SparringRules.HERO_HP - SparringRules.SPAR_DAMAGE)


func test_brace_covers_only_its_own_beat() -> void:
	_sparrer_setup()
	rules.act(0, _action(RuneAction.Kind.BRACE, Rune.Dir.RIGHT, 5))
	rules.end_turn(5)
	rules.end_turn(6)
	assert_eq(hero.hp, SparringRules.HERO_HP - SparringRules.SPAR_DAMAGE, "a brace on the beat before doesn't count")


func test_brace_facing_the_hit_on_its_beat_blocks() -> void:
	_sparrer_setup()
	rules.end_turn(5)
	rules.act(0, _action(RuneAction.Kind.BRACE, Rune.Dir.RIGHT, 6))
	rules.end_turn(6)
	assert_eq(hero.hp, SparringRules.HERO_HP)


func test_brace_the_wrong_way_does_not_block() -> void:
	_sparrer_setup()
	rules.end_turn(5)
	rules.act(0, _action(RuneAction.Kind.BRACE, Rune.Dir.LEFT, 6))
	rules.end_turn(6)
	assert_lt(hero.hp, SparringRules.HERO_HP)


func test_exposed_hero_takes_more() -> void:
	_sparrer_setup()
	rules.end_turn(5)
	rules.act(0, _action(RuneAction.Kind.CHARGE, Rune.Dir.UP, 6))
	rules.end_turn(6)
	assert_eq(hero.hp, SparringRules.HERO_HP - roundi(SparringRules.SPAR_DAMAGE * SparringRules.EXPOSED_MULTIPLIER))


func test_dead_dummy_respawns_at_home() -> void:
	var post: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.POST)
	post.hp = 1
	hero.cell = post.cell + Vector2i(-1, 0)
	rules.act(0, _action(RuneAction.Kind.ATTACK, Rune.Dir.LEFT, 1))
	assert_false(post.is_alive())
	rules.end_turn(1 + SparringRules.RESPAWN_BEATS)
	assert_true(post.is_alive())
	assert_eq(post.hp, SparringRules.DUMMY_HP)
