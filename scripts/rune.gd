class_name Rune
extends RefCounted
## The four rune inputs. They sit at the points of a diamond.
## Names are placeholder Elder Futhark runes chosen to fit each role.

enum Dir { UP, DOWN, LEFT, RIGHT }

const ALL: Array[Dir] = [Dir.UP, Dir.DOWN, Dir.LEFT, Dir.RIGHT]
const NAMES: Array[String] = ["Ansuz", "Raidho", "Tiwaz", "Algiz"]
const ROLES: Array[String] = ["Prayer", "Movement", "Attack", "Defense"]
const DIR_NAMES: Array[String] = ["up", "down", "left", "right"]
## Color code per rune: Prayer gold, Movement green, Attack red, Defense blue.
const COLORS: Array[Color] = [
	Color(1.0, 0.82, 0.2),
	Color(0.3, 0.8, 0.4),
	Color(0.92, 0.25, 0.2),
	Color(0.3, 0.55, 1.0),
]
## Input action suffixes, e.g. "p1_up".
const ACTION_SUFFIXES: Array[String] = ["up", "down", "left", "right"]


static func action_name(player: int, dir: Dir) -> StringName:
	return StringName("p%d_%s" % [player + 1, ACTION_SUFFIXES[dir]])
