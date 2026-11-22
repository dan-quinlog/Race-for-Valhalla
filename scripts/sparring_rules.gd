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

const ATTACK_COLOR := Color(0.92, 0.25, 0.2)
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
	enum Kind { POST, WALKER, SPARRER, ARCHER }
	var kind: Kind
	var home: Vector2i
	## WALKER: the way it's walking, between min_col and max_col.
	var walk_dir: int = LEFT
	var min_col: int = 0
	var max_col: int = COLS - 1
	var rooted_until: int = NONE
	var vulnerable_until: int = NONE
	var died_on: int = NONE
	## SPARRER / ARCHER: the beat its strike lands, or NONE, and the zones
	## it threatens.
	var strike_beat: int = NONE
	var targets: Array[Vector2i] = []
	## Which beat of STRIKE_CYCLE its wind-up starts on.
	var cycle_offset: int = 0

	func _init(p_name: String, p_kind: Kind, p_cell: Vector2i) -> void:
		super(p_name, DUMMY_HP, p_cell)
		kind = p_kind
		home = p_cell

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
	var walker := Dummy.new("Walker", Dummy.Kind.WALKER, Vector2i(5, 0))
	walker.min_col = 2
	walker.max_col = 6
	dummies.append(walker)
	dummies.append(Dummy.new("Sparrer", Dummy.Kind.SPARRER, Vector2i(6, 2)))
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
	for h: Fighter in heroes:
		if h.cell == cell:
			return true
	return false


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


## True if a hit from direction `d` lands on `h`'s zone this beat.
func _hit_coming(h: Fighter, n: int, d: int) -> bool:
	for dummy: Dummy in dummies:
		if dummy.is_alive() and dummy.strike_beat == n and _threatens(dummy, h) and _from_dir(dummy, h) == d:
			return true
	return false


func _threatens(dummy: Dummy, h: Fighter) -> bool:
	if dummy.kind == Dummy.Kind.ARCHER:
		return h.cell.y == dummy.cell.y and h.cell.x < dummy.cell.x
	return h.cell in dummy.targets


static func _from_dir(dummy: Dummy, h: Fighter) -> int:
	return Rune.Dir.RIGHT if dummy.cell.x > h.cell.x else Rune.Dir.LEFT


## Beat `n` closed: the dummies act, after the heroes.
func end_turn(n: int) -> void:
	beat = n
	for d: Dummy in dummies:
		if not d.is_alive():
			if d.died_on != NONE and n - d.died_on >= RESPAWN_BEATS and dummy_at(d.home) == null and not hero_at(d.home):
				d.hp = d.max_hp
				d.cell = d.home
				d.rooted_until = NONE
				d.vulnerable_until = NONE
				d.strike_beat = NONE
				_log("%s is back up" % d.display_name)
			continue
		match d.kind:
			Dummy.Kind.WALKER:
				_walk(d, n)
			Dummy.Kind.SPARRER, Dummy.Kind.ARCHER:
				_strike_cycle(d, n)
	for h: Fighter in heroes:
		if h.hp <= 0:
			h.hp = h.max_hp
			_log("%s would have fallen. Healed for practice." % h.display_name)


func _walk(d: Dummy, n: int) -> void:
	if d.is_rooted(n):
		return
	for attempt: int in 2:
		var to: Vector2i = d.cell + Vector2i(d.walk_dir, 0)
		if to.x >= d.min_col and to.x <= d.max_col and dummy_at(to) == null and not hero_at(to):
			d.cell = to
			return
		d.walk_dir = -d.walk_dir


func _strike_cycle(d: Dummy, n: int) -> void:
	if d.strike_beat == n:
		d.strike_beat = NONE
		if d.kind == Dummy.Kind.ARCHER:
			_loose(d, n)
		else:
			flashed.emit(d.targets, STRIKE_COLOR, "Swing")
			for h: Fighter in heroes:
				if h.cell in d.targets:
					_hit_hero(h, d, n)
		return
	if d.strike_beat == NONE and posmod(n - d.cycle_offset, STRIKE_CYCLE) == 0:
		d.strike_beat = n + STRIKE_WINDUP
		d.targets.clear()
		if d.kind == Dummy.Kind.ARCHER:
			for x: int in range(d.cell.x - 1, -1, -1):
				d.targets.append(Vector2i(x, d.cell.y))
		else:
			for side: int in [LEFT, RIGHT]:
				var c: Vector2i = d.cell + Vector2i(side, 0)
				if in_bounds(c):
					d.targets.append(c)


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
func _hit_hero(h: Fighter, d: Dummy, n: int) -> String:
	if h.evade_beat == n:
		flashed.emit([h.cell] as Array[Vector2i], EVADE_COLOR, "EVADE")
		_log("%s evades the %s" % [h.display_name, d.display_name])
		return "EVADE"
	if _guards(h, d, n):
		flashed.emit([h.cell] as Array[Vector2i], BLOCK_COLOR, "BLOCK")
		_log("%s blocks the %s" % [h.display_name, d.display_name])
		return "BLOCK"
	var dmg: float = STRIKE_DAMAGE * (EXPOSED_MULTIPLIER if h.is_exposed() else 1.0)
	var lost: int = h.take_damage(roundi(dmg))
	flashed.emit([h.cell] as Array[Vector2i], STRIKE_COLOR, "HIT %d" % lost)
	_log("The %s hits %s for %d%s" % [d.display_name, h.display_name, lost, " (exposed!)" if h.is_exposed() else ""])
	return "HIT"


func _log(text: String) -> void:
	logged.emit(text)
