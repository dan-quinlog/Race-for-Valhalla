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
	assert_eq(hero.cell, Vector2i(0, 2))
	assert_eq(hero.facing, SparringRules.LEFT)
	_go(Rune.Dir.UP, 2)
	assert_eq(hero.cell, Vector2i(0, 1))
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
	assert_signal_emitted_with_parameters(rules, "shot", [Vector2i(9, 1), Vector2i(5, 1), "HIT"])


func test_blocking_covers_the_hero_behind() -> void:
	var behind: SparringRules.Fighter = _two_in_line()
	watch_signals(rules)
	_go(Rune.Dir.RIGHT, 4)
	rules.end_turn(4)
	assert_eq(hero.hp, SparringRules.HERO_HP)
	assert_eq(behind.hp, SparringRules.HERO_HP)
	assert_signal_emitted_with_parameters(rules, "shot", [Vector2i(9, 1), Vector2i(5, 1), "BLOCK"])


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
	assert_signal_emitted_with_parameters(rules, "shot", [Vector2i(9, 1), Vector2i(4, 1), "HIT"])


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
	assert_signal_emitted_with_parameters(rules, "shot", [Vector2i(9, 1), Vector2i(-1, 1), "MISS"])


## Only the Draugr, at (5, 0) on its loop from beat 0: attack/move on beats
## 1, 5..., power slam on 3, 7...
func _draugr_at(hero_cell: Vector2i) -> SparringRules.Dummy:
	_keep([SparringRules.Dummy.Kind.DRAUGR])
	hero.cell = hero_cell
	var draugr: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.DRAUGR)
	draugr.cell = Vector2i(5, 0)
	return draugr


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
	varg.cell = Vector2i(6, 2)
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


func test_sidestepping_the_leap_dodges_it() -> void:
	var varg: SparringRules.Dummy = _varg_lined_up()
	_go(Rune.Dir.UP, 1)
	rules.end_turn(1)
	assert_eq(varg.cell, Vector2i(3, 1), "lands where the hero stood")
	assert_eq(hero.hp, SparringRules.HERO_HP)


func test_backing_out_of_reach_dodges_the_leap() -> void:
	var varg: SparringRules.Dummy = _varg_lined_up()
	_go(Rune.Dir.LEFT, 1)
	rules.end_turn(1)
	assert_eq(varg.cell, Vector2i(3, 1))
	assert_eq(hero.hp, SparringRules.HERO_HP)


func test_backing_away_within_reach_still_gets_bitten() -> void:
	var varg: SparringRules.Dummy = _varg_lined_up()
	hero.cell = Vector2i(4, 1)
	varg.leap_aim = Vector2i(4, 1)
	_go(Rune.Dir.LEFT, 1)
	rules.end_turn(1)
	assert_eq(varg.cell, Vector2i(4, 1))
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


## Only the Shield-thrall at (5, 1), facing left. Its attack/move steps
## are the odd beats.
func _thrall_at(hero_cell: Vector2i) -> SparringRules.Dummy:
	_keep([SparringRules.Dummy.Kind.THRALL])
	hero.cell = hero_cell
	var thrall: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.THRALL)
	thrall.cell = Vector2i(5, 1)
	return thrall


func test_thrall_thrusts_two_zones_ahead() -> void:
	_thrall_at(Vector2i(3, 1))
	rules.end_turn(0)
	assert_eq(hero.hp, SparringRules.HERO_HP, "stands on even beats")
	rules.end_turn(1)
	assert_eq(hero.hp, SparringRules.HERO_HP - SparringRules.THRUST_DAMAGE)


func test_thrall_turns_and_steps_into_the_heros_lane() -> void:
	var thrall: SparringRules.Dummy = _thrall_at(Vector2i(7, 3))
	rules.end_turn(1)
	assert_eq(thrall.facing, SparringRules.RIGHT)
	assert_eq(thrall.cell, Vector2i(5, 2))


