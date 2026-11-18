extends GutTest

var stage: StageRules
var ranger: RangerEnemy


func before_each() -> void:
	var map: StageMap = StageMap.build([StageChunk.from_rows(["....", "1...", "...."])])
	ranger = RangerEnemy.new(Vector2i(3, 0))
	stage = StageRules.new(map, 1, [ranger])


func test_moves_one_lane_toward_hero_when_not_in_line() -> void:
	assert_true(ranger.try_act(0, stage))
	assert_false(ranger.is_winding())
	assert_eq(ranger.cell, Vector2i(3, 1), "one lane down, same column")


func test_nocks_arrow_when_hero_is_in_line() -> void:
	ranger.cell = Vector2i(3, 1)
	ranger.try_act(0, stage)
	assert_true(ranger.is_winding())
	assert_eq(ranger.current.display_name, "Arrow")
	assert_eq(ranger.hit_beat, RangerEnemy.ARROW_WINDUP)
	assert_eq(ranger.targets, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)])
	assert_eq(ranger.current.from_dir, Rune.Dir.RIGHT)


func test_never_leaves_its_column() -> void:
	stage.heroes[0].cell = Vector2i(0, 2)
	for beat: int in [0, 2]:
		ranger.try_act(beat, stage)
	assert_eq(ranger.cell, Vector2i(3, 2))


func test_hero_to_its_right_is_not_in_line() -> void:
	ranger.cell = Vector2i(2, 1)
	stage.heroes[0].cell = Vector2i(3, 1)
	ranger.try_act(0, stage)
	assert_false(ranger.is_winding())
	assert_eq(ranger.cell, Vector2i(2, 1))
