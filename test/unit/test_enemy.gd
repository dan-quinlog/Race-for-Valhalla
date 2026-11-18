extends GutTest

var enemy: Enemy
var heroes: Array[Hero] = []


func before_each() -> void:
	var pattern: Array[EnemyMove] = [
		EnemyMove.new("Claw", EnemyMove.Target.HERO_ROOM, 3, 10, 2),
		EnemyMove.new("Howl", EnemyMove.Target.ALL_ROOMS, 2, 5, 1),
	]
	enemy = Enemy.new("Foe", 50, 1, pattern, 2)
	heroes = [Hero.new(0, 60, 0)]


func test_waits_for_first_start() -> void:
	assert_false(enemy.try_start(1, 3, heroes))
	assert_true(enemy.try_start(2, 3, heroes))
	assert_eq(enemy.current.display_name, "Claw")
	assert_eq(enemy.hit_beat, 5)
	assert_eq(enemy.countdown(2), 3)


func test_hero_room_target_locks_in_at_windup() -> void:
	enemy.try_start(2, 3, heroes)
	heroes[0].room = 2
	assert_eq(enemy.targets, [0])


func test_targets_alternate_between_living_heroes() -> void:
	heroes.append(Hero.new(1, 60, 2))
	var pattern: Array[EnemyMove] = [EnemyMove.new("Claw", EnemyMove.Target.HERO_ROOM, 1, 10, 0)]
	enemy = Enemy.new("Foe", 50, 1, pattern)
	enemy.try_start(0, 3, heroes)
	assert_eq(enemy.targets, [0])
	enemy.finish(1)
	enemy.try_start(2, 3, heroes)
	assert_eq(enemy.targets, [2])


func test_rests_then_loops_pattern() -> void:
	enemy.try_start(2, 3, heroes)
	enemy.finish(5)
	assert_false(enemy.is_winding())
	assert_false(enemy.try_start(7, 3, heroes))
	assert_true(enemy.try_start(8, 3, heroes))
	assert_eq(enemy.current.display_name, "Howl")
	assert_eq(enemy.targets, [0, 1, 2])


func test_stagger_delays_hit_or_next_windup() -> void:
	enemy.stagger()
	assert_false(enemy.try_start(2, 3, heroes))
	enemy.try_start(3, 3, heroes)
	enemy.stagger()
	assert_eq(enemy.hit_beat, 7)


func test_dead_enemy_does_not_start() -> void:
	enemy.take_damage(999)
	assert_false(enemy.try_start(5, 3, heroes))
