extends GutTest

var rules: StageRules


## A one-chunk stage. Pass enemies to place them by hand instead of spawns.
func _rules(rows: Array[String], players: int = 1, enemies: Array[Enemy] = []) -> StageRules:
	rules = StageRules.new(StageMap.build([StageChunk.from_rows(rows)]), players, enemies)
	return rules


## Start column, then two 4-column encounters. A brute in each; the door is
## at the far right of the second.
func _scrolling(players: int = 1) -> StageRules:
	var chunks: Array[StageChunk] = [
		StageChunk.from_rows([".", "1", "2"]),
		StageChunk.from_rows(["....", "...B", "...."], true),
		StageChunk.from_rows(["....", "...B", "...D"], true),
	]
	rules = StageRules.new(StageMap.build(chunks), players)
	return rules


func _action(kind: RuneAction.Kind, dir: Rune.Dir, beat: int, perfect: bool = false, empowered: bool = false) -> RuneAction:
	var a := RuneAction.new()
	a.kind = kind
	a.dir = dir
	a.beat = beat
	a.perfect = perfect
	a.empowered = empowered
	if kind == RuneAction.Kind.ATTACK:
		a.attack = RuneAction.ATTACK_BY_DIR[dir]
	return a


func _move(dir: Rune.Dir, beat: int, player: int = 0, warded: bool = false) -> String:
	return rules.act(player, _action(RuneAction.Kind.MOVE, dir, beat, false, warded))


func _attack(dir: Rune.Dir, beat: int, perfect: bool = false, blessed: bool = false) -> String:
	return rules.act(0, _action(RuneAction.Kind.ATTACK, dir, beat, perfect, blessed))


func _brace(dir: Rune.Dir, beat: int, blessed: bool = false, player: int = 0) -> String:
	return rules.act(player, _action(RuneAction.Kind.BRACE, dir, beat, false, blessed))


func _hero(p: int = 0) -> Hero:
	return rules.heroes[p]


func _own_zone_foe(cell: Vector2i, windup: int = 2, damage: int = 10) -> PatternEnemy:
	var p: Array[EnemyMove] = [EnemyMove.new("Swipe", EnemyMove.Target.OWN_ZONE, windup, damage, 5)]
	return PatternEnemy.new("Foe", 100, cell, p)


# --- Movement ---------------------------------------------------------------

func test_moves_across_lanes_and_columns() -> void:
	_rules(["....", "1...", "...."])
	_move(Rune.Dir.UP, 1)
	assert_eq(_hero().cell, Vector2i(0, 0))
	_move(Rune.Dir.DOWN, 3)
	_move(Rune.Dir.DOWN, 5)
	assert_eq(_hero().cell, Vector2i(0, 2))
	_move(Rune.Dir.RIGHT, 7)
	assert_eq(_hero().cell, Vector2i(1, 2))
	_move(Rune.Dir.LEFT, 9)
	assert_eq(_hero().cell, Vector2i(0, 2))


func test_walls_and_edges_hold_position() -> void:
	_rules(["1#..", "....", "...."])
	assert_string_contains(_move(Rune.Dir.RIGHT, 1), "holds position")
	_move(Rune.Dir.UP, 3)
	_move(Rune.Dir.LEFT, 5)
	assert_eq(_hero().cell, Vector2i(0, 0))


# --- Camera and encounters --------------------------------------------------

func test_camera_follows_lead_then_locks_at_encounter() -> void:
	_scrolling()
	_move(Rune.Dir.RIGHT, 1)
	_move(Rune.Dir.RIGHT, 3)
	assert_eq(rules.camera_col, 0)
	_move(Rune.Dir.RIGHT, 5)
	assert_eq(rules.camera_col, 1, "first encounter fills the screen")
	assert_true(rules.is_locked())
	_move(Rune.Dir.RIGHT, 7)
	assert_string_contains(_move(Rune.Dir.RIGHT, 9), "holds position", "the screen edge stops the hero")
	assert_eq(rules.camera_col, 1)


func test_clearing_encounter_resumes_scrolling() -> void:
	_scrolling()
	for beat: int in [1, 3, 5, 7]:
		_move(Rune.Dir.RIGHT, beat)
	assert_eq(_hero().cell, Vector2i(4, 1))
	rules.enemies[0].hp = 0
	rules._update_clears()
	assert_true(rules.cleared[0])
	assert_eq(rules.camera_col, 2, "camera catches up with the lead hero")
	assert_true(rules.can_advance())
	for beat: int in [11, 13, 15]:
		_move(Rune.Dir.RIGHT, beat)
	assert_eq(rules.camera_col, 5, "a full screen on, locked at the second encounter")
	assert_true(rules.is_locked())


