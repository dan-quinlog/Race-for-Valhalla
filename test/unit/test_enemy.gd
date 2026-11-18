extends GutTest

var enemy: Enemy
var heroes: Array[Hero] = []


func before_each() -> void:
	var pattern: Array[EnemyMove] = [
		EnemyMove.new("Claw", EnemyMove.Target.HERO_ROOM, 4, 10, 2),
		EnemyMove.new("Howl", EnemyMove.Target.ALL_ROOMS, 2, 5, 1),
	]
	enemy = Enemy.new("Foe", 50, 1, pattern, 2)
	heroes = [Hero.new(0, 60, 0)]


func _super_then_claw() -> Array[EnemyMove]:
	return [
		EnemyMove.new("Super", EnemyMove.Target.ALL_ROOMS, 5, 20, 1, true),
		EnemyMove.new("Claw", EnemyMove.Target.OWN_ROOM, 4, 10, 1),
	]


func test_waits_for_first_start() -> void:
	assert_false(enemy.try_start(1, 3, heroes))
	assert_true(enemy.try_start(2, 3, heroes))
	assert_eq(enemy.current.display_name, "Claw")
	assert_eq(enemy.hit_beat, 6)
	assert_eq(enemy.countdown(2), 4)


func test_hero_room_target_locks_in_at_windup() -> void:
	enemy.try_start(2, 3, heroes)
	heroes[0].room = 2
	assert_eq(enemy.targets, [0])


func test_targets_alternate_between_living_heroes() -> void:
	heroes.append(Hero.new(1, 60, 2))
	var pattern: Array[EnemyMove] = [EnemyMove.new("Claw", EnemyMove.Target.HERO_ROOM, 2, 10, 0)]
	enemy = Enemy.new("Foe", 50, 1, pattern)
	enemy.try_start(0, 3, heroes)
	assert_eq(enemy.targets, [0])
	enemy.finish(2)
	enemy.try_start(4, 3, heroes)
	assert_eq(enemy.targets, [2])


func test_rests_then_loops_pattern() -> void:
	enemy.try_start(2, 3, heroes)
	enemy.finish(6)
	assert_false(enemy.is_winding())
	assert_false(enemy.try_start(8, 3, heroes))
	assert_true(enemy.try_start(10, 3, heroes))
	assert_eq(enemy.current.display_name, "Howl")
	assert_eq(enemy.targets, [0, 1, 2])


func test_moves_start_only_in_step_with_rhythm() -> void:
	enemy.next_start = 3
	assert_false(enemy.try_start(3, 3, heroes))
	assert_true(enemy.try_start(4, 3, heroes))


func test_stagger_while_resting_waits_for_next_step() -> void:
	enemy.stagger()
	assert_false(enemy.try_start(2, 3, heroes))
	assert_false(enemy.try_start(3, 3, heroes))
	assert_true(enemy.try_start(4, 3, heroes))
	assert_false(enemy.is_off_beat())


func test_stagger_delays_pending_hit() -> void:
	enemy.try_start(2, 3, heroes)
	enemy.stagger()
	assert_eq(enemy.hit_beat, 7)


func test_odd_windup_lands_off_beat_until_staggered() -> void:
	enemy = Enemy.new("Foe", 50, 1, _super_then_claw())
	enemy.try_start(0, 3, heroes)
	assert_true(enemy.current.is_super)
	assert_eq(enemy.hit_beat, 5)
	assert_true(enemy.is_off_beat())
	enemy.stagger()
	assert_eq(enemy.hit_beat, 6)
	assert_false(enemy.is_off_beat())


func test_untripped_super_leaves_rhythm_off_beat() -> void:
	enemy = Enemy.new("Foe", 50, 1, _super_then_claw())
	enemy.try_start(0, 3, heroes)
	enemy.finish(5)
	assert_true(enemy.is_rhythm_off_beat())
	assert_false(enemy.try_start(8, 3, heroes), "even beats are out of step now")
	assert_true(enemy.try_start(7, 3, heroes))
	assert_eq(enemy.hit_beat, 11)
	assert_true(enemy.is_off_beat(), "regular moves stay off the beat")


func test_tripped_super_keeps_rhythm_on_beat() -> void:
	enemy = Enemy.new("Foe", 50, 1, _super_then_claw())
	enemy.try_start(0, 3, heroes)
	enemy.stagger()
	enemy.finish(6)
	assert_false(enemy.is_rhythm_off_beat())
	assert_true(enemy.try_start(8, 3, heroes))
	assert_false(enemy.is_off_beat())


func test_trip_on_off_beat_move_brings_rhythm_back() -> void:
	var pattern: Array[EnemyMove] = [EnemyMove.new("Claw", EnemyMove.Target.OWN_ROOM, 4, 10, 1)]
	enemy = Enemy.new("Foe", 50, 1, pattern, 1)
	assert_true(enemy.is_rhythm_off_beat())
	enemy.try_start(1, 3, heroes)
	assert_true(enemy.is_off_beat())
	enemy.stagger()
	enemy.finish(6)
	assert_false(enemy.is_rhythm_off_beat())


func test_even_windup_is_on_beat() -> void:
	var pattern: Array[EnemyMove] = [EnemyMove.new("Claw", EnemyMove.Target.OWN_ROOM, 4, 10, 1)]
	enemy = Enemy.new("Foe", 50, 1, pattern)
	enemy.try_start(0, 3, heroes)
	assert_false(enemy.is_off_beat())


func test_dead_enemy_does_not_start() -> void:
	enemy.take_damage(999)
	assert_false(enemy.try_start(5, 3, heroes))
