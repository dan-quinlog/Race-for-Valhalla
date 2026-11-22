class_name TurnInput
extends RefCounted
## One player's one-action-per-beat input (the Rhythm Lab prototype).
##
## Each beat takes one rune press, judged against the buh (Perfect comes
## from the press). The press picks the rune and a direction picks the
## detail: a drag on touch, a direction key or d-pad held with the rune
## (chord), or a second key before the dum (gallop). With no direction, the
## rune's own direction is used, so a plain tap is that rune's "double"
## command: Prayer for glory, Standard attack, step down, brace right.
## The direction locks and the action resolves when the beat closes at the
## dum (close_beat). Release timing is never judged.
##
## Heavy (Attack + up) is a charged move. It charges for at least one beat,
## leaving the hero exposed, then fires:
## - HOLD: when the rune is let go. It fires as the next beat closes after
##   the release (a quick tap fires on the beat after it started). Any new
##   press while charging fires it on that beat and is used up.
## - REPEAT: on the next beat whose input isn't another Heavy (a skipped
##   beat fires it too). Repeating Heavy keeps it charging. The input that
##   fires it is used up.
## A charged Heavy is Perfect if the press that started it was.

enum ChargeMode { HOLD, REPEAT }

const NO_RUNE: int = -1
const NONE: int = -(1 << 62)
const PRAYER_GLORY: int = 1
const PERFECT_PRAYER_GLORY: int = 2

var judge: BeatJudge
var combo := ComboTracker.new()
var charge_mode: ChargeMode = ChargeMode.HOLD
var glory: int = 0
## Blessings from prayers, indexed by Rune.Dir.
var blessings: Array[bool] = [false, false, false, false]

## The rune pressed on the open beat, or NO_RUNE.
var rune: int = NO_RUNE
var press_beat: int = 0
var press_perfect: bool = false
## The direction the press currently points (a Rune.Dir).
var direction: int = NO_RUNE
## The press is still held down.
var held: bool = false

var charging: bool = false
var charge_beat: int = NONE
var charge_perfect: bool = false
var charge_empowered: bool = false
## HOLD mode: the beat a released charge fires on, or NONE.
var fire_beat: int = NONE

var _last_closed: int = NONE


func _init(period: float, window: float, perfect_window: float, mode: ChargeMode = ChargeMode.HOLD) -> void:
	configure(period, window, perfect_window, mode)


func configure(period: float, window: float, perfect_window: float, mode: ChargeMode = charge_mode) -> void:
	judge = BeatJudge.new(period, window, perfect_window)
	charge_mode = mode
	combo.reset()
	glory = 0
	blessings = [false, false, false, false]
	rune = NO_RUNE
	held = false
	charging = false
	charge_beat = NONE
	fire_beat = NONE
	_last_closed = NONE


## A rune pressed at time `t`. Returns the judgment. A press that fires a
## charge is used up (see used_up_charge()).
func press(r: Rune.Dir, t: float) -> BeatJudge.Judgment:
	var j: BeatJudge.Judgment = judge.judge(t)
	combo.record(j.grade)
	if j.grade == BeatJudge.Grade.MISS:
		return j
	if charging and charge_mode == ChargeMode.HOLD:
		if fire_beat == NONE:
			fire_beat = maxi(j.beat, charge_beat + 1)
		return j
	rune = r
	press_beat = j.beat
	press_perfect = j.grade == BeatJudge.Grade.PERFECT
	direction = r
	held = true
	return j


## True if the last accepted press went into firing a held charge.
func press_fires_charge() -> bool:
	return charging and charge_mode == ChargeMode.HOLD and fire_beat != NONE and rune == NO_RUNE


## Points the open press in direction `d` (drag, direction key, gallop key).
func point(d: Rune.Dir) -> void:
	if rune != NO_RUNE:
		direction = d


