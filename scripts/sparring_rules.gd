class_name SparringRules
extends RefCounted
## The Rhythm Lab's training yard for the one-action-per-beat rules. Pure
## logic on beat indices. Heroes and practice dummies stand on a grid of
## LANES by COLS zones, one dummy per zone. Heroes may share a zone with each
## other, but not with a dummy.
##
## - Facing: heroes face left or right. Moving or bracing left/right turns
##   them that way (even when the move is blocked).
## - Standard and Heavy hit the zone in front plus the zones above and below
##   the hero. Trip and Defensive hit only the zone in front.
## - Trip roots the dummy (it can't move this beat or the next) and makes it
##   vulnerable (+50% damage) through the two beats after, so Trip, charge,
##   Heavy lands on a vulnerable target.
## - Heavy charges first (TurnInput). The hero is exposed (+50% damage taken)
##   on every charging beat and the beat it lands.
## - A brace covers only the beat it's made on. It blocks hits from the side
##   it faces. A blessed brace strikes back.
## - Defensive halves the next hit taken.
##
## Hero actions resolve first (act), then the dummies (end_turn), so a brace
## or dodge on the hit beat counts.

signal logged(text: String)
## Zones an attack (or a dummy's strike) hit, for the view to flash.
signal flashed(cells: Array[Vector2i], color: Color, text: String)

const COLS: int = 8
const LANES: int = 3
const NONE: int = -(1 << 62)
const LEFT: int = -1
const RIGHT: int = 1

const STANDARD_DAMAGE: int = 10
const HEAVY_DAMAGE: int = 20
const TRIP_DAMAGE: int = 4
const DEFENSIVE_DAMAGE: int = 6
const RETALIATE_DAMAGE: int = 10
## Perfect, blessed and vulnerable each multiply damage by this.
const BONUS: float = 1.5
const EXPOSED_MULTIPLIER: float = 1.5
## Beats after a Trip the dummy stays rooted (the Trip's own beat counts too).
const ROOT_BEATS: int = 1
## Beats after a Trip the dummy takes extra damage.
const VULNERABLE_BEATS: int = 2

const HERO_HP: int = 100
const DUMMY_HP: int = 40
const RESPAWN_BEATS: int = 4
## The sparring dummy starts a wind-up every SPAR_CYCLE beats and strikes
## SPAR_WINDUP beats later.
const SPAR_CYCLE: int = 4
const SPAR_WINDUP: int = 2
const SPAR_DAMAGE: int = 10

const ATTACK_COLOR := Color(0.92, 0.25, 0.2)
const SPAR_COLOR := Color(1.0, 0.55, 0.15)


class Fighter extends Combatant:
	var player: int
	var facing: int = RIGHT
	## The beat a brace covers, or NONE.
	var brace_beat: int = NONE
	var brace_dir: int = Rune.Dir.RIGHT
	var brace_blessed: bool = false
	## The last beat the hero is exposed on (charging or landing a Heavy).
	var exposed_beat: int = NONE
	var charging: bool = false
	## The next hit taken is halved (Defensive attack).
	var guarded: bool = false

	func _init(p_player: int, p_cell: Vector2i) -> void:
		super("P%d" % (p_player + 1), HERO_HP, p_cell)
		player = p_player

	func is_braced(beat: int) -> bool:
		return brace_beat == beat

	func is_exposed(beat: int) -> bool:
		return exposed_beat == beat


class Dummy extends Combatant:
	enum Kind { POST, WALKER, SPARRER }
	var kind: Kind
	var home: Vector2i
	## WALKER: the way it's walking (LEFT or RIGHT), between min_col and max_col.
	var walk_dir: int = LEFT
	var min_col: int = 0
	var max_col: int = COLS - 1
	var rooted_until: int = NONE
	var vulnerable_until: int = NONE
	var died_on: int = NONE
	## SPARRER: the beat its strike lands, or NONE, and the zones it hits.
	var strike_beat: int = NONE
	var targets: Array[Vector2i] = []

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
## The last beat end_turn ran for.
var beat: int = NONE


func _init(player_count: int = 1) -> void:
	for p: int in player_count:
		heroes.append(Fighter.new(p, Vector2i(1, 1 + p)))
	dummies.append(Dummy.new("Post", Dummy.Kind.POST, Vector2i(3, 1)))
	var walker := Dummy.new("Walker", Dummy.Kind.WALKER, Vector2i(5, 0))
	walker.min_col = 2
	walker.max_col = 6
	dummies.append(walker)
	dummies.append(Dummy.new("Sparrer", Dummy.Kind.SPARRER, Vector2i(6, 2)))


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


