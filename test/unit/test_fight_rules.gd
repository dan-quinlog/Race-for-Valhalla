extends GutTest

var rules: FightRules


func before_each() -> void:
	rules = FightRules.new(1, _enemy(EnemyMove.Target.HERO_ROOM))


## An enemy with one 2-beat wind-up move that starts on beat 0 and lands on beat 2.
func _enemy(target: EnemyMove.Target, damage: int = 10) -> Enemy:
	var pattern: Array[EnemyMove] = [EnemyMove.new("Swipe", target, 2, damage, 5)]
	return Enemy.new("Foe", 100, 1, pattern, 0)


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


func _attack(attack_dir: Rune.Dir, beat: int, perfect: bool = false, empowered: bool = false) -> RuneAction:
	return _action(RuneAction.Kind.ATTACK, attack_dir, beat, perfect, empowered)


func _hero() -> Hero:
	return rules.heroes[0]


func test_heroes_start_on_the_sides() -> void:
	var two := FightRules.new(2)
	assert_eq(two.heroes[0].room, 0)
	assert_eq(two.heroes[1].room, 2)
	assert_eq(two.enemy.room, FightRules.ENEMY_ROOM)


func test_move_changes_room_and_clamps() -> void:
	rules.act(0, _action(RuneAction.Kind.MOVE, Rune.Dir.LEFT, 1))
	assert_eq(_hero().room, 0)
	rules.act(0, _action(RuneAction.Kind.MOVE, Rune.Dir.RIGHT, 3))
	assert_eq(_hero().room, 1)
	rules.act(0, _action(RuneAction.Kind.MOVE, Rune.Dir.UP, 5))
	assert_eq(_hero().room, 1)


func test_attack_needs_same_room() -> void:
	rules.act(0, _attack(Rune.Dir.LEFT, 1))
	assert_eq(rules.enemy.hp, 100)
	_hero().room = 1
	rules.act(0, _attack(Rune.Dir.LEFT, 3))
	assert_eq(rules.enemy.hp, 90)


func test_perfect_and_blessed_bonuses_stack() -> void:
	assert_eq(FightRules.attack_damage(RuneAction.Attack.STANDARD, false, false), 10)
	assert_eq(FightRules.attack_damage(RuneAction.Attack.STANDARD, true, false), 15)
	assert_eq(FightRules.attack_damage(RuneAction.Attack.HEAVY, true, true), 40)
	assert_eq(FightRules.attack_damage(RuneAction.Attack.TRIP, false, false), 4)


func test_trip_staggers_enemy() -> void:
	_hero().room = 1
	rules.close_beat(0)
	assert_eq(rules.enemy.hit_beat, 2)
	rules.act(0, _attack(Rune.Dir.DOWN, 1))
	assert_eq(rules.enemy.hit_beat, 3)
	assert_eq(rules.enemy.hp, 96)


func test_enemy_hit_lands_when_beat_closes() -> void:
	rules.close_beat(1)
	assert_eq(_hero().hp, FightRules.HERO_HP)
	rules.close_beat(2)
	assert_eq(_hero().hp, FightRules.HERO_HP - 10)
	assert_false(rules.enemy.is_winding())


func test_dodging_out_of_target_room_avoids_hit() -> void:
	rules.close_beat(0)  # wind-up targets the left room
	rules.act(0, _action(RuneAction.Kind.MOVE, Rune.Dir.RIGHT, 2))
	rules.close_beat(2)
	assert_eq(_hero().hp, FightRules.HERO_HP)


func test_brace_on_hit_beat_blocks() -> void:
	rules.close_beat(0)
	rules.act(0, _action(RuneAction.Kind.BRACE, Rune.Dir.RIGHT, 2))
	rules.close_beat(2)
	assert_eq(_hero().hp, FightRules.HERO_HP)


func test_brace_covers_next_beat_only() -> void:
	rules.close_beat(0)
	rules.act(0, _action(RuneAction.Kind.BRACE, Rune.Dir.RIGHT, 1))
	rules.close_beat(2)
	assert_eq(_hero().hp, FightRules.HERO_HP)
	rules = FightRules.new(1, _enemy(EnemyMove.Target.HERO_ROOM))
	rules.act(0, _action(RuneAction.Kind.BRACE, Rune.Dir.RIGHT, 0))
	rules.close_beat(2)
	assert_eq(_hero().hp, FightRules.HERO_HP - 10)


