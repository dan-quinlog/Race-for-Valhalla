class_name EnemyMove
extends RefCounted
## One telegraphed enemy attack: which zones it hits, how many beats it
## winds up, how hard it lands, and how long the enemy rests afterwards.
## Regular moves wind up for an even number of beats so they keep the
## enemy's 2-beat rhythm. A super winds up for an odd count, so it lands
## off the beat unless a Trip pushes it back.

enum Target {
	## The zone a hero stands in when the wind-up starts.
	HERO_ZONE,
	## The enemy's own zone.
	OWN_ZONE,
	## Every zone on screen.
	ALL_ZONES,
	## The enemy's lane, from the left edge of the screen up to the enemy.
	LANE_LEFT,
}

var display_name: String
var target: Target
var windup: int
var damage: int
var rest: int
var is_super: bool
## Rune.Dir the hit comes from, or Hero.NO_DIR when it lands in the zone
## itself. A brace must face that side to stop it.
var from_dir: int = Hero.NO_DIR
## Only the targeted hero nearest the attacker is hit (an arrow stops at
## the first body).
var hits_first: bool = false


func _init(p_name: String, p_target: Target, p_windup: int, p_damage: int, p_rest: int, p_super: bool = false) -> void:
	assert(p_windup >= 1, "a move needs at least one beat of wind-up")
	display_name = p_name
	target = p_target
	windup = p_windup
	damage = p_damage
	rest = p_rest
	is_super = p_super