func test_camera_keeps_trailing_hero_on_screen() -> void:
	_scrolling(2)
	for beat: int in [1, 3, 5]:
		_move(Rune.Dir.RIGHT, beat)
	assert_eq(rules.camera_col, 0)
	_move(Rune.Dir.RIGHT, 7, 1)
	assert_eq(rules.camera_col, 1)


func test_off_screen_enemies_wait() -> void:
	_scrolling()
	rules.close_beat(10)
	var far: Enemy = rules.enemies[1]
	assert_eq(far.cell, Vector2i(8, 1))
	assert_false(far.is_winding())


func test_door_opens_when_all_areas_clear_and_heroes_reach_it() -> void:
	_scrolling()
	watch_signals(rules)
	var door: Vector2i = rules.map.door
	_hero().cell = door
	rules.enemies[0].hp = 0
	rules.enemies[1].hp = 0
	rules._update_clears()
	assert_true(rules.door_open)
	assert_signal_emitted(rules, "door_opened")
	assert_true(rules.won, "already standing on the door")


func test_door_needs_every_living_hero() -> void:
	_scrolling(2)
	for e: Enemy in rules.enemies:
		e.hp = 0
	rules._update_clears()
	rules.camera_col = 5
	_hero(0).cell = rules.map.door + Vector2i(0, -1)
	_move(Rune.Dir.DOWN, 1)
	assert_false(rules.over)
	_hero(1).hp = 0
	_move(Rune.Dir.LEFT, 3)
	_move(Rune.Dir.RIGHT, 5)
	assert_true(rules.won)


func test_door_closed_until_cleared() -> void:
	_scrolling()
	rules.camera_col = 5
	_hero().cell = rules.map.door + Vector2i(-1, 0)
	_move(Rune.Dir.RIGHT, 1)
	assert_false(rules.over)


# --- Attacks ----------------------------------------------------------------

func test_attack_needs_same_zone() -> void:
	var foe := _own_zone_foe(Vector2i(1, 1))
	_rules(["....", "1...", "...."], 1, [foe])
	assert_string_contains(_attack(Rune.Dir.LEFT, 1), "hits nothing")
	_hero().cell = Vector2i(1, 1)
	_attack(Rune.Dir.LEFT, 3)
	assert_eq(foe.hp, 90)


func test_perfect_and_blessed_bonuses_stack() -> void:
	assert_eq(StageRules.attack_damage(RuneAction.Attack.STANDARD, false, false), 10)
	assert_eq(StageRules.attack_damage(RuneAction.Attack.STANDARD, true, false), 15)
	assert_eq(StageRules.attack_damage(RuneAction.Attack.HEAVY, true, true), 40)
	assert_eq(StageRules.attack_damage(RuneAction.Attack.TRIP, false, false), 4)


func test_trip_staggers_and_reports_back_on_beat() -> void:
	var p: Array[EnemyMove] = [EnemyMove.new("Wrath", EnemyMove.Target.OWN_ZONE, 5, 20, 3, true)]
	var foe := PatternEnemy.new("Foe", 100, Vector2i(0, 1), p)
	_rules(["....", "1...", "...."], 1, [foe])
	rules.close_beat(0)
	assert_true(foe.is_off_beat())
	assert_string_contains(_attack(Rune.Dir.DOWN, 2), "back onto the beat")
	assert_eq(foe.hit_beat, 6)


func test_defensive_halves_next_hit() -> void:
	var foe := _own_zone_foe(Vector2i(0, 1))
	_rules(["....", "1...", "...."], 1, [foe])
	rules.close_beat(0)
	_attack(Rune.Dir.RIGHT, 1)
	assert_eq(foe.hp, 94)
	rules.close_beat(2)
	assert_eq(_hero().hp, StageRules.HERO_HP - 5)


func test_heavy_exposes_until_next_command() -> void:
	var foe := _own_zone_foe(Vector2i(0, 1))
	_rules(["....", "1...", "...."], 1, [foe])
	rules.close_beat(0)
	_attack(Rune.Dir.UP, 1)
	rules.close_beat(2)
	assert_eq(_hero().hp, StageRules.HERO_HP - 15)
	rules.act(0, _action(RuneAction.Kind.PRAY, Rune.Dir.UP, 4))
	assert_false(_hero().exposed)


# --- Enemy hits, braces and wards ----------------------------------------------

