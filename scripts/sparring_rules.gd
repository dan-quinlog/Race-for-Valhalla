class_name SparringRules
extends RefCounted
## The Rhythm Lab's training yard for the one-action-per-beat rules. Pure
## logic on beat indices. Heroes and practice dummies stand on a grid of
## LANES by COLS zones. Nothing shares a zone with a dummy; heroes may share
## with each other.
##
## - A direction moves the hero, or attacks the dummy standing there (the
##   hero stays put). Left/right also turns the hero to face that way.
## - With a shield, a move or attack also guards that direction for the
##   beat. If a hit from that side lands on the hero this beat, the hero
##   blocks it and stays put instead of moving. Without a shield the hero
##   moves and takes the hit. Area hits on the hero's zone can't be blocked.
## - Corner runes (RuneCorner):
##   - Prayer blesses the next action. A blessed move evades: it moves and
##     takes no damage that beat. A blessed attack that kills earns bonus
##     glory (no extra damage).
##   - Heavy adds a charge (up to MAX_CHARGE), each +50% on the next basic
##     attack. The hero is exposed (+50% damage taken) while charged.
##   - Prayer and Heavy are charge-style: they don't use up or cancel each
##     other, and a skipped beat keeps both. A move loses the charge, and
##     any action other than those two uses up the blessing.
##   - Trip hits the zone the hero faces, roots the dummy for that beat and
##     the next, and makes it vulnerable (+50%) for the two beats after.
##   - Flourish hits all four zones around the hero at once.
##   Trip and Flourish lose the Heavy charge and don't guard.
##
## Hero actions resolve first (act), then the dummies (end_turn), so a move
## or block on the hit beat counts.
##
## Foes follow simple, repeatable patterns the player learns by sight:
## - Draugr, every other beat: attack/move, then power slam. Attack/move
##   attacks a hero next to it (after the heroes moved), or else steps
##   toward the nearest hero, so backing away keeps it close. The slam hits
##   all four zones around it, so backing away from that makes distance.
##   No warning before either lands.
## - Varg, every beat: if a hero stood in line within LEAP_RANGE zones at
##   the start of the beat (clear path), it leaps along that line and bites,
##   landing next to wherever the hero ended up. A shield facing it stops
##   the hero in place and the Varg just short of them. An evading hero lets
##   it pass into the zone they left. Bodies cut a leap short. It rests a
##   beat after a leap. Otherwise it prowls one zone: first into line with
##   the nearest hero (keeping its distance), then closer along the line.
## - Archer: telegraphed arrow down its lane (countdown shown).

signal logged(text: String)
## Zones to flash in the view, with a short label ("" for none).
signal flashed(cells: Array[Vector2i], color: Color, text: String)
## An arrow flew from `from` and stopped at `to` (column -1: off the yard).
## `outcome` is "HIT", "BLOCK" or "MISS".
signal shot(from: Vector2i, to: Vector2i, outcome: String)

const COLS: int = 8
const LANES: int = 3
const NONE: int = -(1 << 62)
const LEFT: int = -1
const RIGHT: int = 1

const BASIC_DAMAGE: int = 10
const TRIP_DAMAGE: int = 4
const FLOURISH_DAMAGE: int = 6
const MAX_CHARGE: int = 3
## Extra damage per Heavy charge on the next basic attack.
const CHARGE_BONUS: float = 0.5
## Perfect and vulnerable each multiply damage by this.
const BONUS: float = 1.5
const EXPOSED_MULTIPLIER: float = 1.5
const ROOT_BEATS: int = 1
const VULNERABLE_BEATS: int = 2
const KILL_GLORY: int = 3
const BLESSED_KILL_GLORY: int = 5

const HERO_HP: int = 100
const DUMMY_HP: int = 40
const RESPAWN_BEATS: int = 4
## Each striking dummy starts a wind-up every STRIKE_CYCLE beats (at its
## offset) and strikes STRIKE_WINDUP beats later.
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

const ATTACK_COLOR := Color(0.92, 0.25, 0.2)
const LEAP_COLOR := Color(0.75, 0.7, 0.6)
const STRIKE_COLOR := Color(1.0, 0.55, 0.15)
const BLOCK_COLOR := Color(0.6, 0.8, 1.0)
const EVADE_COLOR := Color(1.0, 0.85, 0.3)


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


