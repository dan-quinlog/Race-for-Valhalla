class_name StageGenerator
extends RefCounted
## Builds stages from shuffled chunks. A stage is laid out as:
##   start | encounter | corridor | encounter | exit door
## The start is one column wide, so the camera scrolls one column to the
## first lock, then a full screen past the corridor to the second.
## Stage n draws its encounters from tiers n-1 and n (tier 1 for stage 1),
## so later stages get harder. The same seed always builds the same stage.

const START: StageChunk = preload("res://stages/chunks/start.tres")
const EXIT: StageChunk = preload("res://stages/chunks/exit.tres")
const ENCOUNTERS: Array[StageChunk] = [
	preload("res://stages/chunks/ambush.tres"),
	preload("res://stages/chunks/wolf_den.tres"),
	preload("res://stages/chunks/shield_line.tres"),
	preload("res://stages/chunks/fire_gate.tres"),
	preload("res://stages/chunks/wolf_pack.tres"),
	preload("res://stages/chunks/shield_wall.tres"),
	preload("res://stages/chunks/warband.tres"),
	preload("res://stages/chunks/burning_pack.tres"),
	preload("res://stages/chunks/shield_breakers.tres"),
]
const CORRIDORS: Array[StageChunk] = [
	preload("res://stages/chunks/corridor_open.tres"),
	preload("res://stages/chunks/corridor_fire.tres"),
	preload("res://stages/chunks/corridor_pillars.tres"),
]
const ENCOUNTERS_PER_STAGE: int = 2


## Encounter chunks stage `stage_number` (1-based) may draw from.
static func encounter_pool(stage_number: int) -> Array[StageChunk]:
	var low: int = maxi(1, stage_number - 1)
	var out: Array[StageChunk] = []
	out.assign(ENCOUNTERS.filter(func(c: StageChunk) -> bool: return c.tier >= low and c.tier <= stage_number))
	return out


## The chunks for stage `stage_number` (1-based), chosen with `rng`.
static func build(stage_number: int, rng: RandomNumberGenerator) -> Array[StageChunk]:
	var pool: Array[StageChunk] = encounter_pool(stage_number)
	var picks: Array[StageChunk] = []
	for i: int in ENCOUNTERS_PER_STAGE:
		var choice: StageChunk = pool[rng.randi_range(0, pool.size() - 1)]
		if pool.size() > 1:
			pool.erase(choice)
		picks.append(choice)
	var corridor: StageChunk = CORRIDORS[rng.randi_range(0, CORRIDORS.size() - 1)]
	var out: Array[StageChunk] = [START, picks[0], corridor, picks[1], EXIT]
	return out