func test_thrall_shield_halves_hits_from_the_front() -> void:
	var thrall: SparringRules.Dummy = _thrall_at(Vector2i(4, 1))
	_go(Rune.Dir.RIGHT, 0)
	assert_eq(thrall.hp, SparringRules.THRALL_HP - roundi(SparringRules.BASIC_DAMAGE * SparringRules.SHIELD_MULTIPLIER))


func test_flanking_the_thrall_lands_in_full() -> void:
	var thrall: SparringRules.Dummy = _thrall_at(Vector2i(5, 0))
	_go(Rune.Dir.DOWN, 0)
	assert_eq(thrall.hp, SparringRules.THRALL_HP - SparringRules.BASIC_DAMAGE)
	hero.cell = Vector2i(6, 1)
	_go(Rune.Dir.LEFT, 2)
	assert_eq(thrall.hp, SparringRules.THRALL_HP - SparringRules.BASIC_DAMAGE * 2, "from behind")


func test_charged_attack_knocks_the_shield_aside() -> void:
	var thrall: SparringRules.Dummy = _thrall_at(Vector2i(4, 1))
	_cast(RuneCorner.Kind.HEAVY, 0)
	_go(Rune.Dir.RIGHT, 2)
	assert_eq(thrall.hp, SparringRules.THRALL_HP - roundi(SparringRules.BASIC_DAMAGE * 1.5), "that blow lands in full")
	assert_false(thrall.is_shielded(3))
	assert_true(thrall.is_shielded(2 + SparringRules.SHIELD_DOWN_BEATS + 1))


func test_thrust_stops_at_the_first_hero() -> void:
	rules = SparringRules.new(2)
	hero = rules.heroes[0]
	var behind: SparringRules.Fighter = rules.heroes[1]
	_thrall_at(Vector2i(4, 1))
	behind.cell = Vector2i(3, 1)
	rules.act(0, TurnAction.direction(Rune.Dir.RIGHT, 1))
	rules.end_turn(1)
	assert_eq(hero.hp, SparringRules.HERO_HP, "blocked while attacking it")
	assert_eq(behind.hp, SparringRules.HERO_HP, "covered by the blocker")


## The boss yard: the Jötunn covers columns 6-7, lanes 1-3. Club Arm at
## (6, 1), Head (7, 1), Legs (7, 3). Its first attack (Club Sweep, the
## column in front) winds up on beat 0 and lands on beat 2.
func _boss_yard() -> SparringRules.Dummy:
	rules = SparringRules.new(1, true, SparringRules.Yard.BOSS)
	hero = rules.heroes[0]
	return rules.dummies[0]


func test_boss_yard_is_bigger_and_holds_the_jotunn() -> void:
	var boss: SparringRules.Dummy = _boss_yard()
	assert_eq(Vector2i(rules.cols, rules.lanes), SparringRules.YARD_SIZE)
	assert_eq(boss.footprint.size(), 6)
	assert_eq(rules.dummy_at(Vector2i(7, 3)), boss)


func test_bumping_a_part_wears_it_and_the_body_takes_more() -> void:
	var boss: SparringRules.Dummy = _boss_yard()
	hero.cell = Vector2i(5, 1)
	_go(Rune.Dir.RIGHT, 0)
	assert_eq(boss.part_at(Vector2i(6, 1)).wear, SparringRules.BASIC_DAMAGE)
	assert_eq(boss.hp, SparringRules.BOSS_HP - SparringRules.BASIC_DAMAGE)
	hero.cell = Vector2i(5, 2)
	_go(Rune.Dir.RIGHT, 1)
	assert_eq(boss.hp, SparringRules.BOSS_HP - SparringRules.BASIC_DAMAGE - roundi(SparringRules.BASIC_DAMAGE * SparringRules.BONUS), "bare body +50%")


func test_breaking_a_part_gives_glory_and_bleeds() -> void:
	var boss: SparringRules.Dummy = _boss_yard()
	hero.cell = Vector2i(7, 0)
	boss.part_at(Vector2i(7, 1)).wear = SparringRules.PART_HP - 1
	_go(Rune.Dir.DOWN, 1)
	assert_true(boss.part_at(Vector2i(7, 1)).broken)
	assert_eq(hero.glory, SparringRules.PART_GLORY)
	var hp: int = boss.hp
	rules.end_turn(1)
	assert_eq(boss.hp, hp - SparringRules.BLEED_PER_WOUND)


