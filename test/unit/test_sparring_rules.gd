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


## Clears the yard of every dummy but these kinds.
func _keep(kinds: Array) -> void:
	rules.dummies = rules.dummies.filter(func(d: SparringRules.Dummy) -> bool: return d.kind in kinds)


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
	_keep([SparringRules.Dummy.Kind.POST])
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
	_keep([SparringRules.Dummy.Kind.VARG])
	var varg: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.VARG)
	varg.cell = Vector2i(5, 0)
	hero.cell = Vector2i(4, 0)
	_cast(RuneCorner.Kind.TRIP, 1)
	assert_eq(varg.hp, SparringRules.VARG_HP - SparringRules.TRIP_DAMAGE)
	hero.cell = Vector2i(1, 2)
	rules.end_turn(1)
	rules.end_turn(2)
	assert_eq(varg.cell, Vector2i(5, 0), "rooted on the trip beat and the next")
	hero.cell = Vector2i(4, 0)
	var hp: int = varg.hp
	_go(Rune.Dir.RIGHT, 3)
	assert_eq(hp - varg.hp, roundi(SparringRules.BASIC_DAMAGE * SparringRules.BONUS))


func test_trip_and_flourish_lose_the_charge() -> void:
	_cast(RuneCorner.Kind.HEAVY, 1)
	_cast(RuneCorner.Kind.FLOURISH, 2)
	assert_eq(hero.charge, 0)
	_cast(RuneCorner.Kind.HEAVY, 3)
	_cast(RuneCorner.Kind.TRIP, 4)
	assert_eq(hero.charge, 0)


func test_flourish_hits_all_four_sides() -> void:
	var post: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.POST)
	var varg: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.VARG)
	hero.cell = Vector2i(3, 2)
	post.cell = Vector2i(3, 1)
	varg.cell = Vector2i(2, 2)
	_cast(RuneCorner.Kind.FLOURISH, 1)
	assert_eq(post.hp, SparringRules.DUMMY_HP - SparringRules.FLOURISH_DAMAGE)
	assert_eq(varg.hp, SparringRules.VARG_HP - SparringRules.FLOURISH_DAMAGE)


## The Archer winds up on beat 2 and looses on beat 4, down lane 1.
func _arrow_incoming() -> void:
	_keep([SparringRules.Dummy.Kind.ARCHER])
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


func test_charged_hero_is_exposed_to_hits() -> void:
	_arrow_incoming()
	_cast(RuneCorner.Kind.HEAVY, 4)
	rules.end_turn(4)
	assert_eq(hero.hp, SparringRules.HERO_HP - roundi(SparringRules.STRIKE_DAMAGE * SparringRules.EXPOSED_MULTIPLIER))


func test_dead_dummy_respawns_at_home() -> void:
	_keep([SparringRules.Dummy.Kind.POST])
	var post: SparringRules.Dummy = _beside_post()
	post.hp = 1
	_go(Rune.Dir.LEFT, 1)
	assert_false(post.is_alive())
	rules.end_turn(1 + SparringRules.RESPAWN_BEATS)
	assert_true(post.is_alive())


## Two heroes in the Archer's lane, P1 nearer the Archer.
func _two_in_line() -> SparringRules.Fighter:
	rules = SparringRules.new(2)
	hero = rules.heroes[0]
	var behind: SparringRules.Fighter = rules.heroes[1]
	_keep([SparringRules.Dummy.Kind.ARCHER])
	hero.cell = Vector2i(5, 1)
	behind.cell = Vector2i(4, 1)
	rules.end_turn(2)
	rules.end_turn(3)
	return behind


func test_arrow_stops_at_the_first_hero() -> void:
	var behind: SparringRules.Fighter = _two_in_line()
	watch_signals(rules)
	rules.end_turn(4)
	assert_lt(hero.hp, SparringRules.HERO_HP)
	assert_eq(behind.hp, SparringRules.HERO_HP)
	assert_signal_emitted_with_parameters(rules, "shot", [Vector2i(7, 1), Vector2i(5, 1), "HIT"])