## The zones an attack from `hero` hits.
static func attack_cells(hero: Fighter, attack: RuneAction.Attack) -> Array[Vector2i]:
	var out: Array[Vector2i] = [hero.cell + Vector2i(hero.facing, 0)]
	if attack == RuneAction.Attack.STANDARD or attack == RuneAction.Attack.HEAVY:
		out.append(hero.cell + Vector2i(0, -1))
		out.append(hero.cell + Vector2i(0, 1))
	var inside: Array[Vector2i] = []
	inside.assign(out.filter(func(c: Vector2i) -> bool: return in_bounds(c)))
	return inside


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
func act(player: int, a: RuneAction) -> void:
	if player >= heroes.size() or a == null:
		return
	var h: Fighter = heroes[player]
	h.charging = a.kind == RuneAction.Kind.CHARGE
	match a.kind:
		RuneAction.Kind.MOVE:
			_move(h, a)
		RuneAction.Kind.BRACE:
			h.brace_beat = a.beat
			h.brace_dir = a.dir
			h.brace_blessed = a.empowered
			if a.dir == Rune.Dir.LEFT or a.dir == Rune.Dir.RIGHT:
				h.facing = LEFT if a.dir == Rune.Dir.LEFT else RIGHT
			_log("%s braces %s" % [h.display_name, Rune.DIR_NAMES[a.dir]])
		RuneAction.Kind.ATTACK:
			_attack(h, a)
		RuneAction.Kind.CHARGE:
			h.exposed_beat = a.beat
			_log("%s charges a Heavy (exposed)" % h.display_name)
		RuneAction.Kind.PRAY:
			_log("%s: %s" % [h.display_name, a.describe()])


func _move(h: Fighter, a: RuneAction) -> void:
	if a.dir == Rune.Dir.LEFT:
		h.facing = LEFT
	elif a.dir == Rune.Dir.RIGHT:
		h.facing = RIGHT
	var to: Vector2i = h.cell + dir_offset(a.dir)
	if not in_bounds(to) or dummy_at(to) != null:
		_log("%s can't move %s" % [h.display_name, Rune.DIR_NAMES[a.dir]])
		return
	h.cell = to


func _attack(h: Fighter, a: RuneAction) -> void:
	var cells: Array[Vector2i] = attack_cells(h, a.attack)
	var base: int = STANDARD_DAMAGE
	match a.attack:
		RuneAction.Attack.HEAVY:
			base = HEAVY_DAMAGE
			h.exposed_beat = a.beat
		RuneAction.Attack.TRIP:
			base = TRIP_DAMAGE
		RuneAction.Attack.DEFENSIVE:
			base = DEFENSIVE_DAMAGE
			h.guarded = true
	var parts: Array[String] = []
	for cell: Vector2i in cells:
		var d: Dummy = dummy_at(cell)
		if d == null:
			continue
		var mult: float = 1.0
		if a.perfect:
			mult *= BONUS
		if a.empowered:
			mult *= BONUS
		if d.is_vulnerable(a.beat):
			mult *= BONUS
		var dealt: int = d.take_damage(roundi(base * mult))
		var note: String = "%s %d" % [d.display_name, dealt]
		if a.attack == RuneAction.Attack.TRIP:
			d.rooted_until = a.beat + ROOT_BEATS
			d.vulnerable_until = a.beat + VULNERABLE_BEATS
			note += " (rooted, vulnerable)"
		if not d.is_alive():
			d.died_on = a.beat
			note += " (down!)"
		parts.append(note)
	flashed.emit(cells, ATTACK_COLOR, RuneAction.ATTACK_NAMES[a.attack])
	var text: String = "%s: %s" % [h.display_name, a.describe()]
	_log(text + (" -> " + ", ".join(parts) if not parts.is_empty() else " -> nothing there"))


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
			Dummy.Kind.SPARRER:
				_spar(d, n)
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


func _spar(d: Dummy, n: int) -> void:
	if d.strike_beat == n:
		d.strike_beat = NONE
		flashed.emit(d.targets, SPAR_COLOR, "Swing")
		for h: Fighter in heroes:
			if h.cell in d.targets:
				_hit_hero(h, d, n)
		return
	if d.strike_beat == NONE and posmod(n, SPAR_CYCLE) == 0:
		d.strike_beat = n + SPAR_WINDUP
		d.targets.clear()
		for side: int in [LEFT, RIGHT]:
			var c: Vector2i = d.cell + Vector2i(side, 0)
			if in_bounds(c):
				d.targets.append(c)


func _hit_hero(h: Fighter, d: Dummy, n: int) -> void:
	var from_dir: int = Rune.Dir.RIGHT if d.cell.x > h.cell.x else Rune.Dir.LEFT
	if h.is_braced(n) and h.brace_dir == from_dir:
		var text: String = "%s blocks the Sparrer" % h.display_name
		if h.brace_blessed:
			var dealt: int = d.take_damage(RETALIATE_DAMAGE)
			text += " and strikes back for %d" % dealt
			if not d.is_alive():
				d.died_on = n
		_log(text)
		return
	var dmg: float = SPAR_DAMAGE
	if h.is_exposed(n):
		dmg *= EXPOSED_MULTIPLIER
	if h.guarded:
		dmg *= 0.5
		h.guarded = false
	var lost: int = h.take_damage(roundi(dmg))
	_log("The Sparrer hits %s for %d%s" % [h.display_name, lost, " (exposed!)" if h.is_exposed(n) else ""])


func _log(text: String) -> void:
	logged.emit(text)
