class_name HeartbeatAudio
extends RefCounted
## Builds a looping "buh-dum" heartbeat sample. This placeholder sound stays
## until real audio assets exist. The buh starts at sample 0 and the dum
## starts dum_delay seconds later, so the loop position maps straight onto
## beat timing.

const MIX_RATE: int = 44100
const _THUMP_LENGTH: float = 0.25
const _DUM_GAIN: float = 0.6
const _MASTER_GAIN: float = 0.8


## Sample count for one beat. The loop length must be a whole number of samples,
## so the real period is frames / MIX_RATE (see actual_period).
static func frames_for_period(period: float) -> int:
	return maxi(1, roundi(period * MIX_RATE))


static func actual_period(period: float) -> float:
	return frames_for_period(period) / float(MIX_RATE)


static func build_loop(period: float, dum_delay: float) -> AudioStreamWAV:
	var frames: int = frames_for_period(period)
	var dum_start: int = roundi(dum_delay * MIX_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i: int in frames:
		var s: float = thump(float(i) / MIX_RATE)
		if i >= dum_start:
			s += _DUM_GAIN * thump(float(i - dum_start) / MIX_RATE)
		data.encode_s16(i * 2, clampi(roundi(s * _MASTER_GAIN * 32767.0), -32768, 32767))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	return wav


## One low thump: a falling sine with a fast attack and an exponential decay.
## The 2nd harmonic keeps it audible on small phone speakers.
static func thump(t: float) -> float:
	if t < 0.0 or t > _THUMP_LENGTH:
		return 0.0
	var env: float = exp(-t * 18.0) * minf(1.0, t * 400.0)
	var phase: float = TAU * (55.0 * t + (40.0 / 30.0) * (1.0 - exp(-t * 30.0)))
	return env * (sin(phase) + 0.35 * sin(2.0 * phase))
