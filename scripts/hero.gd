class_name Hero
extends Combatant
## A player's warrior in a fight. Timed states are stored as the last beat
## they cover, so they follow beat indices rather than seconds.

const NONE: int = -(1 << 62)

var player: int
## Last beat a brace blocks hits on.
var brace_until: int = NONE
## The brace was blessed and strikes back when it blocks.
var brace_blessed: bool = false
## Last beat a warded (blessed) move keeps room damage off.
var ward_until: int = NONE
## Took a Heavy swing: takes extra damage until the next command completes.
var exposed: bool = false
## Made a Defensive attack: the next hit taken is halved.
var guarded: bool = false


func _init(p_player: int, p_max_hp: int, p_room: int) -> void:
	super("Player %d" % (p_player + 1), p_max_hp, p_room)
	player = p_player


func is_braced(beat: int) -> bool:
	return beat <= brace_until


func is_warded(beat: int) -> bool:
	return beat <= ward_until
