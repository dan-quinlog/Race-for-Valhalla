extends GutTest

var clock: BeatClock


func before_each() -> void:
	clock = partial_double(BeatClock).new()
	stub(clock, "play_audio").to_do_nothing()
	add_child_autofree(clock)
	clock.bpm = 100.0
	clock.start()


func test_start_sets_period_from_bpm() -> void:
	assert_almost_eq(clock.period, 0.6, 0.0001)
	assert_true(clock.running)
	assert_eq(clock.time, 0.0)


func test_advance_follows_raw_position() -> void:
	assert_almost_eq(clock.advance(0.2, 0.0), 0.2, 0.0001)
	assert_almost_eq(clock.advance(0.4, 0.0), 0.4, 0.0001)


func test_advance_counts_loop_wraps() -> void:
	clock.advance(0.5, 0.0)
	assert_almost_eq(clock.advance(0.05, 0.0), clock.period + 0.05, 0.0001)
	clock.advance(0.55, 0.0)
	assert_almost_eq(clock.advance(0.01, 0.0), clock.period * 2 + 0.01, 0.0001)


func test_advance_applies_compensation() -> void:
	assert_almost_eq(clock.advance(0.3, -0.05), 0.25, 0.0001)


func test_time_never_goes_backwards() -> void:
	clock.advance(0.3, 0.0)
	assert_almost_eq(clock.advance(0.28, 0.0), 0.3, 0.0001)


func test_emits_each_beat_once() -> void:
	watch_signals(clock)
	clock.advance(0.1, 0.0)
	clock.emit_due_beats()
	assert_signal_emit_count(clock, "beat", 1)
	clock.advance(0.5, 0.0)
	clock.advance(0.05, 0.0)
	clock.emit_due_beats()
	clock.emit_due_beats()
	assert_signal_emit_count(clock, "beat", 2)
	assert_signal_emitted_with_parameters(clock, "beat", [1])


func test_beat_closes_at_the_dum() -> void:
	watch_signals(clock)
	clock.dum_delay = 0.15
	clock.advance(0.1, 0.0)
	clock.emit_due_beats()
	assert_signal_emit_count(clock, "beat_closed", 0)
	clock.advance(0.16, 0.0)
	clock.emit_due_beats()
	assert_signal_emit_count(clock, "beat_closed", 1)
	assert_signal_emitted_with_parameters(clock, "beat_closed", [0])
	clock.advance(0.5, 0.0)
	clock.advance(0.18, 0.0)  # wraps: 0.6 + 0.18, past beat 1's dum at 0.75
	clock.emit_due_beats()
	assert_signal_emit_count(clock, "beat_closed", 2)
	assert_signal_emitted_with_parameters(clock, "beat_closed", [1])


func test_input_time_subtracts_latency() -> void:
	clock.advance(0.3, 0.0)
	clock.input_latency = 0.02
	assert_almost_eq(clock.input_time(), 0.28, 0.0001)


func test_stop_halts_clock() -> void:
	clock.stop()
	assert_false(clock.running)
