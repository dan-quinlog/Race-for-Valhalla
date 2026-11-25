class_name TurnAction
extends RefCounted
## One beat's input in the one-action-per-beat prototype: a direction (move
## that way, or attack a foe standing there) or a corner rune.

enum Kind { DIRECTION, RUNE }

var kind: Kind = Kind.DIRECTION
## Rune.Dir for DIRECTION.
var dir: int = -1
## RuneCorner.Kind for RUNE.
var rune: int = -1
var beat: int = 0
## The first press of the beat was Perfect.
var perfect: bool = false


static func direction(d: Rune.Dir, p_beat: int, p_perfect: bool = false) -> TurnAction:
	var a := TurnAction.new()
	a.kind = Kind.DIRECTION
	a.dir = d
	a.beat = p_beat
	a.perfect = p_perfect
	return a


static func cast(r: RuneCorner.Kind, p_beat: int, p_perfect: bool = false) -> TurnAction:
	var a := TurnAction.new()
	a.kind = Kind.RUNE
	a.rune = r
	a.beat = p_beat
	a.perfect = p_perfect
	return a


func describe() -> String:
	var text: String = Rune.DIR_NAMES[dir].capitalize() if kind == Kind.DIRECTION else RuneCorner.ROLES[rune]
	return text + ("  PERFECT" if perfect else "")
