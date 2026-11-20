class_name CommandReader
extends RefCounted
## Turns accepted runes into two-beat RuneActions.
##
## The first rune is held as pending. The second must land on the very next
## beat. If that beat closes without a rune (a skipped beat), the pending
## rune is cleared, and a later rune starts a fresh command.  Skipping a beat
## is how a player resets a half-finished command. Works on beat indices, not seconds, so tempo
## changes don't affect it.

const NO_RUNE: int = -1
const PRAYER_GLORY: int = 1
const PERFECT_PRAYER_GLORY: int = 2

## Rune.Dir of the pending first rune, or NO_RUNE.
var pending: int = NO_RUNE
var pending_beat: int = 0
var glory: int = 0
## Blessings from prayers, indexed by Rune.Dir. Consumed by the next action
## that starts with that rune.
var blessings: Array[bool] = [false, false, false, false]

var _pending_perfect: bool = false


## Feeds one accepted rune. Returns the completed action, or null if this
## rune started a new command.
func feed(rune: Rune.Dir, beat: int, perfect: bool) -> RuneAction:
	if pending != NO_RUNE and beat > pending_beat + 1:
		pending = NO_RUNE
	if pending == NO_RUNE:
		pending = rune
		pending_beat = beat
		_pending_perfect = perfect
		return null
	var action: RuneAction = _build(pending as Rune.Dir, rune)
	action.beat = beat
	action.perfect = _pending_perfect and perfect
	pending = NO_RUNE
	return action


## Call when beat `closed`'s input window shuts. Returns true if that was
## the follow-up beat and it passed empty, which clears the pending rune.
func on_beat_closed(closed: int) -> bool:
	if pending != NO_RUNE and closed >= pending_beat + 1:
		pending = NO_RUNE
		return true
	return false


## Backstop for callers without beat_closed: clears a pending rune once its
## follow-up beat is over. Returns true if it cleared one.
func on_beat(beat: int) -> bool:
	return on_beat_closed(beat - 1)


func reset() -> void:
	pending = NO_RUNE
	pending_beat = 0
	glory = 0
	blessings = [false, false, false, false]


## Labels for what each second rune would do after `first`, indexed by Rune.Dir.
static func options_for(first: Rune.Dir) -> Array[String]:
	var out: Array[String] = []
	for d: Rune.Dir in Rune.ALL:
		match first:
			Rune.Dir.DOWN:
				out.append("Move %s" % Rune.DIR_NAMES[d])
			Rune.Dir.LEFT:
				out.append(RuneAction.ATTACK_NAMES[RuneAction.ATTACK_BY_DIR[d]].trim_suffix(" attack"))
			Rune.Dir.RIGHT:
				out.append("Brace %s" % Rune.DIR_NAMES[d])
			Rune.Dir.UP:
				out.append("Glory" if d == Rune.Dir.UP else "Bless %s" % Rune.ROLES[d])
	return out


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
			a.glory = PERFECT_PRAYER_GLORY if _pending_perfect else PRAYER_GLORY
			if blessings[Rune.Dir.UP]:
				# A Prayer blessing doubles the glory of the next Prayer + Prayer.
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
