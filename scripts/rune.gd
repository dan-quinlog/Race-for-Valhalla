class_name Rune
extends RefCounted
## The four rune inputs. They sit at the points of a diamond.
## Names are placeholder Elder Futhark runes chosen to fit each role.

enum Dir { UP, DOWN, LEFT, RIGHT }

const ALL: Array[Dir] = [Dir.UP, Dir.DOWN, Dir.LEFT, Dir.RIGHT]
const NAMES: Array[String] = ["Ansuz", "Raidho", "Tiwaz", "Algiz"]
const ROLES: Array[String] = ["Prayer", "Movement", "Attack", "Defense"]
const DIR_NAMES: Array[String] = ["up", "down", "left", "right"]
## Input action suffixes, e.g. "p1_up".
const ACTION_SUFFIXES: Array[String] = ["up", "down", "left", "right"]


static func action_name(player: int, dir: Dir) -> StringName:
	return StringName("p%d_%s" % [player + 1, ACTION_SUFFIXES[dir]])
