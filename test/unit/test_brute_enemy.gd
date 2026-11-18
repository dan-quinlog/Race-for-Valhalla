extends GutTest

var stage: StageRules
var brute: BruteEnemy


func before_each() -> void:
	var map: StageMap = StageMap.build([StageChunk.from_rows(["....", "1...", "...."])])
	brute = BruteEnemy.new(Vector2i(3, 0))
	stage = StageRules.new(map, 1, [brute])


func test_alternates_move_then_smash() -> void:
	brute.try_act(0, stage)
	assert_eq(brute.cell, Vector2i(2, 0), "moves a column toward the hero first")
	assert_false(brute.is_winding())
	brute.try_act(2, stage)
	assert_true(brute.is_winding())
	assert_eq(brute.current.display_name, "Smash")
	assert_eq(brute.targets, [Vector2i(2, 0)])
	brute.finish(brute.hit_beat)
	brute.try_act(6, stage)
	assert_eq(brute.cell, Vector2i(1, 0))
	assert_false(brute.is_winding())


func test_switches_lanes_once_in_the_heros_column() -> void:
	brute.cell = Vector2i(0, 0)
	brute.try_act(0, stage)
	assert_eq(brute.cell, Vector2i(0, 1))


func test_stays_put_on_the_hero_and_still_alternates() -> void:
	brute.cell = Vector2i(0, 1)
	brute.try_act(0, stage)
	assert_eq(brute.cell, Vector2i(0, 1))
	brute.try_act(2, stage)
	assert_true(brute.is_winding())


func test_blocked_by_another_enemy() -> void:
	var map: StageMap = StageMap.build([StageChunk.from_rows(["1...", "....", "...."])])
	var other := BruteEnemy.new(Vector2i(2, 0))
	brute = BruteEnemy.new(Vector2i(3, 0))
	stage = StageRules.new(map, 1, [brute, other])
	brute.try_act(0, stage)
	assert_eq(brute.cell, Vector2i(3, 0), "column and lane steps both blocked or pointless")
