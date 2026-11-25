class_name TurnInput
extends RefCounted
## One player's one-action-per-beat input (the Rhythm Lab prototype).
##
## Each beat takes one input, judged on its first press. A direction alone
## is a move (or an attack on a foe there). Two neighbouring directions
## pressed on the same beat form a chord, which casts the corner rune
## between them (RuneCorner). A rune can also be pressed directly (touch
## corners, Q/E/Z/C, face buttons). The second press of a chord isn't
## judged, but it must come before the beat closes at the dum. The beat's
## input locks and resolves there (close_beat).
##
## A direction pressed just after the dum, on a beat that already took a
## press, is taken as a chord that came too late and ignored, rather than
## counted as a missed press.

const NONE: int = -(1 << 62)

var judge: BeatJudge
var combo := ComboTracker.new()

## The open beat's first direction, or -1.
var dir: int = -1
## The open beat's rune (direct or chord), or -1.
var rune: int = -1
var press_beat: int = NONE
var press_perfect: bool = false

var _last_closed: int = NONE
## The last beat that took a press.
var _last_pressed: int = NONE


func _init(period: float, window: float, perfect_window: float) -> void:
	configure(period, window, perfect_window)


func configure(period: float, window: float, perfect_window: float) -> void:
	judge = BeatJudge.new(period, window, perfect_window)
	combo.reset()
	dir = -1
	rune = -1
	press_beat = NONE
	_last_closed = NONE
	_last_pressed = NONE


func has_open_press() -> bool:
	return press_beat != NONE and (dir >= 0 or rune >= 0) and press_beat > _last_closed


## A direction pressed at time `t`. Returns the judgment, or null if the
## press joined a chord or was ignored.
func press_dir(d: Rune.Dir, t: float) -> BeatJudge.Judgment:
	if has_open_press():
		if rune < 0 and dir >= 0:
			var corner: int = RuneCorner.between(dir as Rune.Dir, d)
			if corner >= 0:
				rune = corner
		return null
	if _is_late_chord(t):
		return null
	var j: BeatJudge.Judgment = _judge(t)
	if j.grade != BeatJudge.Grade.MISS:
		dir = d
		rune = -1
	return j


## A rune pressed directly at time `t`. Ignored (null) if the beat already
## took a press.
func press_rune(r: RuneCorner.Kind, t: float) -> BeatJudge.Judgment:
	if has_open_press():
		return null
	var j: BeatJudge.Judgment = _judge(t)
	if j.grade != BeatJudge.Grade.MISS:
		rune = r
		dir = -1
	return j


## The press is for a beat that already closed (it landed in the window,
## but after the dum fired). Resolve it on its own with resolve_late().
func is_late() -> bool:
	return press_beat != NONE and press_beat <= _last_closed and (dir >= 0 or rune >= 0)


func resolve_late() -> TurnAction:
	return _take(press_beat)


## Beat `n` closed: returns its action, or null for a skipped beat.
func close_beat(n: int) -> TurnAction:
	_last_closed = n
	if press_beat == NONE or press_beat > n:
		return null
	return _take(n)


func _take(n: int) -> TurnAction:
	var a: TurnAction = null
	if rune >= 0:
		a = TurnAction.cast(rune as RuneCorner.Kind, n, press_perfect)
	elif dir >= 0:
		a = TurnAction.direction(dir as Rune.Dir, n, press_perfect)
	dir = -1
	rune = -1
	press_beat = NONE
	return a


func _judge(t: float) -> BeatJudge.Judgment:
	var j: BeatJudge.Judgment = judge.judge(t)
	combo.record(j.grade)
	if j.grade != BeatJudge.Grade.MISS:
		press_beat = j.beat
		press_perfect = j.grade == BeatJudge.Grade.PERFECT
		_last_pressed = j.beat
	return j


func _is_late_chord(t: float) -> bool:
	var beat: int = floori(t / judge.period)
	var since_buh: float = t - beat * judge.period
	return beat == _last_pressed and since_buh > judge.window and since_buh <= judge.window * 2.0
