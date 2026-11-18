class_name Combatant
extends RefCounted
## Anything with health that stands in a zone.

var display_name: String
var max_hp: int
var hp: int
## Zone as Vector2i(column, lane).
var cell: Vector2i


func _init(p_name: String, p_max_hp: int, p_cell: Vector2i) -> void:
	display_name = p_name
	max_hp = p_max_hp
	hp = p_max_hp
	cell = p_cell


func is_alive() -> bool:
	return hp > 0


## Applies damage and returns how much was actually lost.
func take_damage(amount: int) -> int:
	var lost: int = mini(maxi(amount, 0), hp)
	hp -= lost
	return lost
