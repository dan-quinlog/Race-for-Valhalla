class_name SparringRules
extends RefCounted
## The Rhythm Lab's training yard for the one-action-per-beat rules. Pure
## logic on beat indices. Heroes and practice foes ("dummies") stand on a
## grid of `lanes` by `cols` zones. Nothing shares a zone with a foe; heroes
## may share with each other. Two yards (Yard): the sparring yard with
## regular foes, and a boss yard with the Jötunn.
##
## - A direction moves the hero, or attacks the foe standing there (the
##   hero stays put). Left/right also turns the hero to face that way.
## - With a shield, a move or attack also guards that direction for the
##   beat. If a hit from that side lands on the hero this beat, the hero
##   blocks it. A hero moving into a telegraphed hit (arrow, beam, leap)
##   with the shield that way stands firm instead of moving. Without a
##   shield the hero moves and takes the hit. Area hits can't be blocked.
## - Corner runes (RuneCorner):
##   - Prayer blesses the next action. A blessed move evades: it moves and
##     takes no damage that beat. A blessed attack that kills earns bonus
##     glory (no extra damage).
##   - Heavy adds a charge (up to MAX_CHARGE), each +50% on the next basic
##     attack. The hero is exposed (+50% damage taken) while charged.
##   - Prayer and Heavy are charge-style: they don't use up or cancel each
##     other, and a skipped beat keeps both. A move loses the charge, and
##     any action other than those two uses up the blessing.
##   - Trip hits the zone the hero faces, roots the foe for that beat and
##     the next, and makes it vulnerable (+50%) for the two beats after.
##   - Flourish hits all four zones around the hero at once.
##   Trip and Flourish lose the Heavy charge and don't guard.
##
## Hero actions resolve first (act), then the foes (end_turn), so a move or
## block on the hit beat counts.
##
## Hit types (HitKind): melee comes from the attacker's side and a shield
## facing it blocks. A projectile stops at the first hero it reaches, so a
## blocker covers those behind. A beam hits everyone in its line, and each
## must block for themselves. An area hit can't be blocked, only evaded.
## Melee foes give no warning: they follow short fixed patterns the player
## learns by sight. Projectiles, beams and area hits are telegraphed with a
## countdown.
##
## Foes:
## - Draugr, every other beat: attack/move, then power slam. Attack/move
##   attacks a hero next to it (after the heroes moved), or else steps
##   toward the nearest hero, so backing away keeps it close. The slam hits
##   all four zones around it, so backing away from that makes distance.
## - Varg, every beat: if a hero stood in line within LEAP_RANGE zones at
##   the start of the beat (clear path), it leaps along that line and bites
##   the first hero standing in a zone it could land on, stopping just
##   short. Stepping out of the line or out of reach dodges. A shield facing
##   it stands the hero firm. An evading hero is passed. It rests a beat
##   after a leap. Otherwise it prowls one zone: first into line with the
##   nearest hero (keeping its distance), then closer along the line.
## - Shield-thrall, every other beat: attack/move. A spear thrust if a hero
##   stands in the two zones it faces (stops at the first hero, like an
##   arrow), else it turns to the nearest hero and steps to stand in their
##   lane facing them. Its shield halves hits from the front; a charged
##   attack or a Trip from the front knocks it aside for SHIELD_DOWN_BEATS.
##   Hits from above, below or behind land in full.
## - Archer: telegraphed arrow down its lane.
## - Jötunn (boss yard): covers 2x3 zones with one health pool. Bumping into
##   a zone hits that zone: Club Arm, Head and Legs wear down and break
##   (+PART_GLORY), and bare zones (body, broken parts) take +50%. Broken
##   parts bleed it every beat and turn their attack enraged. It cycles its
##   parts' telegraphed attacks: Club Sweep (melee) / Frost Breath (beam) /
##   Stomp (area), enraged to Wild Flail / Jötunn's Roar / Quake. A Trip on
##   a zone makes that zone vulnerable (bosses can't be rooted).
##
## The cave yard (Yard.CAVE) is seen from the side: lanes are height, with
## a terrain tag per zone (Zone). Rows that share a plane (the ground's two
## lanes) are depth, walked freely. Otherwise a hero goes up only on a
## ladder, or by climbing from a hang. Air and vines don't hold you: a hero
## who started the beat in the air acts, then falls one zone (left/right
## drifts). Up in vines hangs: no fall that beat or the next, and the next
## beat's action is free; up again then climbs into the zone above if it
## allows free entry. Down in the air is a plunge: straight down to the
## first foe or footing, +PLUNGE_BONUS_PER_LANE per lane fallen (a depth
## plane is searched for a foe in any of its lanes). Boss knockback attacks
## have a footprint (the zones they hit) and a knockback: a block or evade
## only pushes the hero to the footprint's edge, an unblocked hit knocks
## them the full way. Paths go vertical first, then horizontal, from where
## the hero stood. A wall, a body or a zone without forced entry stops them
## with crush damage; a hero who can't even reach the edge is also stunned
## for the next beat.

signal logged(text: String)
## Zones to flash in the view, with a short label ("" for none).
signal flashed(cells: Array[Vector2i], color: Color, text: String)
## An arrow flew from `from` and stopped at `to` (column -1: off the yard).
## `outcome` is "HIT", "BLOCK" or "MISS".
signal shot(from: Vector2i, to: Vector2i, outcome: String)

enum Yard { SPARRING, BOSS, CAVE }
enum HitKind { MELEE, PROJECTILE, BEAM, AREA }
## What a side-view zone is made of. FLOOR, LEDGE and LADDER hold a hero up;
## AIR and VINES don't (vines can be hung from).
enum Ground { FLOOR, AIR, VINES, LEDGE, LADDER }

const YARD_SIZE := Vector2i(10, 5)
const CAVE_SIZE := Vector2i(10, 6)
## A depth row's height next to a height row's 1.0, for the view.
const DEPTH_ROW_HEIGHT: float = 0.6
const CRUSH_DAMAGE: int = 8
const PLUNGE_BONUS_PER_LANE: float = 0.25
const PLUNGE_MAX_LANES: int = 4
const RUNNER_HP: int = 20
const RUNNER_RESPAWN_BEATS: int = 8
const NO_GUARD: int = -1
const NONE: int = -(1 << 62)
const LEFT: int = -1
const RIGHT: int = 1

const BASIC_DAMAGE: int = 10
const TRIP_DAMAGE: int = 4
const FLOURISH_DAMAGE: int = 6
const MAX_CHARGE: int = 3
## Extra damage per Heavy charge on the next basic attack.
const CHARGE_BONUS: float = 0.5
## Perfect, vulnerable and bare boss zones each multiply damage by this.
const BONUS: float = 1.5
const EXPOSED_MULTIPLIER: float = 1.5
const ROOT_BEATS: int = 1
const VULNERABLE_BEATS: int = 2
const KILL_GLORY: int = 3
const BLESSED_KILL_GLORY: int = 5

const HERO_HP: int = 100
const DUMMY_HP: int = 40
const RESPAWN_BEATS: int = 4
## The Archer starts a wind-up every STRIKE_CYCLE beats (at its offset) and
## looses STRIKE_WINDUP beats later.
const STRIKE_CYCLE: int = 4
const STRIKE_WINDUP: int = 2
const STRIKE_DAMAGE: int = 10