class Dummy extends Combatant:
	enum Kind { POST, DRAUGR, VARG, ARCHER }
	var kind: Kind
	var home: Vector2i
	var rooted_until: int = NONE
	var vulnerable_until: int = NONE
	var died_on: int = NONE
	## ARCHER: the beat its arrow flies, or NONE, and the zones it threatens.
	var strike_beat: int = NONE
	var targets: Array[Vector2i] = []
	## ARCHER: which beat of STRIKE_CYCLE its wind-up starts on. DRAUGR:
	## which beat of DRAUGR_CYCLE its loop starts on.
	var cycle_offset: int = 0
	## VARG: the beat it leaps on (NONE when not leaping), at which hero,
	## along which line, and the last beat it rests after a leap.
	var leap_beat: int = NONE
	var leap_target: int = -1
	var leap_dir := Vector2i.ZERO
	## Where the target stood when the leap was chosen.
	var leap_aim := Vector2i.ZERO
	var rest_until: int = NONE

	func _init(p_name: String, p_kind: Kind, p_cell: Vector2i, p_hp: int = DUMMY_HP) -> void:
		super(p_name, p_hp, p_cell)
		kind = p_kind
		home = p_cell

	func is_leaping(beat: int) -> bool:
		return leap_beat == beat

	func reset() -> void:
		hp = max_hp
		cell = home
		rooted_until = NONE
		vulnerable_until = NONE
		strike_beat = NONE
		leap_beat = NONE
		rest_until = NONE

	func is_rooted(beat: int) -> bool:
		return beat <= rooted_until

	func is_vulnerable(beat: int) -> bool:
		return beat <= vulnerable_until


var heroes: Array[Fighter] = []
var dummies: Array[Dummy] = []
## Heroes carry a shield.
var shields: bool = true
## The last beat end_turn ran for.
var beat: int = NONE


func _init(player_count: int = 1, p_shields: bool = true) -> void:
	shields = p_shields
	for p: int in player_count:
		heroes.append(Fighter.new(p, Vector2i(1, 1 + p)))
	dummies.append(Dummy.new("Post", Dummy.Kind.POST, Vector2i(3, 1)))
	dummies.append(Dummy.new("Draugr", Dummy.Kind.DRAUGR, Vector2i(5, 0), DRAUGR_HP))
	dummies.append(Dummy.new("Varg", Dummy.Kind.VARG, Vector2i(6, 2), VARG_HP))
	var archer := Dummy.new("Archer", Dummy.Kind.ARCHER, Vector2i(7, 1))
	archer.cycle_offset = 2
	dummies.append(archer)


static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < LANES


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
		if d.is_alive() and d.cell == cell:
			return d
	return null


func hero_at(cell: Vector2i) -> bool:
	return first_hero_at(cell) != null


func first_hero_at(cell: Vector2i) -> Fighter:
	for h: Fighter in heroes:
		if h.cell == cell:
			return h
	return null


## True if a dummy could stand in `cell`: on the yard, nobody there.
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
			_strike(h, [front], TRIP_DAMAGE, a, "Trip", true)
		RuneCorner.Kind.FLOURISH:
			h.charge = 0
			var around: Array[Vector2i] = []
			for d: Rune.Dir in Rune.ALL:
				around.append(h.cell + dir_offset(d))
			_strike(h, around, FLOURISH_DAMAGE, a, "Flourish", false)


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
		h.charge = 0
		_strike(h, [to], dmg, a, label, false)
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


## Deals `base` (before bonuses) to each dummy in `cells`. Uses up the
## blessing: a kill with it earns bonus glory.
func _strike(h: Fighter, cells: Array[Vector2i], base: float, a: TurnAction, label: String, trip: bool) -> void:
	var blessed: bool = h.blessed
	h.blessed = false
	var inside: Array[Vector2i] = []
	inside.assign(cells.filter(func(c: Vector2i) -> bool: return in_bounds(c)))
	var parts: Array[String] = []
	for cell: Vector2i in inside:
		var d: Dummy = dummy_at(cell)
		if d == null:
			continue
		var mult: float = BONUS if a.perfect else 1.0
		if d.is_vulnerable(a.beat):
			mult *= BONUS
		var dealt: int = d.take_damage(roundi(base * mult))
		var note: String = "%s %d" % [d.display_name, dealt]
		if trip:
			d.rooted_until = a.beat + ROOT_BEATS
			d.vulnerable_until = a.beat + VULNERABLE_BEATS
			note += " (rooted, vulnerable)"
		if not d.is_alive():
			d.died_on = a.beat
			var glory: int = KILL_GLORY + (BLESSED_KILL_GLORY if blessed else 0)
			h.glory += glory
			note += " (down! +%d glory)" % glory
		parts.append(note)
	flashed.emit(inside, ATTACK_COLOR, label)
	var text: String = "%s: %s%s" % [h.display_name, label, " PERFECT" if a.perfect else ""]
	_log(text + (" -> " + ", ".join(parts) if not parts.is_empty() else " -> nothing there"))