func test_blocking_covers_the_hero_behind() -> void:
	var behind: SparringRules.Fighter = _two_in_line()
	watch_signals(rules)
	_go(Rune.Dir.RIGHT, 4)
	rules.end_turn(4)
	assert_eq(hero.hp, SparringRules.HERO_HP)
	assert_eq(behind.hp, SparringRules.HERO_HP)
	assert_signal_emitted_with_parameters(rules, "shot", [Vector2i(7, 1), Vector2i(5, 1), "BLOCK"])


func test_evading_lets_the_arrow_fly_on_to_the_next() -> void:
	var behind: SparringRules.Fighter = _two_in_line()
	hero.cell = Vector2i(6, 1)
	_cast(RuneCorner.Kind.PRAYER, 3)
	_go(Rune.Dir.LEFT, 4)
	assert_eq(hero.cell, Vector2i(5, 1))
	watch_signals(rules)
	rules.end_turn(4)
	assert_eq(hero.hp, SparringRules.HERO_HP)
	assert_lt(behind.hp, SparringRules.HERO_HP)
	assert_signal_emitted_with_parameters(rules, "shot", [Vector2i(7, 1), Vector2i(4, 1), "HIT"])


func test_blocker_sharing_a_zone_covers_their_partner() -> void:
	var behind: SparringRules.Fighter = _two_in_line()
	behind.cell = Vector2i(5, 1)
	rules.act(1, TurnAction.direction(Rune.Dir.RIGHT, 4))
	rules.end_turn(4)
	assert_eq(hero.hp, SparringRules.HERO_HP)
	assert_eq(behind.hp, SparringRules.HERO_HP)


func test_empty_lane_arrow_flies_off_the_yard() -> void:
	_keep([SparringRules.Dummy.Kind.ARCHER])
	hero.cell = Vector2i(1, 0)
	rules.end_turn(2)
	watch_signals(rules)
	rules.end_turn(4)
	assert_signal_emitted_with_parameters(rules, "shot", [Vector2i(7, 1), Vector2i(-1, 1), "MISS"])


## Only the Draugr, at (5, 0) on its loop from beat 0: attack/move on beats
## 1, 5..., power slam on 3, 7...
func _draugr_at(hero_cell: Vector2i) -> SparringRules.Dummy:
	_keep([SparringRules.Dummy.Kind.DRAUGR])
	hero.cell = hero_cell
	return _dummy(SparringRules.Dummy.Kind.DRAUGR)


func test_draugr_attacks_a_hero_beside_it() -> void:
	var draugr: SparringRules.Dummy = _draugr_at(Vector2i(4, 0))
	rules.end_turn(1)
	assert_eq(hero.hp, SparringRules.HERO_HP - SparringRules.DRAUGR_DAMAGE)
	assert_eq(draugr.cell, Vector2i(5, 0))


func test_draugr_stands_between_steps() -> void:
	var draugr: SparringRules.Dummy = _draugr_at(Vector2i(1, 1))
	rules.end_turn(0)
	rules.end_turn(2)
	assert_eq(draugr.cell, Vector2i(5, 0))
	rules.end_turn(1)
	assert_eq(draugr.cell, Vector2i(4, 0), "attack/move closes the longer gap first")


func test_backing_away_from_attack_move_lets_it_follow() -> void:
	var draugr: SparringRules.Dummy = _draugr_at(Vector2i(4, 0))
	_go(Rune.Dir.LEFT, 1)
	rules.end_turn(1)
	assert_eq(hero.hp, SparringRules.HERO_HP)
	assert_eq(draugr.cell, Vector2i(4, 0))


func test_power_slam_hits_all_around() -> void:
	_draugr_at(Vector2i(5, 1))
	rules.end_turn(3)
	assert_eq(hero.hp, SparringRules.HERO_HP - SparringRules.SLAM_DAMAGE)


func test_backing_away_from_the_slam_makes_distance() -> void:
	var draugr: SparringRules.Dummy = _draugr_at(Vector2i(5, 1))
	_go(Rune.Dir.DOWN, 3)
	rules.end_turn(3)
	assert_eq(hero.hp, SparringRules.HERO_HP)
	assert_eq(draugr.cell, Vector2i(5, 0))


func test_attacking_the_draugr_with_a_shield_blocks_it() -> void:
	var draugr: SparringRules.Dummy = _draugr_at(Vector2i(5, 1))
	_go(Rune.Dir.UP, 1)
	assert_lt(draugr.hp, SparringRules.DRAUGR_HP)
	rules.end_turn(1)
	assert_eq(hero.hp, SparringRules.HERO_HP)