func test_blessed_brace_retaliates() -> void:
	rules.close_beat(0)
	rules.act(0, _action(RuneAction.Kind.BRACE, Rune.Dir.LEFT, 2, false, true))
	rules.close_beat(2)
	assert_eq(rules.enemy.hp, 100 - FightRules.RETALIATE_DAMAGE)


func test_warded_move_ignores_room_damage() -> void:
	rules = FightRules.new(1, _enemy(EnemyMove.Target.ALL_ROOMS))
	rules.close_beat(0)
	rules.act(0, _action(RuneAction.Kind.MOVE, Rune.Dir.RIGHT, 2, false, true))
	rules.close_beat(2)
	assert_eq(_hero().hp, FightRules.HERO_HP)


func test_heavy_exposes_until_next_command() -> void:
	rules.close_beat(0)
	rules.act(0, _attack(Rune.Dir.UP, 1))
	rules.close_beat(2)
	assert_eq(_hero().hp, FightRules.HERO_HP - 15)
	rules.act(0, _action(RuneAction.Kind.PRAY, Rune.Dir.UP, 4))
	assert_false(_hero().exposed)


func test_defensive_halves_next_hit() -> void:
	_hero().room = 1
	rules.close_beat(0)  # targets the center room
	rules.act(0, _attack(Rune.Dir.RIGHT, 1))
	assert_eq(rules.enemy.hp, 94)
	rules.close_beat(2)
	assert_eq(_hero().hp, FightRules.HERO_HP - 5)
	assert_false(_hero().guarded)


func test_actions_close_earlier_beats_first() -> void:
	rules.close_beat(0)
	# The hit on beat 2 must land before a brace completing on beat 3.
	rules.act(0, _action(RuneAction.Kind.BRACE, Rune.Dir.RIGHT, 3))
	assert_eq(rules.closed_through, 2)
	assert_eq(_hero().hp, FightRules.HERO_HP - 10)


func test_killing_enemy_wins() -> void:
	watch_signals(rules)
	_hero().room = 1
	rules.enemy.hp = 5
	rules.act(0, _attack(Rune.Dir.LEFT, 1))
	assert_true(rules.over)
	assert_true(rules.won)
	assert_signal_emitted_with_parameters(rules, "ended", [true])
	rules.close_beat(5)
	assert_eq(_hero().hp, FightRules.HERO_HP)


func test_all_heroes_dead_loses() -> void:
	rules = FightRules.new(1, _enemy(EnemyMove.Target.HERO_ROOM, 999))
	rules.close_beat(2)
	assert_false(_hero().is_alive())
	assert_true(rules.over)
	assert_false(rules.won)
	assert_eq(rules.act(0, _attack(Rune.Dir.LEFT, 3)), "")


func test_one_fallen_hero_does_not_end_coop() -> void:
	rules = FightRules.new(2, _enemy(EnemyMove.Target.HERO_ROOM, 999))
	rules.close_beat(2)
	assert_false(rules.heroes[0].is_alive())
	assert_false(rules.over)


func test_tripping_super_puts_it_back_on_the_beat() -> void:
	var pattern: Array[EnemyMove] = [EnemyMove.new("Wrath", EnemyMove.Target.ALL_ROOMS, 5, 20, 3, true)]
	rules = FightRules.new(1, Enemy.new("Foe", 100, 1, pattern, 0))
	_hero().room = 1
	rules.close_beat(0)
	assert_true(rules.enemy.is_off_beat())
	assert_eq(rules.enemy.hit_beat, 5)
	var text: String = rules.act(0, _attack(Rune.Dir.DOWN, 2))
	assert_string_contains(text, "back onto the beat")
	assert_eq(rules.enemy.hit_beat, 6)
	rules.close_beat(5)
	assert_eq(_hero().hp, FightRules.HERO_HP)
	rules.close_beat(6)
	assert_eq(_hero().hp, FightRules.HERO_HP - 20)


