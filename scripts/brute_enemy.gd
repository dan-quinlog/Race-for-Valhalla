class_name BruteEnemy
extends Enemy
## Alternates steps: move one zone toward the nearest hero, then smash its
## own zone. Dodge out of its zone or brace when it winds up.

const MAX_HP: int = 40
const SMASH_WINDUP: int = 2
const SMASH_DAMAGE: int = 12
const SMASH_REST: int = 1

var attack_next: bool = false


func _init(p_cell: Vector2i, first_start: int = 0) -> void:
	super("Draugr", MAX_HP, p_cell, first_start)


static func smash() -> EnemyMove:
	return EnemyMove.new("Smash", EnemyMove.Target.OWN_ZONE, SMASH_WINDUP, SMASH_DAMAGE, SMASH_REST)


func decide(_beat: int, stage: StageRules) -> EnemyMove:
	attack_next = not attack_next
	if not attack_next:
		return smash()
	var hero: Hero = stage.nearest_hero(cell)
	if hero != null and hero.cell != cell:
		step_toward(hero.cell, stage)
	return null
