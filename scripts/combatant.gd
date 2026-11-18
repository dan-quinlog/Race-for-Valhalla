class_name Combatant
extends RefCounted
## Anything with health that stands in a room.

var display_name: String
var max_hp: int
var hp: int
## Room index on the strip (0 = left).
var room: int


func _init(p_name: String, p_max_hp: int, p_room: int) -> void:
	display_name = p_name
	max_hp = p_max_hp
	hp = p_max_hp
	room = p_room


func is_alive() -> bool:
	return hp > 0


## Applies damage and returns how much was actually lost.
func take_damage(amount: int) -> int:
	var lost: int = mini(maxi(amount, 0), hp)
	hp -= lost
	return lost
