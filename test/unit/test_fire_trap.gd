extends GutTest


func test_four_off_then_two_on() -> void:
	var fire := FireTrap.new([Vector2i(1, 0)])
	var on: Array[bool] = []
	for beat: int in 12:
		on.append(fire.is_on(beat))
	assert_eq(on, [false, false, false, false, true, true, false, false, false, false, true, true])


func test_offset_shifts_cycle() -> void:
	var fire := FireTrap.new([Vector2i(1, 0)], 2)
	assert_false(fire.is_on(5))
	assert_true(fire.is_on(6))
	assert_true(fire.is_on(1))


func test_beats_until_on() -> void:
	var fire := FireTrap.new([Vector2i(1, 0)])
	assert_eq(fire.beats_until_on(0), 4)
	assert_eq(fire.beats_until_on(3), 1)
	assert_eq(fire.beats_until_on(4), 0)
	assert_eq(fire.beats_until_on(6), 4)
