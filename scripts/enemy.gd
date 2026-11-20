class_name Enemy
extends Combatant
## Base for stage foes. Handles the beat rhythm. Subclasses choose what to do
## each step in decide().
##
## The enemy acts in 2-beat steps (CADENCE). On a step it either repositions
## (decide() moves it and returns null) or starts a telegraphed EnemyMove,
## whose target zones lock in now and which lands `windup` beats later.
## After a hit it rests, then the next step starts in step with where the
## hit landed (`phase`). An odd-count super shifts that rhythm by one beat,
## and the enemy stays off the beat until a Trip (or another super) shifts
## it back. A stagger pushes the pending hit, or the next step, back a beat.
## Everything is on beat indices.

const NONE: int = -(1 << 62)
## Beats per step of the enemy's rhythm.
const CADENCE: int = 2

## The move winding up, or null between moves.
var current: EnemyMove
## Zones the current move will hit.
var targets: Array[Vector2i] = []
## Beat the current move lands on.
var hit_beat: int = NONE
## First beat the next step may happen on.
var next_start: int = 0
## Beat parity the enemy's rhythm is on: 0 is on the beat, 1 is off it.
var phase: int = 0
## Index into the stage's encounters, or -1.
var encounter: int = -1
## Glory for the hero who lands the killing blow.
var glory_value: int = 3

var _hero_cursor: int = 0


func _init(p_name: String, p_max_hp: int, p_cell: Vector2i, first_start: int = 0) -> void:
	super(p_name, p_max_hp, p_cell)
	next_start = first_start
	phase = posmod(first_start, CADENCE)


func is_winding() -> bool:
	return current != null


## True while the current move will land off the beat (on an odd beat).
func is_off_beat() -> bool:
	return is_winding() and posmod(hit_beat, CADENCE) != 0


## True while the enemy's rhythm is shifted off the beat.
func is_rhythm_off_beat() -> bool:
	return phase != 0


## True if the enemy stands in `c`. Bosses cover several zones.
func occupies(c: Vector2i) -> bool:
	return c == cell


## Damage from a hero striking zone `c`. Returns the HP lost. Bosses use
## the zone to damage parts, and `zone_bonus` to boost hits on bare zones.
func take_hit(_c: Vector2i, amount: int, _zone_bonus: bool = true) -> int:
	return take_damage(amount)


## True if `c` is one of the enemy's zones with no armor (no part, or a
## broken one). Only bosses have armor.
func is_unarmored(_c: Vector2i) -> bool:
	return false


## Broken boss parts (0 for ordinary enemies).
func broken_parts() -> int:
	return 0


## Called just before a hero's blow lands, with its RuneAction.Attack (-1 for
## a final strike) and beat. Lets a foe react, e.g. a shield knocked aside.
func on_struck(_attack: int, _beat: int) -> void:
	pass


## Called when the current move lands, before finish(). Lets a foe follow
## through, e.g. a wolf leaping into the zone it pounced on.
func landed(_stage: StageRules) -> void:
	pass


## Beats left until the current move lands, counted from the last closed beat.
func countdown(closed_beat: int) -> int:
	return hit_beat - closed_beat if is_winding() else 0


## Takes a step if one is due on `beat`. Returns true if it acted.
func try_act(beat: int, stage: StageRules) -> bool:
	if is_winding() or beat < next_start or not is_alive() or posmod(beat - phase, CADENCE) != 0:
		return false
	var move: EnemyMove = decide(beat, stage)
	if move == null:
		next_start = beat + CADENCE
		return true
	current = move
	hit_beat = beat + move.windup
	targets = aim(move, stage)
	return true


## Chooses this step. Return a move to wind it up, or null after
## repositioning (or idling).
func decide(_beat: int, _stage: StageRules) -> EnemyMove:
	return null


## Zones a move will hit, locked in when its wind-up starts.
func aim(move: EnemyMove, stage: StageRules) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	match move.target:
		EnemyMove.Target.OWN_ZONE:
			out.append(cell)
		EnemyMove.Target.ALL_ZONES:
			out = stage.visible_cells()
		EnemyMove.Target.LANE_LEFT:
			for col: int in range(stage.camera_col, cell.x):
				out.append(Vector2i(col, cell.y))
		EnemyMove.Target.ZONES:
			out = move.zones.duplicate()
		EnemyMove.Target.HERO_ZONE:
			var living: Array[Hero] = stage.living_heroes()
			if living.is_empty():
				out.append(cell)
			else:
				out.append(living[_hero_cursor % living.size()].cell)
				_hero_cursor += 1
	return out


## Ends the current move after it lands and schedules the next step.
## The enemy's rhythm follows where this hit landed.
func finish(beat: int) -> void:
	phase = posmod(beat, CADENCE)
	next_start = beat + (current.rest if current != null else 0) + 1
	current = null
	targets = []
	hit_beat = NONE


func stagger() -> void:
	if is_winding():
		hit_beat += 1
	else:
		next_start += 1


## Steps one zone toward `goal`, trying the column first unless
## `lane_first`. Only free, on-screen zones count. Returns true if it moved.
func step_toward(goal: Vector2i, stage: StageRules, lane_first: bool = false) -> bool:
	var across := Vector2i(signi(goal.x - cell.x), 0)
	var along := Vector2i(0, signi(goal.y - cell.y))
	var tries: Array[Vector2i] = [across, along]
	if lane_first:
		tries = [along, across]
	for d: Vector2i in tries:
		if d != Vector2i.ZERO and stage.enemy_can_enter(cell + d):
			cell += d
			return true
	return false
