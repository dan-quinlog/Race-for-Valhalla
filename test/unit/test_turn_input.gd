extends GutTest

const P: float = 1.0
const W: float = 0.15

var input: TurnInput


func before_each() -> void:
	input = TurnInput.new(P, W, 0.04)


func _tap(r: Rune.Dir, beat: int, offset: float = 0.0) -> BeatJudge.Judgment:
	var j: BeatJudge.Judgment = input.press(r, beat * P + offset)
	input.release(beat * P + offset + 0.05)
	return j


func test_tap_uses_the_runes_own_direction() -> void:
	_tap(Rune.Dir.LEFT, 1)
	var a: RuneAction = input.close_beat(1)
	assert_eq(a.kind, RuneAction.Kind.ATTACK)
	assert_eq(a.attack, RuneAction.Attack.STANDARD)
	_tap(Rune.Dir.DOWN, 2)
	a = input.close_beat(2)
	assert_eq(a.kind, RuneAction.Kind.MOVE)
	assert_eq(a.dir, Rune.Dir.DOWN)
	_tap(Rune.Dir.RIGHT, 3)
	assert_eq(input.close_beat(3).kind, RuneAction.Kind.BRACE)
	_tap(Rune.Dir.UP, 4)
	assert_eq(input.close_beat(4).glory, TurnInput.PERFECT_PRAYER_GLORY)


func test_direction_is_where_it_points_when_the_beat_closes() -> void:
	input.press(Rune.Dir.DOWN, 1.0)
	input.point(Rune.Dir.LEFT)
	input.point(Rune.Dir.RIGHT)
	var a: RuneAction = input.close_beat(1)
	assert_eq(a.kind, RuneAction.Kind.MOVE)
	assert_eq(a.dir, Rune.Dir.RIGHT)


func test_pointing_after_the_close_does_nothing() -> void:
	input.press(Rune.Dir.DOWN, 1.0)
	input.close_beat(1)
	input.point(Rune.Dir.LEFT)
	assert_null(input.close_beat(2))


func test_one_action_per_beat_and_perfect_from_the_press() -> void:
	input.press(Rune.Dir.LEFT, 1.1)
	input.point(Rune.Dir.DOWN)
	var a: RuneAction = input.close_beat(1)
	assert_eq(a.attack, RuneAction.Attack.TRIP)
	assert_false(a.perfect)
	assert_eq(input.press(Rune.Dir.LEFT, 2.0).grade, BeatJudge.Grade.PERFECT)
	assert_eq(input.press(Rune.Dir.LEFT, 2.05).grade, BeatJudge.Grade.MISS)


func test_no_press_no_action() -> void:
	assert_null(input.close_beat(1))


func test_late_press_after_its_close_resolves_on_its_own() -> void:
	input.close_beat(1)
	input.press(Rune.Dir.DOWN, 1.12)
	assert_true(input.is_late())
	var a: RuneAction = input.resolve_late()
	assert_eq(a.kind, RuneAction.Kind.MOVE)
	assert_eq(a.beat, 1)


func test_prayer_blesses_the_rune_it_points_at() -> void:
	input.press(Rune.Dir.UP, 1.0)
	input.point(Rune.Dir.LEFT)
	input.close_beat(1)
	assert_true(input.blessings[Rune.Dir.LEFT])
	_tap(Rune.Dir.LEFT, 2)
	assert_true(input.close_beat(2).empowered)
	assert_false(input.blessings[Rune.Dir.LEFT])


func _start_heavy(beat: int, offset: float = 0.0) -> RuneAction:
	input.press(Rune.Dir.LEFT, beat * P + offset)
	input.point(Rune.Dir.UP)
	return input.close_beat(beat)


func test_hold_heavy_charges_while_held_and_fires_after_release() -> void:
	var a: RuneAction = _start_heavy(1)
	assert_eq(a.kind, RuneAction.Kind.CHARGE)
	assert_true(input.charging)
	a = input.close_beat(2)
	assert_eq(a.kind, RuneAction.Kind.CHARGE)
	assert_eq(a.charge_beats, 1)
	input.release(2.5)
	a = input.close_beat(3)
	assert_eq(a.kind, RuneAction.Kind.ATTACK)
	assert_eq(a.attack, RuneAction.Attack.HEAVY)
	assert_eq(a.charge_beats, 2)
	assert_true(a.perfect, "perfect comes from the press that started it")
	assert_false(input.charging)


func test_hold_release_inside_a_window_fires_that_beat() -> void:
	_start_heavy(1)
	input.release(2.1)
	assert_eq(input.close_beat(2).attack, RuneAction.Attack.HEAVY)


func test_hold_quick_tap_heavy_fires_on_the_next_beat() -> void:
	input.press(Rune.Dir.LEFT, 1.0)
	input.point(Rune.Dir.UP)
	input.release(1.08)
	assert_eq(input.close_beat(1).kind, RuneAction.Kind.CHARGE)
	var a: RuneAction = input.close_beat(2)
	assert_eq(a.attack, RuneAction.Attack.HEAVY)
	assert_eq(a.charge_beats, 1)


func test_hold_new_press_fires_the_charge_and_is_used_up() -> void:
	_start_heavy(1)
	input.press(Rune.Dir.DOWN, 2.0)
	assert_true(input.press_fires_charge())
	var a: RuneAction = input.close_beat(2)
	assert_eq(a.attack, RuneAction.Attack.HEAVY)
	assert_null(input.close_beat(3), "the move press was used up")


func test_repeat_heavy_keeps_charging_and_anything_else_fires() -> void:
	input.charge_mode = TurnInput.ChargeMode.REPEAT
	_start_heavy(1)
	input.release(1.05)
	assert_eq(_start_heavy(2).kind, RuneAction.Kind.CHARGE)
	_tap(Rune.Dir.DOWN, 3)
	var a: RuneAction = input.close_beat(3)
	assert_eq(a.attack, RuneAction.Attack.HEAVY)
	assert_eq(a.charge_beats, 2)
	assert_null(input.close_beat(4), "the move that fired it was used up")


func test_repeat_skipped_beat_fires() -> void:
	input.charge_mode = TurnInput.ChargeMode.REPEAT
	_start_heavy(1)
	assert_eq(input.close_beat(2).attack, RuneAction.Attack.HEAVY)


func test_charged_heavy_keeps_its_blessing() -> void:
	input.blessings[Rune.Dir.LEFT] = true
	_start_heavy(1)
	assert_false(input.blessings[Rune.Dir.LEFT])
	input.release(1.5)
	assert_true(input.close_beat(2).empowered)