const DRAUGR_HP: int = 40
## The Draugr's loop: stand, attack/move, stand, power slam.
const DRAUGR_CYCLE: int = 4
const DRAUGR_ATTACK_STEP: int = 1
const DRAUGR_SLAM_STEP: int = 3
const DRAUGR_DAMAGE: int = 10
const SLAM_DAMAGE: int = 15
const VARG_HP: int = 20
const VARG_DAMAGE: int = 10
## A hero this many zones away in line (or closer) draws a leap.
const LEAP_RANGE: int = 3
const THRALL_HP: int = 35
## The Shield-thrall's loop: stand, attack/move.
const THRALL_CYCLE: int = 2
const THRALL_REACH: int = 2
const THRUST_DAMAGE: int = 12
const SHIELD_MULTIPLIER: float = 0.5
const SHIELD_DOWN_BEATS: int = 4

const BOSS_HP: int = 300
const BOSS_GLORY: int = 25
const PART_HP: int = 40
const PART_GLORY: int = 10
## HP the boss loses per broken part every beat.
const BLEED_PER_WOUND: int = 1
## The boss starts a telegraphed attack every BOSS_CYCLE beats, landing
## BOSS_WINDUP beats later.
const BOSS_CYCLE: int = 4
const BOSS_WINDUP: int = 2

const ATTACK_COLOR := Color(0.92, 0.25, 0.2)
const LEAP_COLOR := Color(0.75, 0.7, 0.6)
const STRIKE_COLOR := Color(1.0, 0.55, 0.15)
const AREA_COLOR := Color(0.75, 0.4, 1.0)
const BLOCK_COLOR := Color(0.6, 0.8, 1.0)
const EVADE_COLOR := Color(1.0, 0.85, 0.3)
const BREAK_COLOR := Color(1.0, 0.95, 0.6)
const KNOCK_COLOR := Color(0.95, 0.95, 0.95)


## A side-view zone's terrain. Zones on the same `plane` are one level
## (depth between them is walked freely). `free_entry`: a hero may move in
## on their own. `forced_entry`: knockback may carry a hero in.
class Zone:
	var ground: Ground
	var plane: int
	var free_entry: bool = true
	var forced_entry: bool = true

	func _init(p_ground: Ground, p_plane: int) -> void:
		ground = p_ground
		plane = p_plane

	func holds_up() -> bool:
		return ground == Ground.FLOOR or ground == Ground.LEDGE or ground == Ground.LADDER


class Fighter extends Combatant:
	var player: int
	var facing: int = RIGHT
	var glory: int = 0
	var blessed: bool = false
	var charge: int = 0
	## The beat a shield guards on, and the Rune.Dir it guards.
	var guard_beat: int = NONE
	var guard_dir: int = Rune.Dir.RIGHT
	## The beat a blessed move evades on.
	var evade_beat: int = NONE
	## Side view: the beat the hero last grabbed vines (holds that beat and
	## the next), the last beat they're stunned, and whether they ended the
	## last beat in the air (so they fall after acting this one).
	var hang_beat: int = NONE
	var stun_until: int = NONE
	var was_airborne: bool = false

	func _init(p_player: int, p_cell: Vector2i) -> void:
		super("P%d" % (p_player + 1), HERO_HP, p_cell)
		player = p_player

	func is_exposed() -> bool:
		return charge > 0


## A boss attack: the zones it hits (its footprint), how, and how hard. A
## knockback attack also carries a `knock` (columns, lanes; up is -y) and
## the Rune.Dir a shield must face to block it (`guard`, NO_GUARD: toward
## the boss).
class BossMove:
	var display_name: String
	var kind: HitKind
	var zones: Array[Vector2i]
	var damage: int
	var knock := Vector2i.ZERO
	var guard: int = NO_GUARD

	func _init(p_name: String, p_kind: HitKind, p_zones: Array[Vector2i], p_damage: int, p_knock := Vector2i.ZERO, p_guard: int = NO_GUARD) -> void:
		display_name = p_name
		kind = p_kind
		zones = p_zones
		damage = p_damage
		knock = p_knock
		guard = p_guard


## A breakable boss part in one of its zones, with the attack it drives
## while intact and once broken. A part with an `alt` attack alternates the
## two each time its slot comes up.
class Part:
	var display_name: String
	var cell: Vector2i
	var break_hp: int
	var wear: int = 0
	var broken: bool = false
	var attack: BossMove
	var enraged: BossMove
	var alt: BossMove = null
	var alt_enraged: BossMove = null
	var uses: int = 0

	func _init(p_name: String, p_cell: Vector2i, p_attack: BossMove, p_enraged: BossMove) -> void:
		display_name = p_name
		cell = p_cell
		break_hp = PART_HP
		attack = p_attack
		enraged = p_enraged

	func next_move() -> BossMove:
		var use_alt: bool = alt != null and uses % 2 == 1
		uses += 1
		if use_alt:
			return alt_enraged if broken else alt
		return enraged if broken else attack


class Dummy extends Combatant:
	enum Kind { POST, DRAUGR, VARG, THRALL, ARCHER, BOSS, RUNNER }
	var kind: Kind
	var home: Vector2i
	var glory_value: int = KILL_GLORY
	var rooted_until: int = NONE
	var vulnerable_until: int = NONE
	var died_on: int = NONE
	## ARCHER / BOSS: the beat its telegraphed attack lands (NONE when
	## not winding up), the zones it threatens, and what it is.
	var strike_beat: int = NONE
	var targets: Array[Vector2i] = []
	var strike_kind: HitKind = HitKind.PROJECTILE
	var strike_name: String = ""
	var strike_damage: int = STRIKE_DAMAGE
	## A knockback attack's knock and guard direction (see BossMove).
	var strike_knock := Vector2i.ZERO
	var strike_guard: int = NO_GUARD
	## Which beat of its loop it starts on.
	var cycle_offset: int = 0
	## VARG: the beat it leaps on (NONE when not leaping), at which hero,
	## along which line, and the last beat it rests after a leap.
	var leap_beat: int = NONE
	var leap_target: int = -1
	var leap_dir := Vector2i.ZERO
	## Where the target stood when the leap was chosen.
	var leap_aim := Vector2i.ZERO
	var rest_until: int = NONE
	## THRALL: the way it faces (LEFT / RIGHT) and the last beat its shield
	## is knocked aside.
	var facing: int = LEFT
	var home_facing: int = LEFT
	var shield_down_until: int = NONE
	## BOSS: the zones it covers, its parts, its next attack slot, and the
	## last vulnerable beat per zone.
	var footprint: Array[Vector2i] = []
	var parts: Array[Part] = []
	var slot: int = 0
	var zone_vulnerable: Dictionary = {}

	func _init(p_name: String, p_kind: Kind, p_cell: Vector2i, p_hp: int = DUMMY_HP) -> void:
		super(p_name, p_hp, p_cell)
		kind = p_kind
		home = p_cell

	func is_boss() -> bool:
		return not footprint.is_empty()

	func occupies(c: Vector2i) -> bool:
		return c in footprint if is_boss() else c == cell

	func zones() -> Array[Vector2i]:
		return footprint.duplicate() if is_boss() else [cell] as Array[Vector2i]

	func part_at(c: Vector2i) -> Part:
		for p: Part in parts:
			if p.cell == c:
				return p
		return null

	## A boss zone with no armor: no part there, or a broken one.
	func is_bare(c: Vector2i) -> bool:
		if not is_boss():
			return false
		var p: Part = part_at(c)
		return p == null or p.broken

	func broken_parts() -> int:
		return parts.filter(func(p: Part) -> bool: return p.broken).size()

	func is_leaping(beat: int) -> bool:
		return leap_beat == beat

	func is_shielded(beat: int) -> bool:
		return kind == Kind.THRALL and beat > shield_down_until

	func is_rooted(beat: int) -> bool:
		return beat <= rooted_until

	func is_vulnerable(beat: int) -> bool:
		return beat <= vulnerable_until

	## Vulnerable in zone `c` (bosses track it per zone).
	func vulnerable_at(c: Vector2i, beat: int) -> bool:
		if is_boss():
			return beat <= int(zone_vulnerable.get(c, NONE))
		return is_vulnerable(beat)

	func reset() -> void:
		hp = max_hp
		cell = home
		facing = home_facing
		rooted_until = NONE
		vulnerable_until = NONE
		strike_beat = NONE
		targets.clear()
		strike_knock = Vector2i.ZERO
		strike_guard = NO_GUARD
		leap_beat = NONE
		rest_until = NONE
		shield_down_until = NONE
		slot = 0
		zone_vulnerable.clear()
		for p: Part in parts:
			p.wear = 0
			p.broken = false
			p.uses = 0


