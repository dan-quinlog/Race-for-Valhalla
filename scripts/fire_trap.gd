class_name FireTrap
extends RefCounted
## A column of zones that burns on a fixed beat cycle: OFF_BEATS quiet, then
## ON_BEATS burning. Heroes in a burning zone when a beat closes take damage,
## unless warded. A brace does not stop fire.

const OFF_BEATS: int = 4
const ON_BEATS: int = 2
const DAMAGE: int = 8

var cells: Array[Vector2i] = []
## Shifts the cycle: beat `offset` is the first quiet beat.
var offset: int = 0


func _init(p_cells: Array[Vector2i], p_offset: int = 0) -> void:
	cells = p_cells
	offset = p_offset


func is_on(beat: int) -> bool:
	return posmod(beat - offset, OFF_BEATS + ON_BEATS) >= OFF_BEATS


## Beats from `beat` until the fire next ignites (0 while burning).
func beats_until_on(beat: int) -> int:
	return maxi(0, OFF_BEATS - posmod(beat - offset, OFF_BEATS + ON_BEATS))
