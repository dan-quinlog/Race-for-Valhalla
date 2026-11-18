class_name PatternEnemy
extends Enemy
## A foe that loops a fixed list of telegraphed moves and never moves.
## The groundwork for bosses, such as the Draugr with its off-beat super.

var pattern: Array[EnemyMove] = []

var _index: int = 0


func _init(p_name: String, p_max_hp: int, p_cell: Vector2i, p_pattern: Array[EnemyMove], first_start: int = 0) -> void:
	super(p_name, p_max_hp, p_cell, first_start)
	assert(not p_pattern.is_empty(), "a pattern enemy needs at least one move")
	pattern = p_pattern


func decide(_beat: int, _stage: StageRules) -> EnemyMove:
	var move: EnemyMove = pattern[_index]
	_index = (_index + 1) % pattern.size()
	return move


## The Draugr from the first fight: four on-beat moves and the off-beat
## Grave Wrath super, which one Trip puts back on the beat.
static func draugr(p_cell: Vector2i, first_start: int = 2) -> PatternEnemy:
	var claw := EnemyMove.new("Grave Claw", EnemyMove.Target.HERO_ZONE, 4, 12, 1)
	var slam := EnemyMove.new("Barrow Slam", EnemyMove.Target.OWN_ZONE, 4, 18, 1)
	var howl := EnemyMove.new("Death Howl", EnemyMove.Target.ALL_ZONES, 4, 8, 3)
	var wrath := EnemyMove.new("Grave Wrath", EnemyMove.Target.ALL_ZONES, 5, 24, 3, true)
	var p: Array[EnemyMove] = [claw, slam, howl, claw, wrath]
	return PatternEnemy.new("Draugr", 120, p_cell, p, first_start)