func test_flourish_hits_each_boss_zone_it_touches() -> void:
	var boss: SparringRules.Dummy = _boss_yard()
	# An L-shaped body, so one zone touches two of its zones.
	boss.footprint.append(Vector2i(5, 1))
	hero.cell = Vector2i(5, 2)
	_cast(RuneCorner.Kind.FLOURISH, 0)
	var bare: int = roundi(SparringRules.FLOURISH_DAMAGE * SparringRules.BONUS)
	assert_eq(boss.hp, SparringRules.BOSS_HP - bare * 2, "(5, 1) and (6, 2), both bare body")


func test_trip_makes_just_that_zone_vulnerable() -> void:
	var boss: SparringRules.Dummy = _boss_yard()
	hero.cell = Vector2i(5, 1)
	_cast(RuneCorner.Kind.TRIP, 0)
	assert_true(boss.vulnerable_at(Vector2i(6, 1), 1))
	assert_false(boss.vulnerable_at(Vector2i(6, 2), 1))
	assert_false(boss.is_rooted(1))


func test_melee_sweep_is_telegraphed_and_blockable() -> void:
	_boss_yard()
	hero.cell = Vector2i(5, 2)
	rules.end_turn(0)
	assert_eq(rules.dummies[0].strike_kind, SparringRules.HitKind.MELEE)
	assert_has(rules.dummies[0].targets, Vector2i(5, 2))
	rules.end_turn(1)
	_go(Rune.Dir.RIGHT, 2)
	rules.end_turn(2)
	assert_eq(hero.hp, SparringRules.HERO_HP)


func test_beam_hits_everyone_in_line_unless_each_blocks() -> void:
	rules = SparringRules.new(2, true, SparringRules.Yard.BOSS)
	hero = rules.heroes[0]
	var other: SparringRules.Fighter = rules.heroes[1]
	var boss: SparringRules.Dummy = rules.dummies[0]
	boss.slot = 1
	hero.cell = Vector2i(4, 1)
	other.cell = Vector2i(2, 1)
	rules.end_turn(0)
	assert_eq(boss.strike_kind, SparringRules.HitKind.BEAM)
	rules.end_turn(1)
	rules.act(0, TurnAction.direction(Rune.Dir.RIGHT, 2))
	assert_eq(hero.cell, Vector2i(4, 1), "stood firm into the breath")
	rules.end_turn(2)
	assert_eq(hero.hp, SparringRules.HERO_HP)
	assert_lt(other.hp, SparringRules.HERO_HP, "the beam goes past a blocker")


func test_area_can_not_be_blocked_only_evaded() -> void:
	var boss: SparringRules.Dummy = _boss_yard()
	boss.slot = 2
	hero.cell = Vector2i(5, 2)
	rules.end_turn(0)
	assert_eq(boss.strike_kind, SparringRules.HitKind.AREA)
	rules.end_turn(1)
	_go(Rune.Dir.RIGHT, 2)
	rules.end_turn(2)
	assert_lt(hero.hp, SparringRules.HERO_HP, "a shield doesn't stop a stomp")
	hero.hp = SparringRules.HERO_HP
	rules.end_turn(4)
	rules.end_turn(5)
	boss.slot = 2
	boss.strike_beat = 6
	boss.strike_kind = SparringRules.HitKind.AREA
	boss.targets.assign([Vector2i(4, 2), Vector2i(5, 2)])
	_cast(RuneCorner.Kind.PRAYER, 5)
	_go(Rune.Dir.LEFT, 6)
	rules.end_turn(6)
	assert_eq(hero.hp, SparringRules.HERO_HP, "evaded")


func test_broken_part_turns_its_attack_enraged() -> void:
	var boss: SparringRules.Dummy = _boss_yard()
	boss.part_at(Vector2i(6, 1)).broken = true
	hero.cell = Vector2i(0, 4)
	rules.end_turn(0)
	assert_eq(boss.strike_name, "Wild Flail")