## A player on an even-beat flow starts a brace, sees the hit is off the beat,
## skips one beat, and braces onto the odd hit beat instead. Combo survives.
func test_skipping_a_beat_resyncs_brace_with_off_beat_hit() -> void:
	var pattern: Array[EnemyMove] = [EnemyMove.new("Wrath", EnemyMove.Target.ALL_ROOMS, 5, 20, 3, true)]
	rules = FightRules.new(1, Enemy.new("Foe", 100, 1, pattern, 0))
	var player := PlayerRhythm.new(0.6, 0.15, 0.04)
	var feed := func(rune: Rune.Dir, beat: int) -> void:
		var r: PlayerRhythm.Result = player.submit(rune, 0.6 * beat)
		if r.action != null:
			rules.act(0, r.action)
	rules.close_beat(0)
	assert_eq(rules.enemy.hit_beat, 5)
	feed.call(Rune.Dir.RIGHT, 2)
	rules.close_beat(2)
	player.reader.on_beat(3)  # beat 3 passes empty: pending brace dropped
	player.reader.on_beat(4)
	feed.call(Rune.Dir.RIGHT, 4)
	feed.call(Rune.Dir.LEFT, 5)
	rules.close_beat(5)
	assert_eq(_hero().hp, FightRules.HERO_HP, "brace completed on the off-beat hit")
	assert_eq(player.combo.combo, 3)


func test_super_windup_log_calls_for_trip() -> void:
	var pattern: Array[EnemyMove] = [EnemyMove.new("Wrath", EnemyMove.Target.ALL_ROOMS, 5, 20, 3, true)]
	rules = FightRules.new(1, Enemy.new("Foe", 100, 1, pattern, 0))
	watch_signals(rules)
	rules.close_beat(0)
	assert_signal_emitted_with_parameters(rules, "logged", ["SUPER! Foe winds up Wrath (left, center, right), off the beat. Trip it!"])


## Plays the default enemy until `count` hits land, optionally Tripping each
## super once while it winds up. Returns each hit as "<move>:<beat parity>".
func _play(count: int, trip_supers: bool) -> Array[String]:
	rules = FightRules.new(1)
	_hero().hp = 100000
	_hero().max_hp = 100000
	_hero().room = 1
	var out: Array[String] = []
	var tripped: bool = false
	var beat: int = 0
	while out.size() < count and beat < 500:
		var e: Enemy = rules.enemy
		if trip_supers and e.is_winding() and e.current.is_super and not tripped:
			rules.act(0, _attack(Rune.Dir.DOWN, beat))
			tripped = true
		var hit: int = e.hit_beat
		var move: EnemyMove = e.current
		rules.close_beat(beat)
		if move != null and hit == beat:
			out.append("%s:%d" % [move.display_name, posmod(beat, Enemy.CADENCE)])
			tripped = false
		beat += 1
	return out


func test_untripped_super_shifts_the_enemy_off_beat() -> void:
	assert_eq(_play(10, false), [
		"Grave Claw:0", "Barrow Slam:0", "Death Howl:0", "Grave Claw:0", "Grave Wrath:1",
		"Grave Claw:1", "Barrow Slam:1", "Death Howl:1", "Grave Claw:1", "Grave Wrath:0",
	])


func test_tripping_supers_keeps_the_enemy_on_beat() -> void:
	assert_eq(_play(10, true), [
		"Grave Claw:0", "Barrow Slam:0", "Death Howl:0", "Grave Claw:0", "Grave Wrath:0",
		"Grave Claw:0", "Barrow Slam:0", "Death Howl:0", "Grave Claw:0", "Grave Wrath:0",
	])


func test_default_enemy_pattern() -> void:
	var e: Enemy = FightRules.default_enemy()
	assert_eq(e.pattern.size(), 5)
	var supers: Array = e.pattern.filter(func(m: EnemyMove) -> bool: return m.is_super)
	assert_eq(supers.size(), 1)
	assert_eq(supers[0].windup % 2, 1)
	assert_eq(e.next_start, FightRules.FIRST_ENEMY_BEAT)
	assert_eq(e.hp, FightRules.ENEMY_HP)
