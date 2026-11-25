class_name RuneCorner
extends RefCounted
## The four runes of the one-action-per-beat prototype. Each sits in a
## corner between two directions, and pressing those two directions
## together (a chord) casts it:
## up-left Prayer, up-right Heavy, down-left Trip, down-right Flourish.
## Names are placeholder Elder Futhark runes chosen to fit each role.

enum Kind { PRAYER, HEAVY, TRIP, FLOURISH }

const ALL: Array[Kind] = [Kind.PRAYER, Kind.HEAVY, Kind.TRIP, Kind.FLOURISH]
const NAMES: Array[String] = ["Ansuz", "Thurisaz", "Isa", "Hagalaz"]
const ROLES: Array[String] = ["Prayer", "Heavy", "Trip", "Flourish"]
## Prayer gold, Heavy red, Trip ice blue, Flourish green.
const COLORS: Array[Color] = [
	Color(1.0, 0.82, 0.2),
	Color(0.92, 0.25, 0.2),
	Color(0.45, 0.75, 1.0),
	Color(0.3, 0.8, 0.4),
]
## Input action suffixes, e.g. "p1_rune_pray".
const ACTION_SUFFIXES: Array[String] = ["pray", "heavy", "trip", "flourish"]
## Charge-style runes build up a state instead of acting. They don't use up
## or cancel each other, and a skipped beat keeps them.
const CHARGE_STYLE: Array[Kind] = [Kind.PRAYER, Kind.HEAVY]


## The rune between two directions, or -1 if they aren't neighbours on
## the diamond (the same direction, or opposites).
static func between(a: Rune.Dir, b: Rune.Dir) -> int:
	var vertical: int = -1
	var horizontal: int = -1
	for d: Rune.Dir in [a, b]:
		if d == Rune.Dir.UP or d == Rune.Dir.DOWN:
			vertical = d
		else:
			horizontal = d
	if vertical < 0 or horizontal < 0:
		return -1
	if vertical == Rune.Dir.UP:
		return Kind.PRAYER if horizontal == Rune.Dir.LEFT else Kind.HEAVY
	return Kind.TRIP if horizontal == Rune.Dir.LEFT else Kind.FLOURISH


static func action_name(player: int, kind: Kind) -> StringName:
	return StringName("p%d_rune_%s" % [player + 1, ACTION_SUFFIXES[kind]])
