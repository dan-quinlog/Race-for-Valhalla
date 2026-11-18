class_name RangerEnemy
extends Enemy
## Holds its column (the far right of its area). Each step, if a hero stands
## in its lane to the left, it nocks an arrow that flies down the lane and
## hits the first hero in line. Otherwise it shifts one lane toward the
## nearest hero. Brace right to block the arrow.

const MAX_HP: int = 25
const ARROW_WINDUP: int = 2
const ARROW_DAMAGE: int = 10
const ARROW_REST: int = 1


func _init(p_cell: Vector2i, first_start: int = 0) -> void:
	super("Archer", MAX_HP, p_cell, first_start)


static func arrow() -> EnemyMove:
	var move := EnemyMove.new("Arrow", EnemyMove.Target.LANE_LEFT, ARROW_WINDUP, ARROW_DAMAGE, ARROW_REST)
	move.from_dir = Rune.Dir.RIGHT
	move.hits_first = true
	return move


func decide(_beat: int, stage: StageRules) -> EnemyMove:
	if stage.hero_in_line_left(self):
		return arrow()
	var hero: Hero = stage.nearest_hero(cell, true)
	if hero != null and hero.cell.y != cell.y:
		step_toward(Vector2i(cell.x, hero.cell.y), stage, true)
	return null