func test_bleeding_out_earns_no_glory() -> void:
	var boss: SparringRules.Dummy = _boss_yard()
	boss.part_at(Vector2i(6, 1)).broken = true
	boss.hp = 1
	hero.cell = Vector2i(0, 4)
	rules.end_turn(0)
	assert_false(boss.is_alive())
	assert_eq(hero.glory, 0)


# --- The cave (side view) ---

func _cave(players: int = 1) -> SparringRules.Dummy:
	rules = SparringRules.new(players, true, SparringRules.Yard.CAVE)
	hero = rules.heroes[0]
	return _dummy(SparringRules.Dummy.Kind.BOSS)


func _airborne_at(cell: Vector2i) -> void:
	hero.cell = cell
	hero.was_airborne = true


## Runs end_turn through the boss's wind-up so its first attack lands on
## beat 2, after `before_land` (if any) acts on beat 2.
func _boss_lands(before_land: Callable = Callable()) -> void:
	rules.end_turn(0)
	rules.end_turn(1)
	if before_land.is_valid():
		before_land.call()
	rules.end_turn(2)


func test_cave_terrain_and_boss() -> void:
	var boss: SparringRules.Dummy = _cave()
	assert_eq(Vector2i(rules.cols, rules.lanes), SparringRules.CAVE_SIZE)
	assert_eq(boss.footprint.size(), 18)
	assert_eq(rules.zone_of(Vector2i(3, 0)).ground, SparringRules.Ground.VINES)
	assert_eq(rules.zone_of(Vector2i(3, 1)).ground, SparringRules.Ground.LEDGE)
	assert_eq(rules.zone_of(Vector2i(3, 2)).ground, SparringRules.Ground.VINES)
	assert_eq(rules.zone_of(Vector2i(3, 3)).ground, SparringRules.Ground.AIR)
	assert_eq(rules.zone_of(Vector2i(0, 0)).ground, SparringRules.Ground.LADDER)
	assert_true(rules.is_depth_row(4) and rules.is_depth_row(5))
	assert_false(rules.is_depth_row(3))
	assert_almost_eq(rules.world_size().y, 4.0 + 2.0 * SparringRules.DEPTH_ROW_HEIGHT, 0.001)


func test_ground_lanes_are_depth_but_going_up_needs_a_ladder() -> void:
	_cave()
	_keep([])
	hero.cell = Vector2i(3, 5)
	_go(Rune.Dir.UP, 0)
	assert_eq(hero.cell, Vector2i(3, 4), "the two ground lanes are one level")
	_go(Rune.Dir.UP, 1)
	assert_eq(hero.cell, Vector2i(3, 4), "no climbing into the air")
	hero.cell = Vector2i(0, 4)
	_go(Rune.Dir.UP, 2)
	assert_eq(hero.cell, Vector2i(0, 3), "the ladder goes up")
	hero.cell = Vector2i(3, 1)
	_go(Rune.Dir.UP, 3)
	assert_eq(hero.cell, Vector2i(3, 1), "no moving up off the catwalk")


func test_dropping_off_the_catwalk_falls_a_zone_a_beat() -> void:
	_cave()
	_keep([])
	hero.cell = Vector2i(3, 1)
	_go(Rune.Dir.DOWN, 0)
	rules.end_turn(0)
	assert_eq(hero.cell, Vector2i(3, 2), "no fall on the beat you stepped off")
	rules.end_turn(1)
	assert_eq(hero.cell, Vector2i(3, 3))
	rules.end_turn(2)
	assert_eq(hero.cell, Vector2i(3, 4), "landed on the ground")
	rules.end_turn(3)
	assert_eq(hero.cell, Vector2i(3, 4))


func test_moving_while_falling_drifts() -> void:
	_cave()
	_keep([])
	_airborne_at(Vector2i(3, 3))
	_go(Rune.Dir.LEFT, 0)
	rules.end_turn(0)
	assert_eq(hero.cell, Vector2i(2, 4))


