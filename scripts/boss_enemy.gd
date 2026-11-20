class_name BossEnemy
extends Enemy
## An oversized foe covering several zones (`footprint`), with one health
## pool and breakable parts in some zones.
##
## Every hit damages the pool. A hit in an intact part's zone also wears that
## part down. Hits on bare zones (no part, or a broken one) deal bonus
## damage, so body zones are the safer, lower-glory way to win. Each broken
## part bleeds the boss every beat, and its attack slot turns enraged. The
## boss cycles through its parts' attacks in `slots` order, on the usual
## 2-beat rhythm.

const UNARMORED_BONUS: float = 1.5
## HP the boss loses per broken part on every beat.
const BLEED_PER_WOUND: int = 1

var footprint: Array[Vector2i] = []
var parts: Array[BossPart] = []
## Attack order, as parts. Repeats.
var slots: Array[BossPart] = []

var _slot: int = 0
var _newly_broken: Array[BossPart] = []


func _init(p_name: String, p_max_hp: int, anchor: Vector2i, p_footprint: Array[Vector2i], first_start: int = 2) -> void:
	super(p_name, p_max_hp, anchor, first_start)
	footprint = p_footprint
	glory_value = 25


func occupies(c: Vector2i) -> bool:
	return c in footprint


func part_at(c: Vector2i) -> BossPart:
	for p: BossPart in parts:
		if p.cell == c:
			return p
	return null


func is_unarmored(c: Vector2i) -> bool:
	if not occupies(c):
		return false
	var p: BossPart = part_at(c)
	return p == null or p.broken


func broken_parts() -> int:
	return parts.filter(func(p: BossPart) -> bool: return p.broken).size()


func take_hit(c: Vector2i, amount: int, zone_bonus: bool = true) -> int:
	var amt: int = amount
	if zone_bonus and is_unarmored(c):
		amt = roundi(amount * UNARMORED_BONUS)
	var lost: int = take_damage(amt)
	var p: BossPart = part_at(c)
	if p != null and p.wear(amt):
		_newly_broken.append(p)
	return lost


## Parts broken since the last call.
func pop_broken() -> Array[BossPart]:
	var out: Array[BossPart] = _newly_broken
	_newly_broken = []
	return out


func bleed() -> int:
	return take_damage(broken_parts() * BLEED_PER_WOUND)


func decide(_beat: int, _stage: StageRules) -> EnemyMove:
	var p: BossPart = slots[_slot]
	_slot = (_slot + 1) % slots.size()
	return p.enraged if p.broken else p.attack


## The demo boss, a frost giant covering 2 columns by 3 lanes from `anchor`
## (its top-left zone). Club Arm (front top), Head (back top) and Legs
## (back bottom) can break. The other three zones are bare body.
static func jotunn(anchor: Vector2i) -> BossEnemy:
	var front: int = anchor.x
	var back: int = anchor.x + 1
	var fp: Array[Vector2i] = []
	for col: int in [front, back]:
		for lane: int in StageMap.LANES:
			fp.append(Vector2i(col, anchor.y + lane))
	var boss := BossEnemy.new("Jötunn", 300, anchor, fp)

	var flail_zones: Array[Vector2i] = []
	for col: int in [front - 1, front]:
		for lane: int in StageMap.LANES:
			flail_zones.append(Vector2i(col, lane))
	var breath_zones: Array[Vector2i] = []
	for col: int in range(maxi(0, front - 2), back):
		breath_zones.append(Vector2i(col, 0))
	var low_lane: Array[Vector2i] = []
	var low_two: Array[Vector2i] = []
	for col: int in range(maxi(0, front - 2), back + 1):
		low_lane.append(Vector2i(col, 2))
		low_two.append(Vector2i(col, 1))
		low_two.append(Vector2i(col, 2))

	var slam := EnemyMove.new("Club Slam", EnemyMove.Target.HERO_ZONE, 4, 14, 1)
	var flail := EnemyMove.at_zones("Wild Flail", flail_zones, 4, 12, 1)
	var breath := EnemyMove.at_zones("Frost Breath", breath_zones, 4, 12, 1)
	breath.from_dir = Rune.Dir.RIGHT
	var roar := EnemyMove.new("Jötunn's Roar", EnemyMove.Target.ALL_ZONES, 5, 20, 3, true)
	var stomp := EnemyMove.at_zones("Stomp", low_lane, 4, 14, 1)
	var quake := EnemyMove.at_zones("Quake", low_two, 4, 12, 1)

	var club := BossPart.new("Club Arm", Vector2i(front, anchor.y), 40, slam, flail)
	var head := BossPart.new("Head", Vector2i(back, anchor.y), 40, breath, roar)
	var legs := BossPart.new("Legs", Vector2i(back, anchor.y + 2), 40, stomp, quake)
	boss.parts = [club, head, legs]
	boss.slots = [club, head, legs]
	return boss