func test_dodging_out_of_target_zone_avoids_hit() -> void:
	var foe := _own_zone_foe(Vector2i(0, 1))
	_rules(["....", "1...", "...."], 1, [foe])
	rules.close_beat(0)
	_move(Rune.Dir.UP, 2)
	rules.close_beat(2)
	assert_eq(_hero().hp, StageRules.HERO_HP)


func test_any_brace_blocks_a_hit_in_your_zone() -> void:
	var foe := _own_zone_foe(Vector2i(0, 1))
	_rules(["....", "1...", "...."], 1, [foe])
	rules.close_beat(0)
	_brace(Rune.Dir.LEFT, 2)
	rules.close_beat(2)
	assert_eq(_hero().hp, StageRules.HERO_HP)


func test_arrow_needs_a_brace_facing_right() -> void:
	var ranger := RangerEnemy.new(Vector2i(3, 1))
	_rules(["....", "1...", "...."], 1, [ranger])
	rules.close_beat(0)
	assert_true(ranger.is_winding())
	_brace(Rune.Dir.RIGHT, 2)
	rules.close_beat(2)
	assert_eq(_hero().hp, StageRules.HERO_HP)
	rules.close_beat(4)
	_brace(Rune.Dir.LEFT, 6)
	rules.close_beat(6)
	assert_eq(_hero().hp, StageRules.HERO_HP - RangerEnemy.ARROW_DAMAGE, "braced the wrong way")


func test_arrow_stops_at_the_first_hero_in_line() -> void:
	var ranger := RangerEnemy.new(Vector2i(3, 1))
	_rules(["....", "1...", "...."], 2, [ranger])
	_hero(1).cell = Vector2i(2, 1)
	rules.close_beat(2)
	assert_eq(_hero(1).hp, StageRules.HERO_HP - RangerEnemy.ARROW_DAMAGE)
	assert_eq(_hero(0).hp, StageRules.HERO_HP)


func test_braced_hero_shields_the_one_behind() -> void:
	var ranger := RangerEnemy.new(Vector2i(3, 1))
	_rules(["....", "1...", "...."], 2, [ranger])
	_hero(1).cell = Vector2i(2, 1)
	rules.close_beat(0)
	_brace(Rune.Dir.RIGHT, 2, false, 1)
	rules.close_beat(2)
	assert_eq(_hero(0).hp, StageRules.HERO_HP)
	assert_eq(_hero(1).hp, StageRules.HERO_HP)


func test_blessed_brace_retaliates() -> void:
	var foe := _own_zone_foe(Vector2i(0, 1))
	_rules(["....", "1...", "...."], 1, [foe])
	rules.close_beat(0)
	_brace(Rune.Dir.LEFT, 2, true)
	rules.close_beat(2)
	assert_eq(foe.hp, 100 - StageRules.RETALIATE_DAMAGE)


func test_warded_move_ignores_hits() -> void:
	var p: Array[EnemyMove] = [EnemyMove.new("Howl", EnemyMove.Target.ALL_ZONES, 2, 10, 5)]
	_rules(["....", "1...", "...."], 1, [PatternEnemy.new("Foe", 100, Vector2i(3, 1), p)])
	rules.close_beat(0)
	_move(Rune.Dir.RIGHT, 2, 0, true)
	rules.close_beat(2)
	assert_eq(_hero().hp, StageRules.HERO_HP)


func test_actions_close_earlier_beats_first() -> void:
	var foe := _own_zone_foe(Vector2i(0, 1))
	_rules(["....", "1...", "...."], 1, [foe])
	rules.close_beat(0)
	_brace(Rune.Dir.RIGHT, 3)
	assert_eq(rules.closed_through, 2)
	assert_eq(_hero().hp, StageRules.HERO_HP - 10)


# --- Fire ---------------------------------------------------------------------

func test_fire_burns_on_its_on_beats() -> void:
	_rules(["1F..", ".F..", ".F.."])
	_move(Rune.Dir.RIGHT, 1)
	rules.close_beat(3)
	assert_eq(_hero().hp, StageRules.HERO_HP, "quiet for 4 beats")
	rules.close_beat(4)
	assert_eq(_hero().hp, StageRules.HERO_HP - FireTrap.DAMAGE)
	rules.close_beat(5)
	assert_eq(_hero().hp, StageRules.HERO_HP - FireTrap.DAMAGE * 2)


