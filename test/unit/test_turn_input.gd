extends GutTest

const P: float = 1.0
const W: float = 0.15

var input: TurnInput


func before_each() -> void:
	input = TurnInput.new(P, W, 0.04)


func test_rune_corners_sit_between_neighbouring_directions() -> void:
	assert_eq(RuneCorner.between(Rune.Dir.UP, Rune.Dir.LEFT), RuneCorner.Kind.PRAYER)
	assert_eq(RuneCorner.between(Rune.Dir.RIGHT, Rune.Dir.UP), RuneCorner.Kind.HEAVY)
	assert_eq(RuneCorner.between(Rune.Dir.DOWN, Rune.Dir.LEFT), RuneCorner.Kind.TRIP)
	assert_eq(RuneCorner.between(Rune.Dir.RIGHT, Rune.Dir.DOWN), RuneCorner.Kind.FLOURISH)
	assert_eq(RuneCorner.between(Rune.Dir.UP, Rune.Dir.DOWN), -1)
	assert_eq(RuneCorner.between(Rune.Dir.LEFT, Rune.Dir.LEFT), -1)


func test_a_direction_alone_resolves_at_the_close() -> void:
	assert_eq(input.press_dir(Rune.Dir.RIGHT, 1.0).grade, BeatJudge.Grade.PERFECT)
	var a: TurnAction = input.close_beat(1)
	assert_eq(a.kind, TurnAction.Kind.DIRECTION)
	assert_eq(a.dir, Rune.Dir.RIGHT)
	assert_eq(a.beat, 1)
	assert_true(a.perfect)


func test_two_neighbouring_directions_cast_the_corner_rune() -> void:
	input.press_dir(Rune.Dir.UP, 1.05)
	assert_null(input.press_dir(Rune.Dir.RIGHT, 1.12), "the second press isn't judged")
	var a: TurnAction = input.close_beat(1)
	assert_eq(a.kind, TurnAction.Kind.RUNE)
	assert_eq(a.rune, RuneCorner.Kind.HEAVY)
	assert_false(a.perfect, "timing comes from the first press")
	assert_eq(input.combo.misses, 0)


func test_opposite_directions_do_not_chord() -> void:
	input.press_dir(Rune.Dir.LEFT, 1.0)
	input.press_dir(Rune.Dir.RIGHT, 1.05)
	var a: TurnAction = input.close_beat(1)
	assert_eq(a.kind, TurnAction.Kind.DIRECTION)
	assert_eq(a.dir, Rune.Dir.LEFT)


func test_direct_rune_press() -> void:
	input.press_rune(RuneCorner.Kind.TRIP, 2.0)
	assert_null(input.press_dir(Rune.Dir.UP, 2.05), "the beat already took its input")
	assert_eq(input.close_beat(2).rune, RuneCorner.Kind.TRIP)


func test_skipped_beat_is_null() -> void:
	assert_null(input.close_beat(1))


func test_late_chord_key_after_the_dum_is_ignored() -> void:
	input.press_dir(Rune.Dir.DOWN, 1.0)
	input.close_beat(1)
	assert_null(input.press_dir(Rune.Dir.LEFT, 1.2))
	assert_eq(input.combo.misses, 0)
	assert_null(input.close_beat(2))


func test_mistimed_press_is_a_miss() -> void:
	assert_eq(input.press_dir(Rune.Dir.DOWN, 1.4).grade, BeatJudge.Grade.MISS)
	assert_null(input.close_beat(1))


func test_late_press_after_its_close_resolves_on_its_own() -> void:
	input.close_beat(1)
	input.press_dir(Rune.Dir.DOWN, 1.12)
	assert_true(input.is_late())
	var a: TurnAction = input.resolve_late()
	assert_eq(a.dir, Rune.Dir.DOWN)
	assert_eq(a.beat, 1)
