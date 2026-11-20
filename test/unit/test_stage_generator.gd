extends GutTest


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_every_pool_chunk_is_valid_and_sized() -> void:
	for chunk: StageChunk in StageGenerator.ENCOUNTERS:
		assert_eq(chunk.validate(), "")
		assert_true(chunk.encounter)
		assert_eq(chunk.width(), StageRules.VIEW_COLS, "an encounter fills the screen")
		assert_between(chunk.tier, 1, 3)
		assert_false("D" in "".join(chunk.rows), "only the exit chunk has a door")
	for chunk: StageChunk in StageGenerator.CORRIDORS:
		assert_eq(chunk.validate(), "")
		assert_false(chunk.encounter)


func test_stage_one_draws_only_tier_one() -> void:
	for chunk: StageChunk in StageGenerator.encounter_pool(1):
		assert_eq(chunk.tier, 1)
	for chunk: StageChunk in StageGenerator.encounter_pool(3):
		assert_gt(chunk.tier, 1)


func test_stage_layout_scrolls_then_locks_twice() -> void:
	for seed_value: int in 20:
		var chunks: Array[StageChunk] = StageGenerator.build(2, _rng(seed_value))
		assert_ne(chunks[1], chunks[3], "two different encounters")
		var map: StageMap = StageMap.build(chunks)
		assert_eq(map.encounters.size(), 2)
		assert_eq(map.encounters[0].end - StageRules.VIEW_COLS, 1)
		assert_eq(map.encounters[1].end - map.encounters[0].end, 2 * StageRules.VIEW_COLS, "a corridor and an encounter")
		assert_eq(map.door, Vector2i(map.width - 1, 1))


func test_same_seed_same_stage() -> void:
	assert_eq(StageGenerator.build(3, _rng(7)), StageGenerator.build(3, _rng(7)))
