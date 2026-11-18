extends GutTest

const PERIOD: float = 0.6

var player: PlayerRhythm


func before_each() -> void:
	player = PlayerRhythm.new(PERIOD, 0.15, 0.04)


func test_two_on_beat_runes_complete_an_action() -> void:
	var first: PlayerRhythm.Result = player.submit(Rune.Dir.DOWN, PERIOD * 2)
	assert_true(first.started_command)
	assert_null(first.action)
	var second: PlayerRhythm.Result = player.submit(Rune.Dir.LEFT, PERIOD * 3)
	assert_eq(second.action.kind, RuneAction.Kind.MOVE)
	assert_true(second.action.perfect)
	assert_eq(player.combo.combo, 2)


func test_miss_breaks_combo_but_keeps_pending_command() -> void:
	player.submit(Rune.Dir.LEFT, PERIOD * 2)
	var miss: PlayerRhythm.Result = player.submit(Rune.Dir.UP, PERIOD * 2.5)
	assert_eq(miss.judgment.grade, BeatJudge.Grade.MISS)
	assert_false(miss.started_command)
	assert_eq(player.combo.combo, 0)
	var done: PlayerRhythm.Result = player.submit(Rune.Dir.UP, PERIOD * 3)
	assert_eq(done.action.attack, RuneAction.Attack.HEAVY)


func test_mashing_still_executes_commands() -> void:
	player.submit(Rune.Dir.RIGHT, PERIOD * 2)
	player.submit(Rune.Dir.RIGHT, PERIOD * 2 + 0.05)  # duplicate on same beat: miss
	var done: PlayerRhythm.Result = player.submit(Rune.Dir.DOWN, PERIOD * 3 + 0.1)
	assert_eq(done.action.kind, RuneAction.Kind.BRACE)
	assert_false(done.action.perfect)


func test_skipping_a_beat_clears_queue_but_keeps_combo() -> void:
	# Start a brace, then sit out one beat to shift the command a beat later.
	assert_true(player.submit(Rune.Dir.RIGHT, PERIOD * 4).started_command)
	assert_true(player.reader.on_beat(6), "the empty beat 5 drops the pending rune")
	var restart: PlayerRhythm.Result = player.submit(Rune.Dir.RIGHT, PERIOD * 6)
	assert_true(restart.started_command, "a fresh command, not the old one's follow-up")
	var done: PlayerRhythm.Result = player.submit(Rune.Dir.DOWN, PERIOD * 7)
	assert_eq(done.action.kind, RuneAction.Kind.BRACE)
	assert_eq(done.action.beat, 7)
	assert_eq(player.combo.combo, 3)
	assert_eq(player.combo.misses, 0)


func test_configure_resets_state() -> void:
	player.submit(Rune.Dir.UP, PERIOD * 2)
	player.configure(0.5, 0.12, 0.03)
	assert_eq(player.reader.pending, CommandReader.NO_RUNE)
	assert_eq(player.combo.combo, 0)
	assert_almost_eq(player.judge.period, 0.5, 0.0001)
