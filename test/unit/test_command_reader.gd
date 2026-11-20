extends GutTest

const U := Rune.Dir.UP
const D := Rune.Dir.DOWN
const L := Rune.Dir.LEFT
const R := Rune.Dir.RIGHT

var reader: CommandReader


func before_each() -> void:
	reader = CommandReader.new()


func _cmd(first: Rune.Dir, second: Rune.Dir, beat: int = 0, perfect: bool = false) -> RuneAction:
	assert_null(reader.feed(first, beat, perfect), "first rune should only start a command")
	return reader.feed(second, beat + 1, perfect)


func test_first_rune_is_pending() -> void:
	assert_null(reader.feed(D, 4, false))
	assert_eq(reader.pending, D)


func test_movement_moves_in_second_direction() -> void:
	for dir: Rune.Dir in Rune.ALL:
		var a: RuneAction = _cmd(D, dir)
		assert_eq(a.kind, RuneAction.Kind.MOVE)
		assert_eq(a.dir, dir)
	assert_eq(reader.pending, CommandReader.NO_RUNE)


func test_attack_variants() -> void:
	assert_eq(_cmd(L, D).attack, RuneAction.Attack.TRIP)
	assert_eq(_cmd(L, L).attack, RuneAction.Attack.STANDARD)
	assert_eq(_cmd(L, U).attack, RuneAction.Attack.HEAVY)
	assert_eq(_cmd(L, R).attack, RuneAction.Attack.DEFENSIVE)
	assert_eq(_cmd(L, R).kind, RuneAction.Kind.ATTACK)


func test_defense_braces_in_direction() -> void:
	var a: RuneAction = _cmd(R, L)
	assert_eq(a.kind, RuneAction.Kind.BRACE)
	assert_eq(a.dir, L)


func test_prayer_blesses_next_action_once() -> void:
	var p: RuneAction = _cmd(U, L, 0)
	assert_eq(p.kind, RuneAction.Kind.PRAY)
	assert_true(reader.blessings[L])
	assert_false(_cmd(D, L, 2).empowered, "blessing is only for the blessed rune")
	assert_true(_cmd(L, L, 4).empowered)
	assert_false(_cmd(L, L, 6).empowered, "blessing is consumed")


func test_prayer_blesses_movement_and_defense() -> void:
	_cmd(U, D, 0)
	_cmd(U, R, 2)
	assert_true(_cmd(D, U, 4).empowered)
	assert_true(_cmd(R, U, 6).empowered)


func test_prayer_on_prayer_grants_glory() -> void:
	var a: RuneAction = _cmd(U, U, 0)
	assert_eq(a.glory, CommandReader.PRAYER_GLORY)
	_cmd(U, U, 2, true)
	assert_eq(reader.glory, CommandReader.PRAYER_GLORY + CommandReader.PERFECT_PRAYER_GLORY)
	assert_false(reader.blessings[U])


func test_perfect_needs_both_beats_perfect() -> void:
	reader.feed(D, 0, true)
	assert_false(reader.feed(L, 1, false).perfect)
	assert_true(_cmd(D, L, 2, true).perfect)


func test_skipped_beat_expires_pending_and_starts_new_command() -> void:
	reader.feed(L, 0, false)
	assert_null(reader.feed(D, 2, false), "late rune starts a new command")
	assert_eq(reader.pending, D)
	var a: RuneAction = reader.feed(R, 3, false)
	assert_eq(a.kind, RuneAction.Kind.MOVE)


func test_on_beat_expires_after_follow_up_beat_passes() -> void:
	reader.feed(L, 5, false)
	assert_false(reader.on_beat(6), "beat 6 is still the follow-up beat")
	assert_true(reader.on_beat(7))
	assert_eq(reader.pending, CommandReader.NO_RUNE)
	assert_false(reader.on_beat(8))


func test_action_records_completing_beat() -> void:
	assert_eq(_cmd(D, U, 10).beat, 11)


func test_options_for_each_first_rune() -> void:
	assert_eq(CommandReader.options_for(L), ["Heavy", "Trip", "Standard", "Defensive"])
	assert_eq(CommandReader.options_for(U)[Rune.Dir.UP], "Glory")
	assert_eq(CommandReader.options_for(D)[Rune.Dir.LEFT], "Move left")


func test_describe_mentions_blessing() -> void:
	_cmd(U, L, 0)
	assert_string_contains(_cmd(L, U, 2).describe(), "Heavy attack (blessed")


func test_reset_clears_state() -> void:
	_cmd(U, U, 0)
	_cmd(U, D, 2)
	reader.feed(L, 4, false)
	reader.reset()
	assert_eq(reader.pending, CommandReader.NO_RUNE)
	assert_eq(reader.glory, 0)
	assert_false(reader.blessings[D])


func test_skipped_follow_up_beat_clears_queue_when_it_closes() -> void:
	reader.feed(L, 5, false)
	assert_false(reader.on_beat_closed(5), "the first rune's own beat closing keeps it")
	assert_true(reader.on_beat_closed(6), "the follow-up beat closed empty")
	assert_eq(reader.pending, CommandReader.NO_RUNE)
	assert_false(reader.on_beat_closed(7))
