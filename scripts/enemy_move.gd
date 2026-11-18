class_name EnemyMove
extends RefCounted
## One telegraphed enemy attack: which rooms it hits, how many beats it
## winds up, how hard it lands, and how long the enemy rests afterwards.
## Regular moves wind up for an even number of beats so they land on the
## enemy's 2-beat grid. A super winds up for an odd count, so it lands
## off-beat unless a Trip pushes it back onto the grid.

enum Target {
	## The room a hero stands in when the wind-up starts.
	HERO_ROOM,
	## The enemy's own room.
	OWN_ROOM,
	## Every room on the strip.
	ALL_ROOMS,
}

var display_name: String
var target: Target
var windup: int
var damage: int
var rest: int
var is_super: bool


func _init(p_name: String, p_target: Target, p_windup: int, p_damage: int, p_rest: int, p_super: bool = false) -> void:
	assert(p_windup >= 1, "a move needs at least one beat of wind-up")
	display_name = p_name
	target = p_target
	windup = p_windup
	damage = p_damage
	rest = p_rest
	is_super = p_super