## True if an arrow or leap from direction `d` comes at `h` this beat, so a
## shield raised that way stands firm. Melee hits (Draugr) aren't predicted:
## they react to where the hero ends up.
func _hit_coming(h: Fighter, n: int, d: int) -> bool:
	for dummy: Dummy in dummies:
		if not dummy.is_alive() or _from_dir(dummy, h) != d:
			continue
		if dummy.strike_beat == n and _threatens(dummy, h):
			return true
		if dummy.is_leaping(n) and heroes[dummy.leap_target] == h:
			return true
	return false


func _threatens(dummy: Dummy, h: Fighter) -> bool:
	return dummy.kind == Dummy.Kind.ARCHER and h.cell.y == dummy.cell.y and h.cell.x < dummy.cell.x


## The Rune.Dir from `h` toward `dummy`: the way a shield must face.
static func _from_dir(dummy: Dummy, h: Fighter) -> int:
	return _dir_toward(h.cell, dummy.cell)


## The Rune.Dir pointing from `a` toward `b` (the longer axis wins).
static func _dir_toward(a: Vector2i, b: Vector2i) -> int:
	var dx: int = b.x - a.x
	var dy: int = b.y - a.y
	if absi(dx) >= absi(dy):
		return Rune.Dir.RIGHT if dx > 0 else Rune.Dir.LEFT
	return Rune.Dir.DOWN if dy > 0 else Rune.Dir.UP


## Beat `n` closed: the dummies act, after the heroes. Then each Varg
## picks its leap for the next beat from where everyone stands now.
func end_turn(n: int) -> void:
	beat = n
	for d: Dummy in dummies:
		if not d.is_alive():
			if d.died_on != NONE and n - d.died_on >= RESPAWN_BEATS and is_free(d.home):
				d.reset()
				_log("%s is back up" % d.display_name)
			continue
		match d.kind:
			Dummy.Kind.DRAUGR:
				_draugr(d, n)
			Dummy.Kind.VARG:
				_varg(d, n)
			Dummy.Kind.ARCHER:
				_strike_cycle(d, n)
	for d: Dummy in dummies:
		if d.kind == Dummy.Kind.VARG and d.is_alive():
			_plan_leap(d, n + 1)
	for h: Fighter in heroes:
		if h.hp <= 0:
			h.hp = h.max_hp
			_log("%s would have fallen. Healed for practice." % h.display_name)


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
		var standing: Array[Fighter] = []
		for h: Fighter in heroes:
			if h.cell == c and h.evade_beat != n:
				standing.append(h)
		if not standing.is_empty():
			# A blocker covers a zone-mate.
			victim = standing[0]
			for h: Fighter in standing:
				if _guards_from(h, before, n):
					victim = h
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


## True if `h` guards against a hit coming from `source` on beat `n`.
func _guards_from(h: Fighter, source: Vector2i, n: int) -> bool:
	return h.guard_beat == n and h.guard_dir == _dir_toward(h.cell, source)


func _strike_cycle(d: Dummy, n: int) -> void:
	if d.strike_beat == n:
		d.strike_beat = NONE
		_loose(d, n)
		return
	if d.strike_beat == NONE and posmod(n - d.cycle_offset, STRIKE_CYCLE) == 0:
		d.strike_beat = n + STRIKE_WINDUP
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


func _guards(h: Fighter, d: Dummy, n: int) -> bool:
	return h.guard_beat == n and h.guard_dir == _from_dir(d, h)


## Resolves a hit from dummy `d` on `h`: "EVADE", "BLOCK" or "HIT".
func _hit_hero(h: Fighter, d: Dummy, n: int, damage: int = STRIKE_DAMAGE) -> String:
	if h.evade_beat == n:
		flashed.emit([h.cell] as Array[Vector2i], EVADE_COLOR, "EVADE")
		_log("%s evades the %s" % [h.display_name, d.display_name])
		return "EVADE"
	if _guards(h, d, n):
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
