class_name VargEnemy
extends Enemy
## A wolf: quick and fragile. When a hero is within POUNCE_RANGE steps it
## winds up a pounce on that hero's zone, and leaps into the zone when the
## pounce lands, hit or miss, so its threat keeps moving. Otherwise it
## lopes two zones toward the nearest hero in one step.

const MAX_HP: int = 18
const POUNCE_RANGE: int = 2
const POUNCE_WINDUP: int = 2
const POUNCE_DAMAGE: int = 10
const POUNCE_REST: int = 1
## Zones moved per repositioning step.
const LOPE: int = 2


func _init(p_cell: Vector2i, first_start: int = 0) -> void:
	super("Varg", MAX_HP, p_cell, first_start)


static func pounce(target: Vector2i) -> EnemyMove:
	var zones: Array[Vector2i] = [target]
	return EnemyMove.at_zones("Pounce", zones, POUNCE_WINDUP, POUNCE_DAMAGE, POUNCE_REST)


func decide(_beat: int, stage: StageRules) -> EnemyMove:
	var hero: Hero = stage.nearest_hero(cell)
	if hero == null:
		return null
	if StageRules._distance(hero.cell, cell) <= POUNCE_RANGE:
		return pounce(hero.cell)
	for i: int in LOPE:
		if StageRules._distance(hero.cell, cell) <= 1 or not step_toward(hero.cell, stage):
			break
	return null


## The pounce carries the wolf into the zone it hit, if no other foe is there.
func landed(stage: StageRules) -> void:
	if targets.is_empty():
		return
	var dest: Vector2i = targets[0]
	if dest != cell and stage.enemy_can_enter(dest):
		cell = dest
