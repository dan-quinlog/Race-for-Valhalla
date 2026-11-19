class_name Hero
extends Combatant
## A player's warrior on a stage. Timed states are stored as the last beat
## they cover, so they follow beat indices rather than seconds.

const NONE: int = -(1 << 62)
## A hit with no direction lands in the hero's own zone.
const NO_DIR: int = -1

var player: int
## Last beat a brace blocks hits on.
var brace_until: int = NONE
## Rune.Dir the brace faces. Blocks hits in the zone and hits from that side.
var brace_dir: int = NO_DIR
## The brace was blessed and strikes back when it blocks.
var brace_blessed: bool = false
## Last beat a warded (blessed) move keeps zone damage off.
var ward_until: int = NONE
## Took a Heavy swing: takes extra damage until the next command completes.
var exposed: bool = false
## Made a Defensive attack: the next hit taken is halved.
var guarded: bool = false
## Glory earned this run: prayers, kills and broken boss parts.
var glory: int = 0


func _init(p_player: int, p_max_hp: int, p_cell: Vector2i) -> void:
	super("Player %d" % (p_player + 1), p_max_hp, p_cell)
	player = p_player


func is_braced(beat: int) -> bool:
	return beat <= brace_until


## True if a brace on `beat` stops a hit coming from `from_dir` (NO_DIR for
## a hit inside the zone, which any brace stops).
func blocks(beat: int, from_dir: int) -> bool:
	return is_braced(beat) and (from_dir == NO_DIR or from_dir == brace_dir)


func is_warded(beat: int) -> bool:
	return beat <= ward_until
