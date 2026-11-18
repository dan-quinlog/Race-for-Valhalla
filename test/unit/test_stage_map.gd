extends GutTest


func _chunk(rows: Array[String], encounter: bool = false) -> StageChunk:
	return StageChunk.from_rows(rows, encounter)


func test_validate_catches_bad_chunks() -> void:
	assert_eq(_chunk([".", ".", "."]).validate(), "")
	assert_string_contains(_chunk([".", "."]).validate(), "3 lanes")
	assert_string_contains(_chunk(["..", ".", ".."]).validate(), "lane 1")
	assert_string_contains(_chunk([".", "x", "."]).validate(), "unknown zone")


func test_build_stitches_chunks_left_to_right() -> void:
	var map: StageMap = StageMap.build([
		_chunk([".", "1", "2"]),
		_chunk(["..R", ".B.", "#.."], true),
		_chunk(["F.", "F.", "FD"], true),
	])
	assert_eq(map.width, 6)
	assert_eq(map.hero_starts, [Vector2i(0, 1), Vector2i(0, 2)])
	assert_true(map.walls.has(Vector2i(1, 2)))
	assert_false(map.is_open(Vector2i(1, 2)))
	assert_eq(map.door, Vector2i(5, 2))
	assert_eq(map.fire_columns[4], [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)])


func test_build_records_encounters_and_spawns() -> void:
	var map: StageMap = StageMap.build([
		_chunk(["1", ".", "."]),
		_chunk(["..R", ".B.", "..."], true),
		_chunk(["R", ".", "."]),
	])
	assert_eq(map.encounters.size(), 1)
	assert_eq(map.encounters[0].start, 1)
	assert_eq(map.encounters[0].end, 4)
	assert_eq(map.spawns.size(), 3)
	assert_eq(map.spawns[0].kind, "R")
	assert_eq(map.spawns[0].cell, Vector2i(3, 0))
	assert_eq(map.spawns[0].encounter, 0)
	assert_eq(map.spawns[2].encounter, -1, "spawns outside encounter chunks")


func test_player_two_defaults_next_to_player_one() -> void:
	var map: StageMap = StageMap.build([_chunk([".", ".", "1"])])
	assert_eq(map.hero_starts[1], Vector2i(0, 1))


func test_bounds() -> void:
	var map: StageMap = StageMap.build([_chunk(["1.", "..", ".."])])
	assert_true(map.is_open(Vector2i(1, 2)))
	assert_false(map.in_bounds(Vector2i(2, 0)))
	assert_false(map.in_bounds(Vector2i(0, 3)))
	assert_false(map.in_bounds(Vector2i(-1, 0)))
