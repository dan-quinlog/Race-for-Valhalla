extends GutTest

var rules: SparringRules
var hero: SparringRules.Fighter


func before_each() -> void:
	rules = SparringRules.new(1)
	hero = rules.heroes[0]


func _dummy(kind: SparringRules.Dummy.Kind) -> SparringRules.Dummy:
	for d: SparringRules.Dummy in rules.dummies:
		if d.kind == kind:
			return d
	return null


func _go(d: Rune.Dir, beat: int, perfect: bool = false) -> void:
	rules.act(0, TurnAction.direction(d, beat, perfect))


func _cast(k: RuneCorner.Kind, beat: int) -> void:
	rules.act(0, TurnAction.cast(k, beat))


## Puts the hero right of the Post, facing left, with only the Post near.
func _beside_post() -> SparringRules.Dummy:
	var post: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.POST)
	hero.cell = post.cell + Vector2i(1, 0)
	return post


func test_moving_left_right_turns_and_up_down_keeps_facing() -> void:
	_go(Rune.Dir.LEFT, 1)
	assert_eq(hero.cell, Vector2i(0, 1))
	assert_eq(hero.facing, SparringRules.LEFT)
	_go(Rune.Dir.UP, 2)
	assert_eq(hero.cell, Vector2i(0, 0))
	assert_eq(hero.facing, SparringRules.LEFT)


func test_direction_into_a_dummy_attacks_and_stays_put() -> void:
	var post: SparringRules.Dummy = _beside_post()
	var at: Vector2i = hero.cell
	_go(Rune.Dir.LEFT, 1)
	assert_eq(hero.cell, at)
	assert_eq(hero.facing, SparringRules.LEFT)
	assert_eq(post.hp, SparringRules.DUMMY_HP - SparringRules.BASIC_DAMAGE)


func test_perfect_attack_deals_more() -> void:
	var post: SparringRules.Dummy = _beside_post()
	_go(Rune.Dir.LEFT, 1, true)
	assert_eq(post.hp, SparringRules.DUMMY_HP - roundi(SparringRules.BASIC_DAMAGE * SparringRules.BONUS))


func test_heavy_stacks_to_three_and_powers_the_next_attack() -> void:
	var post: SparringRules.Dummy = _beside_post()
	for b: int in 4:
		_cast(RuneCorner.Kind.HEAVY, b + 1)
	assert_eq(hero.charge, SparringRules.MAX_CHARGE)
	assert_true(hero.is_exposed())
	rules.end_turn(5)
	assert_eq(hero.charge, SparringRules.MAX_CHARGE, "a skipped beat keeps the charge")
	_go(Rune.Dir.LEFT, 6)
	assert_eq(post.hp, SparringRules.DUMMY_HP - roundi(SparringRules.BASIC_DAMAGE * 2.5))
	assert_eq(hero.charge, 0)


func test_moving_loses_the_charge() -> void:
	_cast(RuneCorner.Kind.HEAVY, 1)
	_go(Rune.Dir.UP, 2)
	assert_eq(hero.charge, 0)


func test_bless_and_charge_work_in_any_order() -> void:
	_cast(RuneCorner.Kind.HEAVY, 1)
	_cast(RuneCorner.Kind.PRAYER, 2)
	_cast(RuneCorner.Kind.HEAVY, 3)
	assert_eq(hero.charge, 2)
	assert_true(hero.blessed)
	var other := SparringRules.new(1)
	other.act(0, TurnAction.cast(RuneCorner.Kind.PRAYER, 1))
	other.act(0, TurnAction.cast(RuneCorner.Kind.HEAVY, 2))
	other.act(0, TurnAction.cast(RuneCorner.Kind.HEAVY, 3))
	assert_eq(other.heroes[0].charge, 2)
	assert_true(other.heroes[0].blessed)


func test_blessed_kill_earns_bonus_glory_not_damage() -> void:
	var post: SparringRules.Dummy = _beside_post()
	post.hp = SparringRules.BASIC_DAMAGE
	_cast(RuneCorner.Kind.PRAYER, 1)
	_go(Rune.Dir.LEFT, 2)
	assert_false(post.is_alive())
	assert_eq(hero.glory, SparringRules.KILL_GLORY + SparringRules.BLESSED_KILL_GLORY)
	assert_false(hero.blessed)


func test_blessing_is_spent_on_an_attack_that_does_not_kill() -> void:
	_beside_post()
	_cast(RuneCorner.Kind.PRAYER, 1)
	_go(Rune.Dir.LEFT, 2)
	assert_false(hero.blessed)
	assert_eq(hero.glory, 0)


