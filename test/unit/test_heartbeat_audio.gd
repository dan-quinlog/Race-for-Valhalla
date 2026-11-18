extends GutTest


func _sample(wav: AudioStreamWAV, frame: int) -> int:
	return wav.data.decode_s16(frame * 2)


func _peak(wav: AudioStreamWAV, from_sec: float, to_sec: float) -> int:
	var peak: int = 0
	var rate: int = HeartbeatAudio.MIX_RATE
	for i: int in range(roundi(from_sec * rate), roundi(to_sec * rate)):
		peak = maxi(peak, absi(_sample(wav, i)))
	return peak


func test_actual_period_is_whole_samples() -> void:
	var p: float = HeartbeatAudio.actual_period(60.0 / 90.0)
	assert_almost_eq(p * HeartbeatAudio.MIX_RATE, roundf(p * HeartbeatAudio.MIX_RATE), 0.0001)
	assert_almost_eq(p, 60.0 / 90.0, 1.0 / HeartbeatAudio.MIX_RATE)


func test_loop_covers_one_period() -> void:
	var wav: AudioStreamWAV = HeartbeatAudio.build_loop(0.6, 0.15)
	var frames: int = HeartbeatAudio.frames_for_period(0.6)
	assert_eq(wav.data.size(), frames * 2)
	assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(wav.loop_end, frames)
	assert_false(wav.stereo)


func test_buh_is_louder_than_dum_and_both_sound() -> void:
	var wav: AudioStreamWAV = HeartbeatAudio.build_loop(0.6, 0.15)
	var buh: int = _peak(wav, 0.0, 0.03)
	var dum: int = _peak(wav, 0.15, 0.18)
	assert_gt(dum, 2000, "dum should be audible")
	assert_gt(buh, dum, "buh should be louder than dum")


func test_tail_of_loop_is_near_silent() -> void:
	var wav: AudioStreamWAV = HeartbeatAudio.build_loop(0.6, 0.15)
	assert_lt(_peak(wav, 0.5, 0.6), 300)


func test_thump_is_zero_outside_its_length() -> void:
	assert_eq(HeartbeatAudio.thump(-0.01), 0.0)
	assert_eq(HeartbeatAudio.thump(1.0), 0.0)
