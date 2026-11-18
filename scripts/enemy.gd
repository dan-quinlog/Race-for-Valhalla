class_name Enemy
extends Combatant
## A foe that loops through a pattern of telegraphed moves.
##
## When a move starts, its target rooms are locked in and its hit lands
## `windup` beats later. After the hit the enemy rests, then starts the next
## move. A stagger pushes the pending hit (or the next wind-up) back one beat.
## Moves only start on the CADENCE grid (even beats), so moves with even
## wind-ups land on the grid and an odd-count super lands off it.
## Everything is on beat indices.

const NONE: int = -(1 << 62)
## Beats per step of the enemy's rhythm. Wind-ups start on multiples of this.
const CADENCE: int = 2

var pattern: Array[EnemyMove] = []
## The move winding up, or null while resting.
var current: EnemyMove
## Rooms the current move will hit.
var targets: Array[int] = []
## Beat the current move lands on.
var hit_beat: int = NONE
## First beat a new wind-up may start on.
var next_start: int = 0

var _pattern_index: int = 0
var _hero_cursor: int = 0


func _init(p_name: String, p_max_hp: int, p_room: int, p_pattern: Array[EnemyMove], first_start: int = 0) -> void:
	super(p_name, p_max_hp, p_room)
	assert(not p_pattern.is_empty(), "an enemy needs at least one move")
	pattern = p_pattern
	next_start = first_start


func is_winding() -> bool:
	return current != null


## True while the current move will land off the 2-beat grid.
func is_off_beat() -> bool:
	return is_winding() and posmod(hit_beat, CADENCE) != 0


## Beats left until the current move lands, counted from the last closed beat.
func countdown(closed_beat: int) -> int:
	return hit_beat - closed_beat if is_winding() else 0


## Starts the next move if resting is over and the beat is on the grid.
## Returns true if one started.
func try_start(beat: int, room_count: int, heroes: Array[Hero]) -> bool:
	if is_winding() or beat < next_start or not is_alive() or posmod(beat, CADENCE) != 0:
		return false
	current = pattern[_pattern_index]
	_pattern_index = (_pattern_index + 1) % pattern.size()
	hit_beat = beat + current.windup
	targets = _pick_targets(current.target, room_count, heroes)
	return true


## Ends the current move after it lands and schedules the next wind-up.
func finish(beat: int) -> void:
	next_start = beat + (current.rest if current != null else 0) + 1
	current = null
	targets = []
	hit_beat = NONE


func stagger() -> void:
	if is_winding():
		hit_beat += 1
	else:
		next_start += 1


func _pick_targets(target: EnemyMove.Target, room_count: int, heroes: Array[Hero]) -> Array[int]:
	var out: Array[int] = []
	match target:
		EnemyMove.Target.OWN_ROOM:
			out.append(room)
		EnemyMove.Target.ALL_ROOMS:
			for r: int in room_count:
				out.append(r)
		EnemyMove.Target.HERO_ROOM:
			var living: Array[Hero] = heroes.filter(func(h: Hero) -> bool: return h.is_alive())
			if living.is_empty():
				out.append(room)
			else:
				out.append(living[_hero_cursor % living.size()].room)
				_hero_cursor += 1
	return out