func test_a_hang_holds_for_the_free_beat_then_falls() -> void:
	_cave()
	_keep([])
	_airborne_at(Vector2i(3, 2))
	_go(Rune.Dir.UP, 0)
	rules.end_turn(0)
	assert_eq(hero.cell, Vector2i(3, 2))
	assert_true(rules.is_hanging(hero))
	_go(Rune.Dir.LEFT, 1)
	rules.end_turn(1)
	assert_eq(hero.cell, Vector2i(2, 2), "the free beat moved along the vines")
	rules.end_turn(2)
	assert_eq(hero.cell, Vector2i(2, 3), "no new hang: falls")


func test_up_after_a_hang_climbs_onto_the_catwalk() -> void:
	_cave()
	_keep([])
	_airborne_at(Vector2i(3, 2))
	_go(Rune.Dir.UP, 0)
	rules.end_turn(0)
	_go(Rune.Dir.UP, 1)
	rules.end_turn(1)
	assert_eq(hero.cell, Vector2i(3, 1))
	assert_false(rules.is_airborne(hero))


func test_plunge_finds_a_foe_on_the_near_ground_lane() -> void:
	_cave()
	_keep([SparringRules.Dummy.Kind.RUNNER])
	var runner: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.RUNNER)
	runner.cell = Vector2i(3, 5)
	_airborne_at(Vector2i(3, 2))
	_go(Rune.Dir.DOWN, 0)
	var dmg: int = roundi(SparringRules.BASIC_DAMAGE * (1.0 + SparringRules.PLUNGE_BONUS_PER_LANE * 3))
	assert_eq(runner.hp, SparringRules.RUNNER_HP - dmg, "+25% for each of 3 lanes")
	assert_eq(runner.cell, Vector2i(4, 5), "pushed the way the hero faces")
	assert_eq(hero.cell, Vector2i(3, 5))


func test_a_killing_plunge_takes_the_zone() -> void:
	_cave()
	_keep([SparringRules.Dummy.Kind.RUNNER])
	var runner: SparringRules.Dummy = _dummy(SparringRules.Dummy.Kind.RUNNER)
	runner.cell = Vector2i(3, 4)
	runner.hp = 5
	_airborne_at(Vector2i(3, 3))
	_go(Rune.Dir.DOWN, 0)
	assert_false(runner.is_alive())
	assert_eq(hero.cell, Vector2i(3, 4))
	assert_eq(hero.glory, SparringRules.KILL_GLORY)


func test_a_plunge_onto_nothing_lands() -> void:
	_cave()
	_keep([])
	_airborne_at(Vector2i(3, 2))
	_go(Rune.Dir.DOWN, 0)
	assert_eq(hero.cell, Vector2i(3, 4))


func test_the_jotunn_alternates_each_parts_two_attacks() -> void:
	_cave()
	_keep([SparringRules.Dummy.Kind.BOSS])
	hero.cell = Vector2i(1, 5)
	var names: Array[String] = []
	for n: int in 21:
		rules.end_turn(n)
		if n % 4 == 0:
			names.append(rules.dummies[0].strike_name)
	assert_eq(names, ["Kick", "Headbutt", "Uppercut", "Stomp", "Frost Breath", "Club Sweep"] as Array[String])


func test_kick_knocks_each_hero_from_where_they_stood() -> void:
	_cave(2)
	_keep([SparringRules.Dummy.Kind.BOSS])
	var other: SparringRules.Fighter = rules.heroes[1]
	hero.cell = Vector2i(5, 5)
	other.cell = Vector2i(6, 5)
	_boss_lands()
	assert_eq(hero.cell, Vector2i(3, 4), "up 1, left 2")
	assert_eq(other.cell, Vector2i(4, 4), "neighbours end as neighbours")
	assert_eq(hero.hp, SparringRules.HERO_HP - 12)


func test_blocking_the_kick_only_pushes_to_its_edge() -> void:
	_cave()
	_keep([SparringRules.Dummy.Kind.BOSS])
	hero.cell = Vector2i(5, 5)
	_boss_lands(func() -> void: _go(Rune.Dir.RIGHT, 2))
	assert_eq(hero.hp, SparringRules.HERO_HP)
	assert_eq(hero.cell, Vector2i(4, 4), "out of the kick, not the full knockback")


