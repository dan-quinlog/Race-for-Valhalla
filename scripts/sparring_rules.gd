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

signal logged(text: String)
## Zones to flash in the view, with a short label ("" for none).
signal flashed(cells: Array[Vector2i], color: Color, text: String)
## An arrow flew from `from` and stopped at `to` (column -1: off the yard).
## `outcome` is "HIT", "BLOCK" or "MISS".
signal shot(from: Vector2i, to: Vector2i, outcome: String)

enum Yard { SPARRING, BOSS }
enum HitKind { MELEE, PROJECTILE, BEAM, AREA }

const YARD_SIZE := Vector2i(10, 5)
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

	func _init(p_player: int, p_cell: Vector2i) -> void:
		super("P%d" % (p_player + 1), HERO_HP, p_cell)
		player = p_player

	func is_exposed() -> bool:
		return charge > 0


## A boss attack: the zones it hits, how, and how hard.
class BossMove:
	var display_name: String
	var kind: HitKind
	var zones: Array[Vector2i]
	var damage: int

	func _init(p_name: String, p_kind: HitKind, p_zones: Array[Vector2i], p_damage: int) -> void:
		display_name = p_name
		kind = p_kind
		zones = p_zones
		damage = p_damage


## A breakable boss part in one of its zones, with the attack it drives
## while intact and once broken.
class Part:
	var display_name: String
	var cell: Vector2i
	var break_hp: int
	var wear: int = 0
	var broken: bool = false
	var attack: BossMove
	var enraged: BossMove

	func _init(p_name: String, p_cell: Vector2i, p_attack: BossMove, p_enraged: BossMove) -> void:
		display_name = p_name
		cell = p_cell
		break_hp = PART_HP
		attack = p_attack
		enraged = p_enraged


class Dummy extends Combatant:
	enum Kind { POST, DRAUGR, VARG, THRALL, ARCHER, BOSS }
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
		leap_beat = NONE
		rest_until = NONE
		shield_down_until = NONE
		slot = 0
		zone_vulnerable.clear()
		for p: Part in parts:
			p.wear = 0
			p.broken = false


var heroes: Array[Fighter] = []
var dummies: Array[Dummy] = []
var yard: Yard
var cols: int = YARD_SIZE.x
var lanes: int = YARD_SIZE.y
## Heroes carry a shield.
var shields: bool = true
## The last beat end_turn ran for.
var beat: int = NONE


func _init(player_count: int = 1, p_shields: bool = true, p_yard: Yard = Yard.SPARRING) -> void:
	shields = p_shields
	yard = p_yard
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
	if not in_bounds(to) or dummy_at(to) != null:
		_log("%s can't move there" % h.display_name)
		return
	h.cell = to


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
		if not dummy.is_alive() or _from_dir(dummy, h) != d:
			continue
		if dummy.strike_beat == n and _threatens(dummy, h) and dummy.strike_kind != HitKind.AREA:
			return true
		if dummy.is_leaping(n) and heroes[dummy.leap_target] == h:
			return true
	return false


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
	for d: Dummy in dummies:
		if not d.is_alive():
			if d.died_on != NONE and n - d.died_on >= RESPAWN_BEATS and _can_respawn(d):
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
	for d: Dummy in dummies:
		if d.kind == Dummy.Kind.VARG and d.is_alive():
			_plan_leap(d, n + 1)
	for h: Fighter in heroes:
		if h.hp <= 0:
			h.hp = h.max_hp
			_log("%s would have fallen. Healed for practice." % h.display_name)


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
		var move: BossMove = p.enraged if p.broken else p.attack
		d.strike_beat = n + BOSS_WINDUP
		d.strike_kind = move.kind
		d.strike_name = move.display_name
		d.strike_damage = move.damage
		d.targets.assign(move.zones.filter(func(c: Vector2i) -> bool: return in_bounds(c)))
		_log("The %s readies %s" % [d.display_name, move.display_name])


## A telegraphed melee, beam or area attack lands on every hero in its
## zones. Melee and beam: each hero blocks for themselves. Area: only an
## evade avoids it.
func _land(d: Dummy, n: int) -> void:
	var area: bool = d.strike_kind == HitKind.AREA
	flashed.emit(d.targets, AREA_COLOR if area else STRIKE_COLOR, d.strike_name)
	for h: Fighter in heroes:
		if h.cell in d.targets:
			_hit_hero(h, d, n, d.strike_damage, area)
	d.targets.clear()


func _guards(h: Fighter, d: Dummy, n: int) -> bool:
	return h.guard_beat == n and h.guard_dir == _from_dir(d, h)


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
