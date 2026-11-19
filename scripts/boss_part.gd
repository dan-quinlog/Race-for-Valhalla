class_name BossPart
extends RefCounted
## A breakable part of a boss, tied to one of its zones. Damage dealt in
## that zone wears the part down until it breaks. A broken part is a wound:
## the zone loses its armor, the boss bleeds, and the part's attack turns
## into its nastier `enraged` version.

var display_name: String
var cell: Vector2i
var break_hp: int
var damage: int = 0
var broken: bool = false
## The move this part drives while intact.
var attack: EnemyMove
## The move it drives once broken.
var enraged: EnemyMove


func _init(p_name: String, p_cell: Vector2i, p_break_hp: int, p_attack: EnemyMove, p_enraged: EnemyMove) -> void:
	display_name = p_name
	cell = p_cell
	break_hp = p_break_hp
	attack = p_attack
	enraged = p_enraged


## Adds damage. Returns true if this broke the part.
func wear(amount: int) -> bool:
	if broken:
		return false
	damage += amount
	if damage >= break_hp:
		broken = true
		return true
	return false