var heroes: Array[Fighter] = []
var dummies: Array[Dummy] = []
var yard: Yard
var cols: int = YARD_SIZE.x
var lanes: int = YARD_SIZE.y
## Heroes carry a shield.
var shields: bool = true
## The last beat end_turn ran for.
var beat: int = NONE
## Side view: Zone per cell. Empty for the flat, top-down yards.
var terrain: Dictionary = {}
## Rows that are depth (they share a plane with another row).
var depth_rows: Dictionary = {}


func _init(player_count: int = 1, p_shields: bool = true, p_yard: Yard = Yard.SPARRING) -> void:
	shields = p_shields
	yard = p_yard
	if yard == Yard.CAVE:
		_build_cave()
		for p: int in player_count:
			heroes.append(Fighter.new(p, Vector2i(2 + p, 5 - p)))
		var runner := Dummy.new("Runner", Dummy.Kind.RUNNER, Vector2i(1, 4), RUNNER_HP)
		runner.facing = RIGHT
		runner.home_facing = RIGHT
		dummies.append(runner)
		dummies.append(cave_jotunn())
		return
	if yard == Yard.BOSS:
		for p: int in player_count:
			heroes.append(Fighter.new(p, Vector2i(1, 1 + p * 2)))
		dummies.append(jotunn(Vector2i(6, 1)))
		return
	for p: int in player_count:
		heroes.append(Fighter.new(p, Vector2i(1, 2 + p)))
	dummies.append(Dummy.new("Post", Dummy.Kind.POST, Vector2i(3, 1)))
	dummies.append(Dummy.new("Draugr", Dummy.Kind.DRAUGR, Vector2i(6, 0), DRAUGR_HP))
	dummies.append(Dummy.new("Shield-thrall", Dummy.Kind.THRALL, Vector2i(6, 2), THRALL_HP))
	dummies.append(Dummy.new("Varg", Dummy.Kind.VARG, Vector2i(7, 4), VARG_HP))
	var archer := Dummy.new("Archer", Dummy.Kind.ARCHER, Vector2i(9, 1))
	archer.cycle_offset = 2
	dummies.append(archer)


## The frost giant, covering 2 columns by 3 lanes from `anchor` (its
## top-left zone). Club Arm (front top), Head (back top) and Legs (back
## bottom) can break; the other three zones are bare body.
func jotunn(anchor: Vector2i) -> Dummy:
	var boss := Dummy.new("Jötunn", Dummy.Kind.BOSS, anchor, BOSS_HP)
	boss.glory_value = BOSS_GLORY
	var front: int = anchor.x
	var back: int = anchor.x + 1
	var top: int = anchor.y
	var low: int = anchor.y + 2
	for col: int in [front, back]:
		for lane: int in range(top, low + 1):
			boss.footprint.append(Vector2i(col, lane))

	var sweep: Array[Vector2i] = []
	var flail: Array[Vector2i] = []
	for lane: int in range(top, low + 1):
		sweep.append(Vector2i(front - 1, lane))
		flail.append(Vector2i(front - 1, lane))
		flail.append(Vector2i(front - 2, lane))
	var breath: Array[Vector2i] = []
	for col: int in range(0, front):
		breath.append(Vector2i(col, top))
	var stomp: Array[Vector2i] = _ring(boss.footprint, 1)
	var roar: Array[Vector2i] = _ring(boss.footprint, 2)
	var quake: Array[Vector2i] = []
	for col: int in cols:
		for lane: int in [lanes - 2, lanes - 1]:
			var c := Vector2i(col, lane)
			if c not in boss.footprint:
				quake.append(c)

	var club := Part.new("Club Arm", Vector2i(front, top),
			BossMove.new("Club Sweep", HitKind.MELEE, sweep, 14),
			BossMove.new("Wild Flail", HitKind.MELEE, flail, 12))
	var head := Part.new("Head", Vector2i(back, top),
			BossMove.new("Frost Breath", HitKind.BEAM, breath, 12),
			BossMove.new("Jötunn's Roar", HitKind.AREA, roar, 16))
	var legs := Part.new("Legs", Vector2i(back, low),
			BossMove.new("Stomp", HitKind.AREA, stomp, 12),
			BossMove.new("Quake", HitKind.AREA, quake, 12))
	boss.parts = [club, head, legs]
	return boss