## The held rune was let go at time `t`.
func release(t: float) -> void:
	if not held:
		return
	held = false
	if charging and charge_mode == ChargeMode.HOLD and fire_beat == NONE:
		fire_beat = maxi(charge_beat + 1, ceili((t - judge.window) / judge.period))


## The press for a beat that already closed (it landed in the window, but
## after the dum fired). Resolves it on its own, outside the charge flow.
func is_late() -> bool:
	return rune != NO_RUNE and press_beat <= _last_closed


func resolve_late() -> RuneAction:
	if charging:
		rune = NO_RUNE
		return null
	return _resolve_press(press_beat)


## Beat `n` closed: locks the direction and returns the hero's action for
## the beat (null for none). A CHARGE action means the hero is charging.
func close_beat(n: int) -> RuneAction:
	_last_closed = n
	var pressed: bool = rune != NO_RUNE and press_beat <= n
	if charging:
		if charge_mode == ChargeMode.HOLD:
			if fire_beat != NONE and fire_beat <= n:
				return _fire(n)
			return _charge_turn(n)
		if pressed and _is_heavy(rune, direction):
			rune = NO_RUNE
			return _charge_turn(n)
		rune = NO_RUNE
		return _fire(n)
	if not pressed:
		return null
	return _resolve_press(n)


static func _is_heavy(r: int, d: int) -> bool:
	return r == Rune.Dir.LEFT and d == Rune.Dir.UP


func _resolve_press(n: int) -> RuneAction:
	var a: RuneAction = _build(rune as Rune.Dir, direction as Rune.Dir)
	a.beat = n
	a.perfect = press_perfect
	rune = NO_RUNE
	if a.kind == RuneAction.Kind.ATTACK and a.attack == RuneAction.Attack.HEAVY:
		charging = true
		charge_beat = n
		charge_perfect = a.perfect
		charge_empowered = a.empowered
		fire_beat = NONE
		if charge_mode == ChargeMode.HOLD and not held:
			fire_beat = n + 1
		return _charge_turn(n)
	return a


func _charge_turn(n: int) -> RuneAction:
	var a := RuneAction.new()
	a.kind = RuneAction.Kind.CHARGE
	a.dir = Rune.Dir.UP
	a.attack = RuneAction.Attack.HEAVY
	a.beat = n
	a.charge_beats = n - charge_beat
	a.empowered = charge_empowered
	a.perfect = charge_perfect
	return a


func _fire(n: int) -> RuneAction:
	var a := RuneAction.new()
	a.kind = RuneAction.Kind.ATTACK
	a.attack = RuneAction.Attack.HEAVY
	a.dir = Rune.Dir.UP
	a.beat = n
	a.charge_beats = n - charge_beat
	a.empowered = charge_empowered
	a.perfect = charge_perfect
	charging = false
	charge_beat = NONE
	fire_beat = NONE
	return a


func _build(first: Rune.Dir, second: Rune.Dir) -> RuneAction:
	var a := RuneAction.new()
	a.dir = second
	match first:
		Rune.Dir.DOWN:
			a.kind = RuneAction.Kind.MOVE
		Rune.Dir.LEFT:
			a.kind = RuneAction.Kind.ATTACK
			a.attack = RuneAction.ATTACK_BY_DIR[second]
		Rune.Dir.RIGHT:
			a.kind = RuneAction.Kind.BRACE
		Rune.Dir.UP:
			a.kind = RuneAction.Kind.PRAY
	if a.kind == RuneAction.Kind.PRAY:
		if second == Rune.Dir.UP:
			a.glory = PERFECT_PRAYER_GLORY if press_perfect else PRAYER_GLORY
			if blessings[Rune.Dir.UP]:
				a.glory *= 2
				a.empowered = true
				blessings[Rune.Dir.UP] = false
			glory += a.glory
		else:
			blessings[second] = true
	else:
		a.empowered = blessings[first]
		blessings[first] = false
	return a