func test_trip_roots_and_sets_up_a_bigger_hit() -> void:
	var walker: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.WALKER)
	walker.cell = Vector2i(4, 0)
	hero.cell = Vector2i(3, 0)
	_cast(RuneCorner.Kind.TRIP, 1)
	assert_eq(walker.hp, SparringRules.DUMMY_HP - SparringRules.TRIP_DAMAGE)
	rules.end_turn(1)
	rules.end_turn(2)
	assert_eq(walker.cell, Vector2i(4, 0), "rooted on the trip beat and the next")
	var hp: int = walker.hp
	_go(Rune.Dir.RIGHT, 3)
	assert_eq(hp - walker.hp, roundi(SparringRules.BASIC_DAMAGE * SparringRules.BONUS))


func test_trip_and_flourish_lose_the_charge() -> void:
	_cast(RuneCorner.Kind.HEAVY, 1)
	_cast(RuneCorner.Kind.FLOURISH, 2)
	assert_eq(hero.charge, 0)
	_cast(RuneCorner.Kind.HEAVY, 3)
	_cast(RuneCorner.Kind.TRIP, 4)
	assert_eq(hero.charge, 0)


func test_flourish_hits_all_four_sides() -> void:
	var post: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.POST)
	var walker: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.WALKER)
	hero.cell = Vector2i(3, 2)
	post.cell = Vector2i(3, 1)
	walker.cell = Vector2i(2, 2)
	_cast(RuneCorner.Kind.FLOURISH, 1)
	assert_eq(post.hp, SparringRules.DUMMY_HP - SparringRules.FLOURISH_DAMAGE)
	assert_eq(walker.hp, SparringRules.DUMMY_HP - SparringRules.FLOURISH_DAMAGE)


## The Archer winds up on beat 2 and looses on beat 4, down lane 1.
func _arrow_incoming() -> void:
	hero.cell = Vector2i(5, 1)
	rules.end_turn(2)
	assert_eq(_dummy(SparringRules.Dummy.Kind.ARCHER).strike_beat, 4)
	rules.end_turn(3)


func test_arrow_hits_the_first_hero_in_its_lane() -> void:
	_arrow_incoming()
	rules.end_turn(4)
	assert_eq(hero.hp, SparringRules.HERO_HP - SparringRules.STRIKE_DAMAGE)


func test_shield_moving_into_the_arrow_blocks_and_stands_firm() -> void:
	_arrow_incoming()
	_go(Rune.Dir.RIGHT, 4)
	assert_eq(hero.cell, Vector2i(5, 1), "blocked instead of moving")
	rules.end_turn(4)
	assert_eq(hero.hp, SparringRules.HERO_HP)


func test_no_shield_moves_and_takes_the_hit() -> void:
	rules = SparringRules.new(1, false)
	hero = rules.heroes[0]
	_arrow_incoming()
	_go(Rune.Dir.RIGHT, 4)
	assert_eq(hero.cell, Vector2i(6, 1))
	rules.end_turn(4)
	assert_eq(hero.hp, SparringRules.HERO_HP - SparringRules.STRIKE_DAMAGE)


func test_blessed_move_evades_even_with_a_shield() -> void:
	_arrow_incoming()
	_cast(RuneCorner.Kind.PRAYER, 3)
	_go(Rune.Dir.RIGHT, 4)
	assert_eq(hero.cell, Vector2i(6, 1), "evading still moves")
	rules.end_turn(4)
	assert_eq(hero.hp, SparringRules.HERO_HP)


func test_shield_only_guards_the_way_you_moved() -> void:
	_arrow_incoming()
	_go(Rune.Dir.LEFT, 4)
	rules.end_turn(4)
	assert_eq(hero.hp, SparringRules.HERO_HP - SparringRules.STRIKE_DAMAGE)


func test_stepping_out_of_the_lane_dodges() -> void:
	_arrow_incoming()
	_go(Rune.Dir.UP, 4)
	rules.end_turn(4)
	assert_eq(hero.hp, SparringRules.HERO_HP)


func test_attacking_the_sparrer_with_a_shield_also_blocks_its_swing() -> void:
	var sparrer: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.SPARRER)
	hero.cell = sparrer.cell + Vector2i(-1, 0)
	rules.end_turn(4)
	rules.end_turn(5)
	_go(Rune.Dir.RIGHT, 6)
	assert_lt(sparrer.hp, SparringRules.DUMMY_HP)
	rules.end_turn(6)
	assert_eq(hero.hp, SparringRules.HERO_HP)


func test_charged_hero_is_exposed_to_hits() -> void:
	_arrow_incoming()
	_cast(RuneCorner.Kind.HEAVY, 4)
	rules.end_turn(4)
	assert_eq(hero.hp, SparringRules.HERO_HP - roundi(SparringRules.STRIKE_DAMAGE * SparringRules.EXPOSED_MULTIPLIER))


func test_dead_dummy_respawns_at_home() -> void:
	var post: SparringRules.Dummy = _beside_post()
	post.hp = 1
	_go(Rune.Dir.LEFT, 1)
	assert_false(post.is_alive())
	rules.end_turn(1 + SparringRules.RESPAWN_BEATS)
	assert_true(post.is_alive())