func test_passing_through_fire_while_quiet_is_safe() -> void:
	_rules(["1F..", ".F..", ".F.."])
	_move(Rune.Dir.RIGHT, 1)
	_move(Rune.Dir.RIGHT, 3)
	rules.close_beat(5)
	assert_eq(_hero().hp, StageRules.HERO_HP)


func test_brace_does_not_stop_fire_but_ward_does() -> void:
	_rules(["1F..", ".F..", ".F.."])
	_move(Rune.Dir.RIGHT, 1)
	_brace(Rune.Dir.RIGHT, 4)
	rules.close_beat(4)
	assert_eq(_hero().hp, StageRules.HERO_HP - FireTrap.DAMAGE)
	_move(Rune.Dir.UP, 5, 0, true)
	rules.close_beat(5)
	assert_eq(_hero().hp, StageRules.HERO_HP - FireTrap.DAMAGE)


# --- Winning, losing and rhythm ------------------------------------------------

func test_all_heroes_dead_loses() -> void:
	_rules(["....", "1...", "...."], 1, [_own_zone_foe(Vector2i(0, 1), 2, 999)])
	rules.close_beat(2)
	assert_true(rules.over)
	assert_false(rules.won)
	assert_eq(_attack(Rune.Dir.LEFT, 3), "")


func test_one_fallen_hero_does_not_end_coop() -> void:
	_rules(["....", "1...", "2..."], 2, [_own_zone_foe(Vector2i(0, 1), 2, 999)])
	rules.close_beat(2)
	assert_false(_hero(0).is_alive())
	assert_false(rules.over)


## A player on an even-beat flow starts a brace, sees the hit is off the beat,
## skips one beat, and braces onto the odd hit beat instead. Combo survives.
func test_skipping_a_beat_resyncs_brace_with_off_beat_hit() -> void:
	var p: Array[EnemyMove] = [EnemyMove.new("Wrath", EnemyMove.Target.ALL_ZONES, 5, 20, 3, true)]
	_rules(["....", "1...", "...."], 1, [PatternEnemy.new("Foe", 100, Vector2i(3, 1), p)])
	var player := PlayerRhythm.new(0.6, 0.15, 0.04)
	var feed := func(rune: Rune.Dir, beat: int) -> void:
		var r: PlayerRhythm.Result = player.submit(rune, 0.6 * beat)
		if r.action != null:
			rules.act(0, r.action)
	rules.close_beat(0)
	feed.call(Rune.Dir.RIGHT, 2)
	rules.close_beat(2)
	player.reader.on_beat(3)
	player.reader.on_beat(4)
	feed.call(Rune.Dir.RIGHT, 4)
	feed.call(Rune.Dir.LEFT, 5)
	rules.close_beat(5)
	assert_eq(_hero().hp, StageRules.HERO_HP, "brace completed on the off-beat hit")
	assert_eq(player.combo.combo, 3)


## Plays the Draugr until `count` hits land, optionally Tripping each super
## once. Returns each hit as "<move>:<beat parity>".
func _play_draugr(count: int, trip_supers: bool) -> Array[String]:
	var draugr: PatternEnemy = PatternEnemy.draugr(Vector2i(1, 1))
	_rules(["....", ".1..", "...."], 1, [draugr])
	_hero().hp = 100000
	_hero().max_hp = 100000
	var out: Array[String] = []
	var tripped: bool = false
	var beat: int = 0
	while out.size() < count and beat < 500:
		if trip_supers and draugr.is_winding() and draugr.current.is_super and not tripped:
			_attack(Rune.Dir.DOWN, beat)
			tripped = true
		var hit: int = draugr.hit_beat
		var move: EnemyMove = draugr.current
		rules.close_beat(beat)
		if move != null and hit == beat:
			out.append("%s:%d" % [move.display_name, posmod(beat, Enemy.CADENCE)])
			tripped = false
		beat += 1
	return out


func test_untripped_super_shifts_the_enemy_off_beat() -> void:
	assert_eq(_play_draugr(10, false), [
		"Grave Claw:0", "Barrow Slam:0", "Death Howl:0", "Grave Claw:0", "Grave Wrath:1",
		"Grave Claw:1", "Barrow Slam:1", "Death Howl:1", "Grave Claw:1", "Grave Wrath:0",
	])


func test_tripping_supers_keeps_the_enemy_on_beat() -> void:
	assert_eq(_play_draugr(10, true), [
		"Grave Claw:0", "Barrow Slam:0", "Death Howl:0", "Grave Claw:0", "Grave Wrath:0",
		"Grave Claw:0", "Barrow Slam:0", "Death Howl:0", "Grave Claw:0", "Grave Wrath:0",
	])
