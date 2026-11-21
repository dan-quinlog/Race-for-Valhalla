class_name ShieldThrallEnemy
extends Enemy
## A thrall behind a round shield. While the shield is up, hits deal half
## damage. A Trip or a Heavy swing knocks it down for SHIELD_DOWN_BEATS
## beats (that blow itself lands in full). Alternates a step toward the
## nearest hero with a spear thrust into its own zone and the zone in front
## (to its left).

const MAX_HP: int = 35
const SHIELD_MULTIPLIER: float = 0.5
const SHIELD_DOWN_BEATS: int = 4
const THRUST_WINDUP: int = 2
const THRUST_DAMAGE: int = 10
const THRUST_REST: int = 1

## Last beat the shield is down, or NONE.
var shield_down_until: int = NONE
var attack_next: bool = false

## Beat of the blow being taken, set by on_struck() just before take_hit().
var _beat: int = 0


func _init(p_cell: Vector2i, first_start: int = 0) -> void:
	super("Shield-thrall", MAX_HP, p_cell, first_start)
	glory_value = 4


func is_shielded(beat: int) -> bool:
	return beat > shield_down_until


func on_struck(attack: int, beat: int) -> void:
	_beat = beat
	if attack == RuneAction.Attack.TRIP or attack == RuneAction.Attack.HEAVY:
		var shield_was_up: bool = is_shielded(beat)
		shield_down_until = beat + SHIELD_DOWN_BEATS
		if shield_was_up:
			# This blow is what knocked the shield aside, so it lands in full.
			_beat = shield_down_until


func take_hit(_c: Vector2i, amount: int, _zone_bonus: bool = true) -> int:
	if is_shielded(_beat):
		amount = roundi(amount * SHIELD_MULTIPLIER)
	return take_damage(amount)


func thrust(stage: StageRules) -> EnemyMove:
	var zones: Array[Vector2i] = [cell]
	var front := cell + Vector2i(-1, 0)
	if stage.map.is_open(front):
		zones.append(front)
	return EnemyMove.at_zones("Spear Thrust", zones, THRUST_WINDUP, THRUST_DAMAGE, THRUST_REST)


func decide(_beat_now: int, stage: StageRules) -> EnemyMove:
	attack_next = not attack_next
	if not attack_next:
		return thrust(stage)
	var hero: Hero = stage.nearest_hero(cell)
	# Close in to stand just right of the hero, so the thrust reaches them.
	if hero != null and hero.cell != cell and hero.cell + Vector2i(1, 0) != cell:
		step_toward(hero.cell + Vector2i(1, 0), stage)
	return null
