extends GutTest

var boss: BossEnemy
var rules: StageRules


func before_each() -> void:
	var arena := StageChunk.from_rows(["..J.", "1...", "2..."], true)
	rules = StageRules.new(StageMap.build([arena]), 1)
	boss = rules.enemies[0]


func _hero() -> Hero:
	return rules.heroes[0]


func _attack(dir: Rune.Dir, beat: int, perfect: bool = false) -> String:
	var a := RuneAction.new()
	a.kind = RuneAction.Kind.ATTACK
	a.dir = dir
	a.attack = RuneAction.ATTACK_BY_DIR[dir]
	a.beat = beat
	a.perfect = perfect
	return rules.act(0, a)


func test_jotunn_spawns_from_chunk_and_covers_two_by_three() -> void:
	assert_true(boss is BossEnemy)
	assert_eq(boss.footprint.size(), 6)
	for col: int in [2, 3]:
		for lane: int in 3:
			assert_true(boss.occupies(Vector2i(col, lane)))
			assert_eq(rules.enemy_at(Vector2i(col, lane)), boss)
	assert_false(boss.occupies(Vector2i(1, 0)))


func test_parts_sit_in_their_zones() -> void:
	assert_eq(boss.part_at(Vector2i(2, 0)).display_name, "Club Arm")
	assert_eq(boss.part_at(Vector2i(3, 0)).display_name, "Head")
	assert_eq(boss.part_at(Vector2i(3, 2)).display_name, "Legs")
	assert_null(boss.part_at(Vector2i(2, 1)), "body")
	assert_true(boss.is_unarmored(Vector2i(2, 1)))
	assert_false(boss.is_unarmored(Vector2i(2, 0)))
	assert_false(boss.is_unarmored(Vector2i(0, 0)), "not the boss")


func test_bare_zones_take_bonus_damage() -> void:
	assert_eq(boss.take_hit(Vector2i(2, 1), 10), 15)
	assert_eq(boss.take_hit(Vector2i(2, 1), 10, false), 10, "bonus can be skipped")
	assert_eq(boss.hp, 300 - 25)


func test_part_hits_wear_part_and_pool() -> void:
	assert_eq(boss.take_hit(Vector2i(3, 0), 30), 30)
	assert_eq(boss.hp, 270)
	assert_eq(boss.part_at(Vector2i(3, 0)).damage, 30)
	assert_true(boss.pop_broken().is_empty())
	boss.take_hit(Vector2i(3, 0), 10)
	var broken: Array[BossPart] = boss.pop_broken()
	assert_eq(broken.size(), 1)
	assert_eq(broken[0].display_name, "Head")
	assert_true(boss.is_unarmored(Vector2i(3, 0)), "a wound is bare")
	assert_eq(boss.take_hit(Vector2i(3, 0), 10), 15)
	assert_eq(boss.broken_parts(), 1)


func test_attack_cycle_turns_enraged_after_breaks() -> void:
	var names: Array[String] = []
	for i: int in 3:
		names.append(boss.decide(0, rules).display_name)
	assert_eq(names, ["Club Slam", "Frost Breath", "Stomp"])
	boss.take_hit(Vector2i(3, 0), 40)
	names.clear()
	for i: int in 3:
		names.append(boss.decide(0, rules).display_name)
	assert_eq(names, ["Club Slam", "Jötunn's Roar", "Stomp"])


func test_roar_is_an_off_beat_super() -> void:
	var roar: EnemyMove = boss.part_at(Vector2i(3, 0)).enraged
	assert_true(roar.is_super)
	assert_eq(roar.windup % 2, 1)


func test_frost_breath_sweeps_top_lane_from_the_right() -> void:
	var breath: EnemyMove = boss.part_at(Vector2i(3, 0)).attack
	assert_eq(breath.zones, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	assert_eq(breath.from_dir, Rune.Dir.RIGHT)


func test_wounds_bleed_each_beat() -> void:
	boss.take_hit(Vector2i(3, 0), 40)
	boss.take_hit(Vector2i(3, 2), 40)
	var hp: int = boss.hp
	rules.close_beat(0)
	assert_eq(boss.hp, hp - 2 * BossEnemy.BLEED_PER_WOUND)


# --- Through the stage rules --------------------------------------------------

func test_hero_attack_on_body_gets_bonus() -> void:
	_hero().cell = Vector2i(2, 1)
	_attack(Rune.Dir.LEFT, 1)
	assert_eq(boss.hp, 300 - 15)


func test_breaking_a_part_earns_glory() -> void:
	_hero().cell = Vector2i(2, 0)
	boss.part_at(Vector2i(2, 0)).damage = 35
	watch_signals(rules)
	_attack(Rune.Dir.LEFT, 1)
	assert_true(boss.part_at(Vector2i(2, 0)).broken)
	assert_eq(_hero().glory, StageRules.PART_GLORY)


func test_killing_blow_earns_boss_glory_and_wins_doorless_arena() -> void:
	_hero().cell = Vector2i(2, 1)
	boss.hp = 5
	_attack(Rune.Dir.LEFT, 1)
	assert_eq(_hero().glory, boss.glory_value)
	assert_true(rules.over)
	assert_true(rules.won)


func test_bleeding_out_wins_without_kill_glory() -> void:
	boss.take_hit(Vector2i(3, 0), 40)
	boss.pop_broken()
	boss.hp = 1
	rules.close_beat(0)
	assert_false(boss.is_alive())
	assert_true(rules.won)
	assert_eq(_hero().glory, 0)


func test_prayer_glory_counts_toward_hero_glory() -> void:
	var a := RuneAction.new()
	a.kind = RuneAction.Kind.PRAY
	a.dir = Rune.Dir.UP
	a.glory = 2
	a.beat = 1
	rules.act(0, a)
	assert_eq(_hero().glory, 2)
