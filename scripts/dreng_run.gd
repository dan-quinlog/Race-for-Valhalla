class_name DrengRun
extends RefCounted
## One run of the Dreng (adolescent) arc: STAGE_COUNT generated stages, each
## a little harder, then the Jötunn who guards the ancestors' relic. Heroes
## rest between stages (REST_HEAL). The hall sets `current` before opening
## the stage scene, which plays it.

const STAGE_COUNT: int = 3
const REST_HEAL: int = 30
const BOSS_ARENA: Array[StageChunk] = [preload("res://stages/chunks/jotunn_arena.tres")]

## The run the stage scene should play, or null (it then plays a quick run
## with no lineage).
static var current: DrengRun

## The lineage the heroes belong to, or null for a quick run.
var lineage: Lineage
## Names for player 1 and player 2's heroes.
var hero_names: Array[String] = []
var seed_value: int = 0
## Set once the run's outcome is saved to the lineage.
var recorded: bool = false


func _init(p_lineage: Lineage = null, p_seed: int = 0) -> void:
	lineage = p_lineage
	seed_value = p_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	var first: String = lineage.next_hero_name(rng) if lineage != null else "Player 1"
	var second: String = "Player 2"
	if lineage != null:
		second = first
		while second == first:
			second = lineage.next_hero_name(rng)
	hero_names = [first, second]


func oath() -> int:
	return lineage.oath if lineage != null else Oath.Kind.NONE


## Stages in the run, counting the boss.
func stage_count() -> int:
	return STAGE_COUNT + 1


func is_boss(index: int) -> bool:
	return index == STAGE_COUNT


## Chunks for stage `index` (0-based). Each stage has its own seed, so a
## restarted stage is laid out the same.
func stage_chunks(index: int) -> Array[StageChunk]:
	if is_boss(index):
		return BOSS_ARENA.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, index])
	return StageGenerator.build(index + 1, rng)


func banner(index: int) -> String:
	if is_boss(index):
		return "The Jötunn guards your ancestors' relic! Break its parts for glory, or strike its body to live."
	if index == 0:
		return "The Dreng arc begins: seek the relic of your ancestors. Stage 1 of %d." % STAGE_COUNT
	return "Stage %d of %d. The path grows harder." % [index + 1, STAGE_COUNT]


## Records how the run ended for each hero, once. Does nothing for a quick
## run. Returns true if the lineage changed (and should be saved).
func record(heroes: Array[Hero], won: bool, stage_index: int) -> bool:
	if recorded or lineage == null:
		return false
	recorded = true
	for h: Hero in heroes:
		var fate: Lineage.Fate = Lineage.Fate.COMPLETED_DRENG if won and h.is_alive() else Lineage.Fate.FELL
		lineage.record(hero_names[h.player], h.glory, fate, stage_index + 1)
	return true