## Only the Varg: it prowls from (7, 1) to (6, 1) on beat 0, with the hero
## in zone 3 of its leap at (3, 1), and readies a leap for beat 1.
func _varg_lined_up(kinds: Array = [SparringRules.Dummy.Kind.VARG]) -> SparringRules.Dummy:
	_keep(kinds)
	var varg: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.VARG)
	varg.cell = Vector2i(7, 1)
	hero.cell = Vector2i(3, 1)
	rules.end_turn(0)
	assert_eq(varg.cell, Vector2i(6, 1))
	assert_true(varg.is_leaping(1))
	return varg


func test_varg_comes_in_line_before_closing() -> void:
	_keep([SparringRules.Dummy.Kind.VARG])
	var varg: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.VARG)
	hero.cell = Vector2i(1, 1)
	rules.end_turn(0)
	assert_eq(varg.cell, Vector2i(6, 1), "into the hero's lane first")
	rules.end_turn(1)
	assert_eq(varg.cell, Vector2i(5, 1), "then closer along it")


func test_varg_leaps_and_lands_short_of_the_hero() -> void:
	var varg: SparringRules.Dummy = _varg_lined_up()
	rules.end_turn(1)
	assert_eq(varg.cell, Vector2i(4, 1))
	assert_eq(hero.hp, SparringRules.HERO_HP - SparringRules.VARG_DAMAGE)


func test_shield_toward_the_varg_halts_both() -> void:
	var varg: SparringRules.Dummy = _varg_lined_up()
	_go(Rune.Dir.RIGHT, 1)
	assert_eq(hero.cell, Vector2i(3, 1), "stood firm")
	rules.end_turn(1)
	assert_eq(varg.cell, Vector2i(4, 1))
	assert_eq(hero.hp, SparringRules.HERO_HP)


func test_moving_into_the_leap_without_a_shield_gets_bitten() -> void:
	rules = SparringRules.new(1, false)
	hero = rules.heroes[0]
	var varg: SparringRules.Dummy = _varg_lined_up()
	_go(Rune.Dir.RIGHT, 1)
	rules.end_turn(1)
	assert_eq(hero.cell, Vector2i(4, 1))
	assert_eq(varg.cell, Vector2i(5, 1))
	assert_eq(hero.hp, SparringRules.HERO_HP - SparringRules.VARG_DAMAGE)


func test_evading_lets_the_varg_pass() -> void:
	var varg: SparringRules.Dummy = _varg_lined_up()
	_cast(RuneCorner.Kind.PRAYER, 0)
	_go(Rune.Dir.RIGHT, 1)
	rules.end_turn(1)
	assert_eq(hero.cell, Vector2i(4, 1))
	assert_eq(varg.cell, Vector2i(3, 1), "landed in the zone the hero left")
	assert_eq(hero.hp, SparringRules.HERO_HP)


func test_sidestepping_the_leap_still_gets_bitten() -> void:
	var varg: SparringRules.Dummy = _varg_lined_up()
	_go(Rune.Dir.UP, 1)
	rules.end_turn(1)
	assert_eq(varg.cell, Vector2i(3, 1))
	assert_eq(hero.hp, SparringRules.HERO_HP - SparringRules.VARG_DAMAGE)


func test_varg_rests_a_beat_after_leaping() -> void:
	var varg: SparringRules.Dummy = _varg_lined_up()
	rules.end_turn(1)
	var hp: int = hero.hp
	rules.end_turn(2)
	assert_eq(hero.hp, hp)
	assert_eq(varg.cell, Vector2i(4, 1))
	assert_true(varg.is_leaping(3), "bites again after its rest")


func test_a_body_in_the_way_cuts_the_leap_short() -> void:
	_dummy(SparringRules.Dummy.Kind.POST).cell = Vector2i(0, 0)
	var varg: SparringRules.Dummy = _varg_lined_up([SparringRules.Dummy.Kind.VARG, SparringRules.Dummy.Kind.POST])
	_dummy(SparringRules.Dummy.Kind.POST).cell = Vector2i(5, 1)
	rules.end_turn(1)
	assert_eq(varg.cell, Vector2i(6, 1))
	assert_eq(hero.hp, SparringRules.HERO_HP)
