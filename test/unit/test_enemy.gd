extends GutTest
## Rhythm and targeting shared by every enemy, exercised through PatternEnemy.

var stage: StageRules


## A 4x3 open stage with player 1 at the left of the middle lane.
func _stage(enemies: Array[Enemy], players: int = 1) -> StageRules:
	var map: StageMap = StageMap.build([StageChunk.from_rows(["....", "1...", "2..."])])
	stage = StageRules.new(map, players, enemies)
	return stage


func _pattern(moves: Array[EnemyMove], first_start: int = 0, cell := Vector2i(3, 1)) -> PatternEnemy:
	return PatternEnemy.new("Foe", 50, cell, moves, first_start)


func _claw(windup: int = 4) -> EnemyMove:
	return EnemyMove.new("Claw", EnemyMove.Target.HERO_ZONE, windup, 10, 2)


func _super() -> EnemyMove:
	return EnemyMove.new("Super", EnemyMove.Target.ALL_ZONES, 5, 20, 1, true)


func _own(windup: int = 4) -> EnemyMove:
	return EnemyMove.new("Own", EnemyMove.Target.OWN_ZONE, windup, 10, 1)


func test_waits_for_first_start() -> void:
	var e := _pattern([_claw()], 2)
	_stage([e])
	assert_false(e.try_act(1, stage))
	assert_true(e.try_act(2, stage))
	assert_eq(e.current.display_name, "Claw")
	assert_eq(e.hit_beat, 6)
	assert_eq(e.countdown(2), 4)


func test_hero_zone_target_locks_in_at_windup() -> void:
	var e := _pattern([_claw()])
	_stage([e])
	e.try_act(0, stage)
	stage.heroes[0].cell = Vector2i(2, 2)
	assert_eq(e.targets, [Vector2i(0, 1)])


func test_targets_alternate_between_living_heroes() -> void:
	var e := _pattern([_claw(2)])
	_stage([e], 2)
	e.try_act(0, stage)
	assert_eq(e.targets, [Vector2i(0, 1)])
	e.finish(2)
	e.try_act(6, stage)
	assert_eq(e.targets, [Vector2i(0, 2)])


func test_all_zones_covers_the_screen() -> void:
	var e := _pattern([_super()])
	_stage([e])
	e.try_act(0, stage)
	assert_eq(e.targets.size(), 12)


func test_lane_left_runs_from_screen_edge_to_enemy() -> void:
	var e := _pattern([RangerEnemy.arrow()], 0, Vector2i(3, 0))
	_stage([e])
	e.try_act(0, stage)
	assert_eq(e.targets, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])


func test_rests_then_loops_pattern() -> void:
	var e := _pattern([_claw(), _own(2)], 2)
	_stage([e])
	e.try_act(2, stage)
	e.finish(6)
	assert_false(e.is_winding())
	assert_false(e.try_act(8, stage))
	assert_true(e.try_act(10, stage))
	assert_eq(e.current.display_name, "Own")


func test_repositioning_step_waits_a_cadence() -> void:
	var e := BruteEnemy.new(Vector2i(3, 1))
	_stage([e])
	assert_true(e.try_act(0, stage))
	assert_false(e.is_winding(), "the first brute step is a move")
	assert_false(e.try_act(1, stage))
	assert_true(e.try_act(2, stage))
	assert_true(e.is_winding())


func test_moves_start_only_in_step_with_rhythm() -> void:
	var e := _pattern([_claw()], 2)
	_stage([e])
	e.next_start = 3
	assert_false(e.try_act(3, stage))
	assert_true(e.try_act(4, stage))


func test_stagger_while_resting_waits_for_next_step() -> void:
	var e := _pattern([_claw()], 2)
	_stage([e])
	e.stagger()
	assert_false(e.try_act(2, stage))
	assert_false(e.try_act(3, stage))
	assert_true(e.try_act(4, stage))
	assert_false(e.is_off_beat())


func test_stagger_delays_pending_hit() -> void:
	var e := _pattern([_claw()], 2)
	_stage([e])
	e.try_act(2, stage)
	e.stagger()
	assert_eq(e.hit_beat, 7)


func test_odd_windup_lands_off_beat_until_staggered() -> void:
	var e := _pattern([_super()])
	_stage([e])
	e.try_act(0, stage)
	assert_eq(e.hit_beat, 5)
	assert_true(e.is_off_beat())
	e.stagger()
	assert_eq(e.hit_beat, 6)
	assert_false(e.is_off_beat())


func test_untripped_super_leaves_rhythm_off_beat() -> void:
	var e := _pattern([_super(), _own()])
	_stage([e])
	e.try_act(0, stage)
	e.finish(5)
	assert_true(e.is_rhythm_off_beat())
	assert_false(e.try_act(8, stage), "even beats are out of step now")
	assert_true(e.try_act(7, stage))
	assert_eq(e.hit_beat, 11)
	assert_true(e.is_off_beat(), "regular moves stay off the beat")


func test_tripped_super_keeps_rhythm_on_beat() -> void:
	var e := _pattern([_super(), _own()])
	_stage([e])
	e.try_act(0, stage)
	e.stagger()
	e.finish(6)
	assert_false(e.is_rhythm_off_beat())
	assert_true(e.try_act(8, stage))
	assert_false(e.is_off_beat())


func test_trip_on_off_beat_move_brings_rhythm_back() -> void:
	var e := _pattern([_own()], 1)
	_stage([e])
	assert_true(e.is_rhythm_off_beat())
	e.try_act(1, stage)
	assert_true(e.is_off_beat())
	e.stagger()
	e.finish(6)
	assert_false(e.is_rhythm_off_beat())


func test_dead_enemy_does_not_act() -> void:
	var e := _pattern([_claw()])
	_stage([e])
	e.take_damage(999)
	assert_false(e.try_act(0, stage))


func test_step_toward_prefers_column_then_lane() -> void:
	var e := _pattern([_claw()], 0, Vector2i(3, 0))
	_stage([e])
	assert_true(e.step_toward(Vector2i(0, 2), stage))
	assert_eq(e.cell, Vector2i(2, 0))
	assert_true(e.step_toward(Vector2i(0, 2), stage, true))
	assert_eq(e.cell, Vector2i(2, 1))


func test_step_toward_avoids_walls_other_enemies_and_off_screen() -> void:
	var map: StageMap = StageMap.build([StageChunk.from_rows(["1.#..", ".....", "....."])])
	var e := _pattern([_claw()], 0, Vector2i(3, 0))
	var other := _pattern([_claw()], 0, Vector2i(2, 1))
	stage = StageRules.new(map, 1, [e, other])
	assert_false(e.step_toward(Vector2i(2, 0), stage), "wall")
	e.cell = Vector2i(3, 1)
	assert_false(e.step_toward(Vector2i(2, 1), stage), "zone already holds an enemy")
	e.cell = Vector2i(3, 2)
	assert_false(e.step_toward(Vector2i(4, 2), stage), "column 4 is off screen")


func test_draugr_keeps_its_off_beat_super() -> void:
	var d: PatternEnemy = PatternEnemy.draugr(Vector2i(1, 1))
	assert_eq(d.pattern.size(), 5)
	var supers: Array = d.pattern.filter(func(m: EnemyMove) -> bool: return m.is_super)
	assert_eq(supers.size(), 1)
	assert_eq(supers[0].windup % 2, 1)