## Zones on the yard within `reach` steps of `zones`, not in them.
func _ring(zones: Array[Vector2i], reach: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for col: int in cols:
		for lane: int in lanes:
			var c := Vector2i(col, lane)
			if c in zones:
				continue
			for z: Vector2i in zones:
				if _manhattan(c, z) <= reach:
					out.append(c)
					break
	return out


## The cave, top to bottom: vines (lane 6), the catwalk (5), vines (4),
## open air (3), and two lanes of ground (2-1, one plane). A ladder runs up
## the left column to the top vines.
func _build_cave() -> void:
	cols = CAVE_SIZE.x
	lanes = CAVE_SIZE.y
	for x: int in cols:
		for y: int in lanes:
			var g: Ground = Ground.FLOOR
			if x == 0:
				g = Ground.LADDER
			else:
				match y:
					0, 2:
						g = Ground.VINES
					1:
						g = Ground.LEDGE
					3:
						g = Ground.AIR
			terrain[Vector2i(x, y)] = Zone.new(g, 0 if y >= lanes - 2 else 10 + y)
	_find_depth_rows()


func _find_depth_rows() -> void:
	depth_rows.clear()
	for y: int in lanes:
		for y2: int in lanes:
			if y2 != y and zone_of(Vector2i(1, y)).plane == zone_of(Vector2i(1, y2)).plane:
				depth_rows[y] = true


## The cave's Jötunn: 3 columns by all 6 lanes on the right. Head at the
## catwalk, Chest beside the low vines, Legs on the front ground lane. Each
## part alternates a knockback attack with another:
## - Legs: Kick (6 zones in front of the feet, lanes 1-3; up 1, left 2) /
##   Stomp (area on the ground near it), enraged Quake.
## - Head: Headbutt (2x2 in front of the head; down 2, left 2) / Frost
##   Breath (beam along the catwalk), enraged Jötunn's Roar.
## - Chest: Uppercut (air, vines and catwalk in front; up 2, block facing
##   down) / Club Sweep (the column in front), enraged Wild Flail.
func cave_jotunn() -> Dummy:
	var front: int = cols - 3
	var boss := Dummy.new("Jötunn", Dummy.Kind.BOSS, Vector2i(front, 0), BOSS_HP)
	boss.glory_value = BOSS_GLORY
	for x: int in range(front, cols):
		for y: int in lanes:
			boss.footprint.append(Vector2i(x, y))
	var near: Array[int] = [front - 2, front - 1]
	var up_left := Vector2i(-2, -1)
	var legs := Part.new("Legs", Vector2i(front, 5),
			BossMove.new("Kick", HitKind.MELEE, _block(near, [3, 4, 5]), 12, up_left, Rune.Dir.RIGHT),
			BossMove.new("Raging Kick", HitKind.MELEE, _block(near, [3, 4, 5]), 16, up_left, Rune.Dir.RIGHT))
	legs.alt = BossMove.new("Stomp", HitKind.AREA, _block([front - 3, front - 2, front - 1], [4, 5]), 12)
	legs.alt_enraged = BossMove.new("Quake", HitKind.AREA, _block(range(0, front), [4, 5]), 12)
	var head := Part.new("Head", Vector2i(front, 1),
			BossMove.new("Headbutt", HitKind.MELEE, _block(near, [0, 1]), 14, Vector2i(-2, 2), Rune.Dir.RIGHT),
			BossMove.new("Raging Headbutt", HitKind.MELEE, _block(near, [0, 1]), 18, Vector2i(-2, 2), Rune.Dir.RIGHT))
	head.alt = BossMove.new("Frost Breath", HitKind.BEAM, _block(range(0, front), [1]), 12)
	head.alt_enraged = BossMove.new("Jötunn's Roar", HitKind.AREA, _ring(boss.footprint, 2), 16)
	var chest := Part.new("Chest", Vector2i(front, 2),
			BossMove.new("Uppercut", HitKind.MELEE, _block(near, [1, 2, 3]), 12, Vector2i(0, -2), Rune.Dir.DOWN),
			BossMove.new("Raging Uppercut", HitKind.MELEE, _block(near, [1, 2, 3]), 16, Vector2i(0, -2), Rune.Dir.DOWN))
	chest.alt = BossMove.new("Club Sweep", HitKind.MELEE, _block([front - 1], [1, 2, 3, 4, 5]), 14)
	chest.alt_enraged = BossMove.new("Wild Flail", HitKind.MELEE, _block(near, [1, 2, 3, 4, 5]), 12)
	boss.parts = [legs, head, chest]
	return boss


static func _block(xs: Array, ys: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x: int in xs:
		for y: int in ys:
			out.append(Vector2i(x, y))
	return out


func is_side_view() -> bool:
	return not terrain.is_empty()


func zone_of(c: Vector2i) -> Zone:
	return terrain.get(c) as Zone


func is_depth_row(y: int) -> bool:
	return depth_rows.has(y)


## For the view: a row's height (depth rows are squashed), where it starts,
## and the whole yard's size, in zone widths.
func row_height(y: int) -> float:
	return DEPTH_ROW_HEIGHT if is_depth_row(y) else 1.0


func row_top(y: int) -> float:
	var top: float = 0.0
	for r: int in y:
		top += row_height(r)
	return top


func world_size() -> Vector2:
	return Vector2(cols, row_top(lanes))


## True if `c` holds a hero up. (A hero above a foe stays airborne but
## can't fall into its zone: standing on foes is still to be designed.)
func holds_up(c: Vector2i) -> bool:
	if not is_side_view():
		return true
	var z: Zone = zone_of(c)
	return z == null or z.holds_up()


func is_airborne(h: Fighter) -> bool:
	return is_side_view() and not holds_up(h.cell)


func is_hanging(h: Fighter) -> bool:
	return h.hang_beat != NONE and h.hang_beat == beat


## True if a hero at `from` may move into `to` on their own: no foe there,
## free entry, and up only within a plane or ladder to ladder.
func can_step(from: Vector2i, to: Vector2i) -> bool:
	if not in_bounds(to) or dummy_at(to) != null:
		return false
	if not is_side_view():
		return true
	var z: Zone = zone_of(to)
	if not z.free_entry:
		return false
	if to.y >= from.y:
		return true
	var here: Zone = zone_of(from)
	return here.plane == z.plane or (here.ground == Ground.LADDER and z.ground == Ground.LADDER)


## True if knockback may carry a hero into `c`.
func can_force_into(c: Vector2i) -> bool:
	if not in_bounds(c) or dummy_at(c) != null:
		return false
	var z: Zone = zone_of(c)
	return z == null or z.forced_entry


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < cols and cell.y >= 0 and cell.y < lanes


static func dir_offset(d: int) -> Vector2i:
	match d:
		Rune.Dir.UP:
			return Vector2i(0, -1)
		Rune.Dir.DOWN:
			return Vector2i(0, 1)
		Rune.Dir.LEFT:
			return Vector2i(-1, 0)
	return Vector2i(1, 0)


static func facing_dir(facing: int) -> Rune.Dir:
	return Rune.Dir.LEFT if facing == LEFT else Rune.Dir.RIGHT


func dummy_at(cell: Vector2i) -> Dummy:
	for d: Dummy in dummies:
		if d.is_alive() and d.occupies(cell):
			return d
	return null


func hero_at(cell: Vector2i) -> bool:
	return first_hero_at(cell) != null


func first_hero_at(cell: Vector2i) -> Fighter:
	for h: Fighter in heroes:
		if h.cell == cell:
			return h
	return null


## True if a foe could stand in `cell`: on the yard, nobody there.
func is_free(cell: Vector2i) -> bool:
	return in_bounds(cell) and dummy_at(cell) == null and not hero_at(cell)


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func nearest_hero(from: Vector2i) -> Fighter:
	var best: Fighter = null
	for h: Fighter in heroes:
		if best == null or _manhattan(h.cell, from) < _manhattan(best.cell, from):
			best = h
	return best


## Resolves one hero action for its beat.
func act(player: int, a: TurnAction) -> void:
	if player >= heroes.size() or a == null:
		return
	var h: Fighter = heroes[player]
	if a.beat <= h.stun_until:
		_log("%s is stunned" % h.display_name)
		return
	if a.kind == TurnAction.Kind.DIRECTION:
		_direction(h, a)
		return
	match a.rune:
		RuneCorner.Kind.PRAYER:
			h.blessed = true
			_log("%s prays: the next action is blessed" % h.display_name)
		RuneCorner.Kind.HEAVY:
			h.charge = mini(MAX_CHARGE, h.charge + 1)
			_log("%s charges a Heavy (x%d, exposed)" % [h.display_name, h.charge])
		RuneCorner.Kind.TRIP:
			h.charge = 0
			var front: Vector2i = h.cell + Vector2i(h.facing, 0)
			_strike(h, [front], TRIP_DAMAGE, a, "Trip", true, true)
		RuneCorner.Kind.FLOURISH:
			h.charge = 0
			var around: Array[Vector2i] = []
			for d: Rune.Dir in Rune.ALL:
				around.append(h.cell + dir_offset(d))
			_strike(h, around, FLOURISH_DAMAGE, a, "Flourish", false, false)


func _direction(h: Fighter, a: TurnAction) -> void:
	var d: int = a.dir
	if d == Rune.Dir.LEFT or d == Rune.Dir.RIGHT:
		h.facing = LEFT if d == Rune.Dir.LEFT else RIGHT
	if shields:
		h.guard_beat = a.beat
		h.guard_dir = d
	var to: Vector2i = h.cell + dir_offset(d)
	if is_airborne(h) and (d == Rune.Dir.UP or d == Rune.Dir.DOWN):
		if d == Rune.Dir.UP:
			_hang_or_climb(h, a.beat)
		elif shields and _hit_coming(h, a.beat, d):
			flashed.emit([h.cell] as Array[Vector2i], BLOCK_COLOR, "BLOCK")
			_log("%s holds the shield down and braces" % h.display_name)
		else:
			_plunge(h, a)
		return
	if dummy_at(to) != null:
		var dmg: float = BASIC_DAMAGE * (1.0 + CHARGE_BONUS * h.charge)
		var label: String = "Attack" if h.charge == 0 else "Heavy x%d" % h.charge
		var charged: bool = h.charge > 0
		h.charge = 0
		_strike(h, [to], dmg, a, label, false, charged)
		return
	h.charge = 0
	if h.blessed:
		h.blessed = false
		h.evade_beat = a.beat
		flashed.emit([h.cell] as Array[Vector2i], EVADE_COLOR, "EVADE")
		_step(h, to)
		return
	if shields and _hit_coming(h, a.beat, d):
		flashed.emit([h.cell] as Array[Vector2i], BLOCK_COLOR, "BLOCK")
		_log("%s holds the shield up and stands firm" % h.display_name)
		return
	_step(h, to)


func _step(h: Fighter, to: Vector2i) -> void:
	if not can_step(h.cell, to):
		_log("%s can't move there" % h.display_name)
		return
	h.cell = to


## Up in the air. In vines: hang (no fall this beat or the next), or, on
## the free beat after a hang, climb into the zone above if it lets a hero
## in. Anywhere else there's nothing to grab.
func _hang_or_climb(h: Fighter, n: int) -> void:
	if zone_of(h.cell).ground != Ground.VINES:
		_log("%s grabs at the air" % h.display_name)
		return
	var above: Vector2i = h.cell + Vector2i(0, -1)
	if h.hang_beat == n - 1 and in_bounds(above) and dummy_at(above) == null and zone_of(above).free_entry:
		h.cell = above
		h.hang_beat = NONE
		h.charge = 0
		_log("%s climbs up" % h.display_name)
		return
	h.hang_beat = n
	_log("%s hangs on the vines" % h.display_name)


## Down in the air: drop straight down in one beat onto the first foe, or
## else the first footing. A depth plane is searched in all its lanes, so a
## foe on the near ground lane is hit even with the far one empty. Damage
## grows with each lane fallen. A kill or a pushed foe leaves the hero in
## its zone; a foe that holds leaves the hero on top of it.
func _plunge(h: Fighter, a: TurnAction) -> void:
	var start: Vector2i = h.cell
	var landing: Vector2i = start
	var target := Vector2i(-1, -1)
	var c: Vector2i = start
	while true:
		c += Vector2i(0, 1)
		if not in_bounds(c):
			break
		target = _plunge_target(c)
		if target.x >= 0:
			break
		landing = c
		if zone_of(c).holds_up():
			break
	h.hang_beat = NONE
	if target.x < 0:
		h.charge = 0
		h.blessed = false
		h.cell = landing
		_log("%s drops %d and lands" % [h.display_name, landing.y - start.y])
		return
	var fell: int = target.y - start.y
	var foe: Dummy = dummy_at(target)
	var dmg: float = BASIC_DAMAGE * (1.0 + CHARGE_BONUS * h.charge) * (1.0 + PLUNGE_BONUS_PER_LANE * mini(fell, PLUNGE_MAX_LANES))
	var charged: bool = h.charge > 0
	h.charge = 0
	_strike(h, [target] as Array[Vector2i], dmg, a, "Plunge (%d)" % fell, false, charged)
	var shove: Vector2i = target + Vector2i(h.facing, 0)
	if not foe.is_alive():
		h.cell = target
	elif not foe.is_boss() and is_free(shove) and holds_up(shove):
		foe.cell = shove
		h.cell = target
		_log("%s is knocked aside" % foe.display_name)
	else:
		h.cell = target + Vector2i(0, -1)


## The zone a plunge passing through `c` hits: a foe in `c`, or in a lower
## lane of the same depth plane. (-1, -1) if none.
func _plunge_target(c: Vector2i) -> Vector2i:
	if dummy_at(c) != null:
		return c
	if is_depth_row(c.y):
		for y: int in range(c.y + 1, lanes):
			var below := Vector2i(c.x, y)
			if zone_of(below).plane != zone_of(c).plane:
				break
			if dummy_at(below) != null:
				return below
	return Vector2i(-1, -1)


## Deals `base` (before bonuses) to the foe in each of `cells`. A boss
## covering several of them is hit once per zone. Uses up the blessing: a
## kill with it earns bonus glory. `breaks_guard` (a charged attack or a
## Trip) knocks a Shield-thrall's shield aside when it comes from the front.
func _strike(h: Fighter, cells: Array[Vector2i], base: float, a: TurnAction, label: String, trip: bool, breaks_guard: bool) -> void:
	var blessed: bool = h.blessed
	h.blessed = false
	var inside: Array[Vector2i] = []
	inside.assign(cells.filter(func(c: Vector2i) -> bool: return in_bounds(c)))
	var notes: Array[String] = []
	for cell: Vector2i in inside:
		var d: Dummy = dummy_at(cell)
		if d == null:
			continue
		var mult: float = BONUS if a.perfect else 1.0
		if d.vulnerable_at(cell, a.beat):
			mult *= BONUS
		var extra: String = ""
		if d.is_bare(cell):
			mult *= BONUS
			extra += " (bare)"
		if d.is_shielded(a.beat) and _from_front(d, h.cell):
			if breaks_guard:
				d.shield_down_until = a.beat + SHIELD_DOWN_BEATS
				extra += " (shield knocked aside)"
			else:
				mult *= SHIELD_MULTIPLIER
				extra += " (shield)"
		var dealt: int = d.take_damage(roundi(base * mult))
		var note: String = "%s %d%s" % [d.display_name, dealt, extra]
		if trip:
			if d.is_boss():
				d.zone_vulnerable[cell] = a.beat + VULNERABLE_BEATS
				note += " (zone vulnerable)"
			else:
				d.rooted_until = a.beat + ROOT_BEATS
				d.vulnerable_until = a.beat + VULNERABLE_BEATS
				note += " (rooted, vulnerable)"
		var part: Part = d.part_at(cell)
		if part != null and not part.broken:
			part.wear += dealt
			if part.wear >= part.break_hp:
				part.broken = true
				h.glory += PART_GLORY
				flashed.emit([cell] as Array[Vector2i], BREAK_COLOR, "BROKEN")
				note += " (%s broken! +%d glory)" % [part.display_name, PART_GLORY]
		if not d.is_alive():
			d.died_on = a.beat
			var glory: int = d.glory_value + (BLESSED_KILL_GLORY if blessed else 0)
			h.glory += glory
			note += " (down! +%d glory)" % glory
		notes.append(note)
	flashed.emit(inside, ATTACK_COLOR, label)
	var text: String = "%s: %s%s" % [h.display_name, label, " PERFECT" if a.perfect else ""]
	_log(text + (" -> " + ", ".join(notes) if not notes.is_empty() else " -> nothing there"))


## True if a hero at `from` strikes the Shield-thrall `d` from the side its
## shield faces.
static func _from_front(d: Dummy, from: Vector2i) -> bool:
	return from.y == d.cell.y and signi(from.x - d.cell.x) == d.facing


## True if a telegraphed hit (arrow, beam, leap) from direction `d` comes at
## `h` this beat, so a shield raised that way stands firm. Melee and area
## hits aren't: melee reacts to where the hero ends up, and area can't be
## blocked.
func _hit_coming(h: Fighter, n: int, d: int) -> bool:
	for dummy: Dummy in dummies:
		if not dummy.is_alive():
			continue
		if dummy.strike_beat == n and _threatens(dummy, h) and dummy.strike_kind != HitKind.AREA and _incoming_dir(dummy, h) == d:
			return true
		if dummy.is_leaping(n) and heroes[dummy.leap_target] == h and _from_dir(dummy, h) == d:
			return true
	return false


## The Rune.Dir a shield must face to block `dummy`'s strike on `h`: the
## strike's own guard direction (an uppercut comes from below), or toward
## the foe.
static func _incoming_dir(dummy: Dummy, h: Fighter) -> int:
	return dummy.strike_guard if dummy.strike_guard != NO_GUARD else _from_dir(dummy, h)


func _threatens(dummy: Dummy, h: Fighter) -> bool:
	if dummy.kind == Dummy.Kind.ARCHER:
		return h.cell.y == dummy.cell.y and h.cell.x < dummy.cell.x
	return h.cell in dummy.targets


## The zone of `dummy` nearest `h`: where its hits on `h` come from.
static func _source(dummy: Dummy, h: Fighter) -> Vector2i:
	var best: Vector2i = dummy.cell
	for z: Vector2i in dummy.zones():
		if _manhattan(z, h.cell) < _manhattan(best, h.cell):
			best = z
	return best


## The Rune.Dir from `h` toward `dummy`: the way a shield must face.
static func _from_dir(dummy: Dummy, h: Fighter) -> int:
	return _dir_toward(h.cell, _source(dummy, h))


## The Rune.Dir pointing from `a` toward `b` (the longer axis wins).
static func _dir_toward(a: Vector2i, b: Vector2i) -> int:
	var dx: int = b.x - a.x
	var dy: int = b.y - a.y
	if absi(dx) >= absi(dy):
		return Rune.Dir.RIGHT if dx > 0 else Rune.Dir.LEFT
	return Rune.Dir.DOWN if dy > 0 else Rune.Dir.UP


## Beat `n` closed: the foes act, after the heroes. Then each Varg picks its
## leap for the next beat from where everyone stands now.
func end_turn(n: int) -> void:
	beat = n
	_fall(n)
	for d: Dummy in dummies:
		if not d.is_alive():
			var wait: int = RUNNER_RESPAWN_BEATS if d.kind == Dummy.Kind.RUNNER else RESPAWN_BEATS
			if d.died_on != NONE and n - d.died_on >= wait and _can_respawn(d):
				d.reset()
				_log("%s is back up" % d.display_name)
			continue
		match d.kind:
			Dummy.Kind.DRAUGR:
				_draugr(d, n)
			Dummy.Kind.VARG:
				_varg(d, n)
			Dummy.Kind.THRALL:
				_thrall(d, n)
			Dummy.Kind.ARCHER:
				_strike_cycle(d, n)
			Dummy.Kind.BOSS:
				_boss(d, n)
			Dummy.Kind.RUNNER:
				_runner(d, n)
	for d: Dummy in dummies:
		if d.kind == Dummy.Kind.VARG and d.is_alive():
			_plan_leap(d, n + 1)
	for h: Fighter in heroes:
		if h.hp <= 0:
			h.hp = h.max_hp
			_log("%s would have fallen. Healed for practice." % h.display_name)
		h.was_airborne = is_airborne(h)


## Gravity, after the heroes acted: a hero who started the beat in the air
## and isn't held (hanging this beat or the one before) falls one zone.
func _fall(n: int) -> void:
	if not is_side_view():
		return
	for h: Fighter in heroes:
		if not h.was_airborne or not is_airborne(h) or h.hang_beat == n or h.hang_beat == n - 1:
			continue
		var below: Vector2i = h.cell + Vector2i(0, 1)
		if in_bounds(below) and dummy_at(below) == null:
			h.cell = below
			_log("%s falls" % h.display_name)


## The runner dashes along the ground every beat, turning (and switching
## ground lanes) when blocked. Harmless: it's there to plunge onto.
func _runner(d: Dummy, n: int) -> void:
	if d.is_rooted(n):
		return
	var ahead: Vector2i = d.cell + Vector2i(d.facing, 0)
	if _runway(ahead):
		d.cell = ahead
		return
	d.facing = -d.facing
	for dy: int in [-1, 1]:
		var side: Vector2i = d.cell + Vector2i(0, dy)
		if _runway(side) and zone_of(side).plane == zone_of(d.cell).plane:
			d.cell = side
			return


func _runway(c: Vector2i) -> bool:
	return is_free(c) and (not is_side_view() or zone_of(c).ground == Ground.FLOOR)


func _can_respawn(d: Dummy) -> bool:
	var spots: Array[Vector2i] = [d.home]
	if d.is_boss():
		spots = d.footprint
	for c: Vector2i in spots:
		if not is_free(c):
			return false
	return true


func _draugr(d: Dummy, n: int) -> void:
	match posmod(n - d.cycle_offset, DRAUGR_CYCLE):
		DRAUGR_ATTACK_STEP:
			for h: Fighter in heroes:
				if _manhattan(h.cell, d.cell) == 1:
					_hit_hero(h, d, n, DRAUGR_DAMAGE)
					return
			var h: Fighter = nearest_hero(d.cell)
			if h != null and not d.is_rooted(n):
				_step_toward(d, h.cell, false)
		DRAUGR_SLAM_STEP:
			var around: Array[Vector2i] = []
			for dir: Rune.Dir in Rune.ALL:
				var c: Vector2i = d.cell + dir_offset(dir)
				if in_bounds(c):
					around.append(c)
			flashed.emit(around, STRIKE_COLOR, "SLAM")
			_log("The Draugr slams the ground")
			for h: Fighter in heroes:
				if h.cell in around:
					_hit_hero(h, d, n, SLAM_DAMAGE)


## Steps `d` one zone toward `goal`. `align` tries the shorter axis first
## (to come in line while keeping distance); otherwise the longer one (to
## close in). Falls back to the other axis, then a sidestep.
func _step_toward(d: Dummy, goal: Vector2i, align: bool) -> bool:
	var dx: int = goal.x - d.cell.x
	var dy: int = goal.y - d.cell.y
	var horiz := Vector2i(signi(dx), 0)
	var vert := Vector2i(0, signi(dy))
	var tries: Array[Vector2i] = []
	if dx != 0 and dy != 0:
		var shorter_vert: bool = absi(dy) <= absi(dx)
		tries.assign([vert, horiz] if shorter_vert == align else [horiz, vert])
	else:
		tries.append(horiz + vert)
		# Stuck behind something in line: step around it.
		if dx == 0:
			tries.append_array([Vector2i(-1, 0), Vector2i(1, 0)])
		else:
			tries.append_array([Vector2i(0, -1), Vector2i(0, 1)])
	for t: Vector2i in tries:
		if t != Vector2i.ZERO and is_free(d.cell + t):
			d.cell += t
			return true
	return false


func _varg(d: Dummy, n: int) -> void:
	if d.is_leaping(n):
		_leap(d, n)
		return
	if n <= d.rest_until or d.is_rooted(n):
		return
	var h: Fighter = nearest_hero(d.cell)
	if h != null and _manhattan(h.cell, d.cell) > 1:
		_step_toward(d, h.cell, true)


## Sets up a leap on beat `n` if a hero stands in line within LEAP_RANGE
## with nothing between (rooted: only right next to it).
func _plan_leap(d: Dummy, n: int) -> void:
	d.leap_beat = NONE
	if n <= d.rest_until:
		return
	var reach: int = 1 if d.is_rooted(n) else LEAP_RANGE
	var best: int = -1
	for i: int in heroes.size():
		var c: Vector2i = heroes[i].cell
		var dist: int = _manhattan(c, d.cell)
		if (c.x != d.cell.x and c.y != d.cell.y) or dist > reach:
			continue
		if best != -1 and dist >= _manhattan(heroes[best].cell, d.cell):
			continue
		var step := Vector2i(signi(c.x - d.cell.x), signi(c.y - d.cell.y))
		var clear: bool = true
		for k: int in range(1, dist):
			if not is_free(d.cell + step * k):
				clear = false
		if clear:
			best = i
	if best == -1:
		return
	var aim: Vector2i = heroes[best].cell
	d.leap_beat = n
	d.leap_target = best
	d.leap_aim = aim
	d.leap_dir = Vector2i(signi(aim.x - d.cell.x), signi(aim.y - d.cell.y))


## The leap: along its line, up to LEAP_RANGE zones. It bites the first
## hero standing in a zone it could have landed on, stopping just short of
## them; a hero who stepped out of the line or out of reach dodges it. An
## evading hero is passed. Anything else in the way cuts it short. With no
## one to bite, it lands in the zone its target stood in (or as near as it
## got).
func _leap(d: Dummy, n: int) -> void:
	d.leap_beat = NONE
	d.rest_until = n + 1
	var from: Vector2i = d.cell
	var aim_k: int = _manhattan(d.leap_aim, from)
	var before: Vector2i = from
	var landing: Vector2i = from
	var victim: Fighter = null
	for k: int in range(1, LEAP_RANGE + 1):
		var c: Vector2i = from + d.leap_dir * k
		if not in_bounds(c) or dummy_at(c) != null:
			break
		var standing: Array[Fighter] = _standing_at(c, n)
		if not standing.is_empty():
			victim = _first_to_meet(standing, before, n)
			break
		if hero_at(c):
			for h: Fighter in heroes:
				if h.cell == c:
					_hit_hero(h, d, n, VARG_DAMAGE)
			continue
		before = c
		if k <= aim_k:
			landing = c
	if victim != null:
		landing = before
	var path: Array[Vector2i] = []
	for k: int in range(1, _manhattan(landing, from) + 1):
		path.append(from + d.leap_dir * k)
	d.cell = landing
	if not path.is_empty():
		flashed.emit(path, LEAP_COLOR, "")
	if victim != null:
		_hit_hero(victim, d, n, VARG_DAMAGE)
	else:
		_log("The Varg leaps and snaps at nothing")


## Heroes in `c` who aren't evading on beat `n`.
func _standing_at(c: Vector2i, n: int) -> Array[Fighter]:
	var out: Array[Fighter] = []
	for h: Fighter in heroes:
		if h.cell == c and h.evade_beat != n:
			out.append(h)
	return out


## Of heroes sharing a zone, the one a hit from `source` meets first: a
## blocker covers a zone-mate.
func _first_to_meet(standing: Array[Fighter], source: Vector2i, n: int) -> Fighter:
	for h: Fighter in standing:
		if _guards_from(h, source, n):
			return h
	return standing[0]


## True if `h` guards against a hit coming from `source` on beat `n`.
func _guards_from(h: Fighter, source: Vector2i, n: int) -> bool:
	return h.guard_beat == n and h.guard_dir == _dir_toward(h.cell, source)


## The Shield-thrall's attack/move step: thrust if a hero stands within
## reach in front, else turn to the nearest hero and step to stand in their
## lane, facing them.
func _thrall(d: Dummy, n: int) -> void:
	if posmod(n - d.cycle_offset, THRALL_CYCLE) != 1:
		return
	var reach: Array[Vector2i] = []
	for k: int in range(1, THRALL_REACH + 1):
		var c: Vector2i = d.cell + Vector2i(d.facing * k, 0)
		if not in_bounds(c) or dummy_at(c) != null:
			break
		reach.append(c)
	for c: Vector2i in reach:
		if hero_at(c):
			_thrust(d, reach, n)
			return
	var h: Fighter = nearest_hero(d.cell)
	if h == null:
		return
	if h.cell.x != d.cell.x:
		d.facing = signi(h.cell.x - d.cell.x)
	if d.is_rooted(n):
		return
	# Into the hero's lane first, then up to just in front of them.
	var goal: Vector2i = h.cell - Vector2i(d.facing, 0)
	var vert := Vector2i(0, signi(goal.y - d.cell.y))
	if vert != Vector2i.ZERO and is_free(d.cell + vert):
		d.cell += vert
	elif goal != d.cell:
		_step_toward(d, goal, false)
	if h.cell.x != d.cell.x:
		d.facing = signi(h.cell.x - d.cell.x)


## The spear goes through the zones in front and stops at the first hero
## (a blocker covers those behind; an evader lets it on).
func _thrust(d: Dummy, reach: Array[Vector2i], n: int) -> void:
	flashed.emit(reach, STRIKE_COLOR, "THRUST")
	var before: Vector2i = d.cell
	for c: Vector2i in reach:
		var standing: Array[Fighter] = _standing_at(c, n)
		for h: Fighter in heroes:
			if h.cell == c and h.evade_beat == n:
				_hit_hero(h, d, n, THRUST_DAMAGE)
		if not standing.is_empty():
			_hit_hero(_first_to_meet(standing, before, n), d, n, THRUST_DAMAGE)
			return
		before = c


func _strike_cycle(d: Dummy, n: int) -> void:
	if d.strike_beat == n:
		d.strike_beat = NONE
		_loose(d, n)
		return
	if d.strike_beat == NONE and posmod(n - d.cycle_offset, STRIKE_CYCLE) == 0:
		d.strike_beat = n + STRIKE_WINDUP
		d.strike_kind = HitKind.PROJECTILE
		d.strike_name = "Arrow"
		d.targets.clear()
		for x: int in range(d.cell.x - 1, -1, -1):
			d.targets.append(Vector2i(x, d.cell.y))


## The Archer's arrow flies left down its lane and stops at the first hero
## it reaches. A shield guarding that way blocks it there, so a blocker
## covers everyone behind them (and anyone sharing their zone). A hero who
## evades lets it fly past to the next one. With no one left, it flies off
## the yard. Emits `shot` with where it stopped.
func _loose(d: Dummy, n: int) -> void:
	var line: Array[Fighter] = []
	for h: Fighter in heroes:
		if _threatens(d, h):
			line.append(h)
	# Nearest the Archer first; in a shared zone, a blocker goes first.
	line.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.cell.x > b.cell.x or (a.cell.x == b.cell.x and _guards(a, d, n) and not _guards(b, d, n)))
	var end := Vector2i(-1, d.cell.y)
	var outcome: String = "MISS"
	for h: Fighter in line:
		outcome = _hit_hero(h, d, n)
		if outcome != "EVADE":
			end = h.cell
			break
	if outcome == "EVADE":
		outcome = "MISS"
	shot.emit(d.cell, end, outcome)


## The boss bleeds from its wounds, then runs its telegraphed attacks, one
## part's slot after another.
func _boss(d: Dummy, n: int) -> void:
	var wounds: int = d.broken_parts()
	if wounds > 0:
		d.take_damage(wounds * BLEED_PER_WOUND)
		if not d.is_alive():
			d.died_on = n
			_log("The %s bleeds out. No one earns the kill." % d.display_name)
			return
	if d.strike_beat == n:
		d.strike_beat = NONE
		_land(d, n)
		return
	if d.strike_beat == NONE and posmod(n - d.cycle_offset, BOSS_CYCLE) == 0:
		var p: Part = d.parts[d.slot]
		d.slot = (d.slot + 1) % d.parts.size()
		var move: BossMove = p.next_move()
		d.strike_beat = n + BOSS_WINDUP
		d.strike_kind = move.kind
		d.strike_name = move.display_name
		d.strike_damage = move.damage
		d.strike_knock = move.knock
		d.strike_guard = move.guard
		d.targets.assign(move.zones.filter(func(c: Vector2i) -> bool: return in_bounds(c)))
		_log("The %s readies %s" % [d.display_name, move.display_name])


## A telegraphed melee, beam or area attack lands on every hero in its
## zones. Melee and beam: each hero blocks for themselves. Area: only an
## evade avoids it.
func _land(d: Dummy, n: int) -> void:
	var area: bool = d.strike_kind == HitKind.AREA
	flashed.emit(d.targets, AREA_COLOR if area else STRIKE_COLOR, d.strike_name)
	var footprint: Array[Vector2i] = d.targets.duplicate()
	for h: Fighter in heroes:
		if h.cell not in footprint:
			continue
		var outcome: String = _hit_hero(h, d, n, d.strike_damage, area)
		if d.strike_knock == Vector2i.ZERO:
			continue
		if outcome == "HIT":
			_knock_back(h, d, d.strike_knock)
		else:
			_push_to_edge(h, d, footprint, n)
	d.targets.clear()
	d.strike_knock = Vector2i.ZERO
	d.strike_guard = NO_GUARD


## Knockback steps: the vertical part first, then the horizontal.
static func knock_steps(knock: Vector2i) -> Array[Vector2i]:
	var steps: Array[Vector2i] = []
	for i: int in absi(knock.y):
		steps.append(Vector2i(0, signi(knock.y)))
	for i: int in absi(knock.x):
		steps.append(Vector2i(signi(knock.x), 0))
	return steps


## An unblocked knockback: the full path from where the hero stood. A wall,
## a body or a zone without forced entry stops it, with crush damage.
func _knock_back(h: Fighter, d: Dummy, knock: Vector2i) -> void:
	h.hang_beat = NONE
	var at: Vector2i = h.cell
	var crushed: bool = false
	for s: Vector2i in knock_steps(knock):
		if not can_force_into(at + s):
			crushed = true
			break
		at += s
	h.cell = at
	flashed.emit([at] as Array[Vector2i], KNOCK_COLOR, "KNOCKED")
	if crushed:
		_crush(h, d)


## A blocked or evaded knockback attack still shoves: along the knockback
## path only until the hero is out of the attack's footprint (past the end
## of the path if need be). A hero who can't get out is stopped where they
## are, crushed and stunned for the next beat.
func _push_to_edge(h: Fighter, d: Dummy, footprint: Array[Vector2i], n: int) -> void:
	h.hang_beat = NONE
	var steps: Array[Vector2i] = knock_steps(d.strike_knock)
	var at: Vector2i = h.cell
	var i: int = 0
	while at in footprint:
		var s: Vector2i = steps[mini(i, steps.size() - 1)]
		i += 1
		if not can_force_into(at + s):
			h.cell = at
			h.stun_until = n + 1
			flashed.emit([at] as Array[Vector2i], KNOCK_COLOR, "STUNNED")
			_log("%s is pinned and stunned" % h.display_name)
			_crush(h, d)
			return
		at += s
	h.cell = at
	flashed.emit([at] as Array[Vector2i], KNOCK_COLOR, "PUSHED")


func _crush(h: Fighter, d: Dummy) -> void:
	var lost: int = h.take_damage(CRUSH_DAMAGE)
	flashed.emit([h.cell] as Array[Vector2i], STRIKE_COLOR, "CRUSH %d" % lost)
	_log("%s is crushed against the wall by the %s for %d" % [h.display_name, d.display_name, lost])


func _guards(h: Fighter, d: Dummy, n: int) -> bool:
	return h.guard_beat == n and h.guard_dir == _incoming_dir(d, h)


## Resolves a hit from foe `d` on `h`: "EVADE", "BLOCK" or "HIT".
func _hit_hero(h: Fighter, d: Dummy, n: int, damage: int = STRIKE_DAMAGE, unblockable: bool = false) -> String:
	if h.evade_beat == n:
		flashed.emit([h.cell] as Array[Vector2i], EVADE_COLOR, "EVADE")
		_log("%s evades the %s" % [h.display_name, d.display_name])
		return "EVADE"
	if not unblockable and _guards(h, d, n):
		flashed.emit([h.cell] as Array[Vector2i], BLOCK_COLOR, "BLOCK")
		_log("%s blocks the %s" % [h.display_name, d.display_name])
		return "BLOCK"
	var dmg: float = damage * (EXPOSED_MULTIPLIER if h.is_exposed() else 1.0)
	var lost: int = h.take_damage(roundi(dmg))
	flashed.emit([h.cell] as Array[Vector2i], STRIKE_COLOR, "HIT %d" % lost)
	_log("The %s hits %s for %d%s" % [d.display_name, h.display_name, lost, " (exposed!)" if h.is_exposed() else ""])
	return "HIT"


func _log(text: String) -> void:
	logged.emit(text)