func test_uppercut_on_the_catwalk_crushes_into_the_ceiling() -> void:
	var boss: SparringRules.Dummy = _cave()
	_keep([SparringRules.Dummy.Kind.BOSS])
	boss.slot = 2
	hero.cell = Vector2i(6, 1)
	_boss_lands()
	assert_eq(boss.strike_name, "Uppercut")
	assert_eq(hero.cell, Vector2i(6, 0))
	assert_eq(hero.hp, SparringRules.HERO_HP - 12 - SparringRules.CRUSH_DAMAGE)


func test_blocking_the_uppercut_downward_lands_on_the_ceiling_vines() -> void:
	var boss: SparringRules.Dummy = _cave()
	_keep([SparringRules.Dummy.Kind.BOSS])
	boss.slot = 2
	hero.cell = Vector2i(6, 1)
	_boss_lands(func() -> void: _go(Rune.Dir.DOWN, 2))
	assert_eq(hero.hp, SparringRules.HERO_HP, "a shield facing down blocks it")
	assert_eq(hero.cell, Vector2i(6, 0))
	_go(Rune.Dir.UP, 3)
	rules.end_turn(3)
	assert_eq(hero.cell, Vector2i(6, 0), "caught the vines")


func test_headbutt_knocks_off_the_catwalk_into_the_air() -> void:
	var boss: SparringRules.Dummy = _cave()
	_keep([SparringRules.Dummy.Kind.BOSS])
	boss.slot = 1
	hero.cell = Vector2i(6, 1)
	_boss_lands()
	assert_eq(boss.strike_name, "Headbutt")
	assert_eq(hero.cell, Vector2i(4, 3), "down 2, left 2")
	rules.end_turn(3)
	assert_eq(hero.cell, Vector2i(4, 4), "falls on the next beat")


func test_blocking_the_headbutt_drops_only_to_the_vines() -> void:
	var boss: SparringRules.Dummy = _cave()
	_keep([SparringRules.Dummy.Kind.BOSS])
	boss.slot = 1
	hero.cell = Vector2i(6, 1)
	_boss_lands(func() -> void: _go(Rune.Dir.RIGHT, 2))
	assert_eq(hero.hp, SparringRules.HERO_HP)
	assert_eq(hero.cell, Vector2i(6, 2))


func test_a_zone_closed_to_forced_entry_stops_knockback_with_a_crush() -> void:
	_cave()
	_keep([SparringRules.Dummy.Kind.BOSS])
	rules.zone_of(Vector2i(4, 4)).forced_entry = false
	hero.cell = Vector2i(5, 5)
	_boss_lands()
	assert_eq(hero.cell, Vector2i(5, 4))
	assert_eq(hero.hp, SparringRules.HERO_HP - 12 - SparringRules.CRUSH_DAMAGE)


func test_pinned_short_of_the_edge_is_crushed_and_stunned() -> void:
	var boss: SparringRules.Dummy = _cave()
	_keep([SparringRules.Dummy.Kind.BOSS])
	boss.strike_beat = 1
	boss.strike_kind = SparringRules.HitKind.MELEE
	boss.strike_name = "Shove"
	boss.strike_damage = 10
	boss.strike_knock = Vector2i(-2, 0)
	boss.strike_guard = Rune.Dir.RIGHT
	boss.targets.assign([Vector2i(0, 5), Vector2i(1, 5)])
	hero.cell = Vector2i(1, 5)
	_go(Rune.Dir.RIGHT, 1)
	rules.end_turn(1)
	assert_eq(hero.cell, Vector2i(0, 5), "stopped in the attack's last zone")
	assert_eq(hero.hp, SparringRules.HERO_HP - SparringRules.CRUSH_DAMAGE)
	_go(Rune.Dir.RIGHT, 2)
	assert_eq(hero.cell, Vector2i(0, 5), "stunned for the next beat")
