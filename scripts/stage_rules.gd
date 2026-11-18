class_name StageRules
extends RefCounted
## Rules for a scrolling stage: heroes' rune actions against enemies and
## hazards on a 3-lane grid of zones. Pure logic on beat indices.
##
## The camera shows VIEW_COLS columns and only scrolls right, following the
## lead hero while keeping every living hero on screen. It stops at the next
## uncleared encounter (the lock) until that area's enemies are dead. Once
## every encounter is cleared, the exit door opens; the stage is won when
## every living hero stands on it.
##
## Hero actions resolve as they complete. Enemies and hazards resolve when a
## beat closes (at the dum), so a brace or dodge entered on the hit beat
## counts. Enemies only act while on screen. act() closes earlier beats
## first, so ordering holds even if an input arrives in the same frame as
## the previous beat's close.

signal logged(text: String)
signal ended(won: bool)
signal door_opened

const VIEW_COLS: int = 4
## The camera scrolls once the lead hero passes this many columns into view.
const LEAD_COLS: int = 2
const HERO_HP: int = 60
## A brace or warded move covers the beat it completes on and the next one.
const COVER_BEATS: int = 2

const ATTACK_DAMAGE: Array[int] = [4, 10, 20, 6]  # indexed by RuneAction.Attack
const PERFECT_BONUS: float = 0.5
const BLESSED_BONUS: float = 0.5
const EXPOSED_MULTIPLIER: float = 1.5
const GUARDED_MULTIPLIER: float = 0.5
const RETALIATE_DAMAGE: int = 10

const STEPS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]  # by Rune.Dir

var map: StageMap
var heroes: Array[Hero] = []
var enemies: Array[Enemy] = []
var fires: Array[FireTrap] = []
## Leftmost visible column.
var camera_col: int = 0
## Per encounter: its enemies are all dead.
var cleared: Array[bool] = []
var door_open: bool = false
## Last beat whose enemy and hazard step has resolved.
var closed_through: int = -1
var over: bool = false
var won: bool = false

var _announced_lock: int = -1


func _init(p_map: StageMap, player_count: int = 1, p_enemies: Array[Enemy] = []) -> void:
	map = p_map
	for p: int in player_count:
		heroes.append(Hero.new(p, HERO_HP, map.hero_starts[p]))
	for col: int in map.fire_columns:
		fires.append(FireTrap.new(map.fire_columns[col]))
	if p_enemies.is_empty():
		for s: StageMap.Spawn in map.spawns:
			var e: Enemy = spawn(s.kind, s.cell)
			e.encounter = s.encounter
			enemies.append(e)
	else:
		enemies = p_enemies
	cleared.resize(map.encounters.size())
	cleared.fill(false)
	_update_clears(false)


static func spawn(kind: String, cell: Vector2i) -> Enemy:
	match kind:
		"R":
			return RangerEnemy.new(cell)
		_:
			return BruteEnemy.new(cell)


static func attack_damage(attack: RuneAction.Attack, perfect: bool, blessed: bool) -> int:
	var mult: float = 1.0
	if perfect:
		mult += PERFECT_BONUS
	if blessed:
		mult += BLESSED_BONUS
	return roundi(ATTACK_DAMAGE[attack] * mult)


# --- Queries used by enemies and the view ---------------------------------

func living_heroes() -> Array[Hero]:
	return heroes.filter(func(h: Hero) -> bool: return h.is_alive())


func is_on_screen(col: int) -> bool:
	return col >= camera_col and col < camera_col + VIEW_COLS


func visible_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for col: int in range(camera_col, mini(camera_col + VIEW_COLS, map.width)):
		for lane: int in StageMap.LANES:
			out.append(Vector2i(col, lane))
	return out


func enemy_at(cell: Vector2i) -> Enemy:
	for e: Enemy in enemies:
		if e.is_alive() and e.cell == cell:
			return e
	return null


## Open, on screen, and not already holding an enemy (one foe per zone).
func enemy_can_enter(cell: Vector2i) -> bool:
	return map.is_open(cell) and is_on_screen(cell.x) and enemy_at(cell) == null


## Nearest living hero by steps, or by lanes only when `by_lane`.
## Ties go to the lower player number.
func nearest_hero(from: Vector2i, by_lane: bool = false) -> Hero:
	var best: Hero = null
	var best_d: int = 1 << 30
	for h: Hero in living_heroes():
		var d: int = absi(h.cell.y - from.y)
		if not by_lane:
			d += absi(h.cell.x - from.x)
		if d < best_d:
			best = h
			best_d = d
	return best


## A living hero stands in the enemy's lane, on screen, to its left.
func hero_in_line_left(enemy: Enemy) -> bool:
	for h: Hero in living_heroes():
		if h.cell.y == enemy.cell.y and h.cell.x < enemy.cell.x and is_on_screen(h.cell.x):
			return true
	return false


## Index of the first uncleared encounter, or -1.
func next_encounter() -> int:
	for i: int in cleared.size():
		if not cleared[i]:
			return i
	return -1


## Furthest the camera may scroll right now.
func camera_limit() -> int:
	var limit: int = maxi(0, map.width - VIEW_COLS)
	var i: int = next_encounter()
	if i >= 0:
		limit = mini(limit, maxi(0, map.encounters[i].end - VIEW_COLS))
	return limit


## The camera is stopped at an uncleared encounter.
func is_locked() -> bool:
	return next_encounter() >= 0 and camera_col >= camera_limit()


## The camera can scroll further right (the "GO" prompt).
func can_advance() -> bool:
	return camera_col < camera_limit()


# --- Hero actions -----------------------------------------------------------

## Applies a completed command for one player. Returns a short description of
## what happened ("" when the action has no stage effect).
func act(player: int, action: RuneAction) -> String:
	close_beat(action.beat - 1)
	if over or player >= heroes.size():
		return ""
	var hero: Hero = heroes[player]
	if not hero.is_alive():
		return ""
	hero.exposed = false
	var text: String = ""
	match action.kind:
		RuneAction.Kind.MOVE:
			text = _move(hero, action)
		RuneAction.Kind.ATTACK:
			text = _attack(hero, action)
		RuneAction.Kind.BRACE:
			hero.brace_until = action.beat + COVER_BEATS - 1
			hero.brace_dir = action.dir
			hero.brace_blessed = action.empowered
			text = "%s braces %s%s" % [hero.display_name, Rune.DIR_NAMES[action.dir], " (retaliating)" if action.empowered else ""]
		RuneAction.Kind.PRAY:
			pass
	if text != "":
		logged.emit(text)
	if action.kind == RuneAction.Kind.MOVE:
		_check_exit()
	return text


func _move(hero: Hero, action: RuneAction) -> String:
	if action.empowered:
		hero.ward_until = action.beat + COVER_BEATS - 1
	var ward: String = " (warded)" if action.empowered else ""
	var dest: Vector2i = hero.cell + STEPS[action.dir]
	if not map.is_open(dest) or not is_on_screen(dest.x):
		return "%s holds position%s" % [hero.display_name, ward]
	hero.cell = dest
	_update_camera()
	return "%s moves %s%s" % [hero.display_name, Rune.DIR_NAMES[action.dir], ward]


func _attack(hero: Hero, action: RuneAction) -> String:
	var attack_name: String = RuneAction.ATTACK_NAMES[action.attack]
	if action.attack == RuneAction.Attack.HEAVY:
		hero.exposed = true
	var foe: Enemy = enemy_at(hero.cell)
	if foe == null:
		return "%s: %s hits nothing" % [hero.display_name, attack_name]
	var dealt: int = foe.take_damage(attack_damage(action.attack, action.perfect, action.empowered))
	var extra: String = ""
	match action.attack:
		RuneAction.Attack.TRIP:
			var was_off_beat: bool = foe.is_off_beat()
			foe.stagger()
			extra = ", staggered"
			if was_off_beat and not foe.is_off_beat():
				extra += " back onto the beat"
		RuneAction.Attack.DEFENSIVE:
			hero.guarded = true
			extra = ", guarding"
	var text: String = "%s: %s on %s for %d%s" % [hero.display_name, attack_name, foe.display_name, dealt, extra]
	_check_enemy_dead(foe)
	return text


# --- Beat resolution --------------------------------------------------------

## Resolves enemies and hazards for every beat up to and including `beat`.
func close_beat(beat: int) -> void:
	while closed_through < beat:
		closed_through += 1
		_resolve(closed_through)


func _resolve(beat: int) -> void:
	if over:
		return
	for fire: FireTrap in fires:
		if fire.is_on(beat):
			for hero: Hero in living_heroes():
				if hero.cell in fire.cells:
					_burn(hero, beat)
	if _check_heroes_dead():
		return
	var active: Array[Enemy] = enemies.filter(func(e: Enemy) -> bool: return e.is_alive() and is_on_screen(e.cell.x))
	for e: Enemy in active:
		if e.is_winding() and e.hit_beat == beat:
			_land(e, beat)
			if over:
				return
	if _check_heroes_dead():
		return
	for e: Enemy in active:
		if e.is_alive() and e.try_act(beat, self) and e.is_winding():
			var text: String = "%s winds up %s" % [e.display_name, e.current.display_name]
			if e.current.is_super:
				text = "SUPER! " + text
			if e.is_off_beat():
				text += ", off the beat. Trip it!"
			logged.emit(text)


func _burn(hero: Hero, beat: int) -> void:
	if hero.is_warded(beat):
		logged.emit("%s's ward holds back the fire" % hero.display_name)
		return
	logged.emit("Fire burns %s for %d" % [hero.display_name, hero.take_damage(FireTrap.DAMAGE)])
	if not hero.is_alive():
		logged.emit("%s falls" % hero.display_name)


func _land(enemy: Enemy, beat: int) -> void:
	var move: EnemyMove = enemy.current
	var struck: Array[Hero] = living_heroes().filter(func(h: Hero) -> bool: return h.cell in enemy.targets)
	if move.hits_first and struck.size() > 1:
		struck.sort_custom(func(a: Hero, b: Hero) -> bool:
			return _distance(a.cell, enemy.cell) < _distance(b.cell, enemy.cell))
		struck = [struck[0]]
	for hero: Hero in struck:
		_hit(hero, enemy, move, beat)
		if over:
			return
	enemy.finish(beat)


func _hit(hero: Hero, enemy: Enemy, move: EnemyMove, beat: int) -> void:
	if hero.is_warded(beat):
		logged.emit("%s's ward turns aside %s" % [hero.display_name, move.display_name])
		return
	if hero.blocks(beat, move.from_dir):
		var text: String = "%s blocks %s" % [hero.display_name, move.display_name]
		if hero.brace_blessed and enemy.is_alive():
			text += " and strikes back for %d" % enemy.take_damage(RETALIATE_DAMAGE)
		logged.emit(text)
		_check_enemy_dead(enemy)
		return
	var mult: float = 1.0
	if hero.exposed:
		mult *= EXPOSED_MULTIPLIER
	if hero.guarded:
		mult *= GUARDED_MULTIPLIER
		hero.guarded = false
	var lost: int = hero.take_damage(roundi(move.damage * mult))
	var note: String = ""
	if hero.is_braced(beat):
		note = " (braced the wrong way)"
	logged.emit("%s's %s hits %s for %d%s" % [enemy.display_name, move.display_name, hero.display_name, lost, note])
	if not hero.is_alive():
		logged.emit("%s falls" % hero.display_name)


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


# --- Camera, encounters and the exit -----------------------------------------

func _update_camera() -> void:
	var living: Array[Hero] = living_heroes()
	if living.is_empty():
		return
	var lead: int = 0
	var rear: int = map.width
	for h: Hero in living:
		lead = maxi(lead, h.cell.x)
		rear = mini(rear, h.cell.x)
	var target: int = mini(mini(lead - LEAD_COLS, rear), camera_limit())
	camera_col = maxi(camera_col, target)
	var i: int = next_encounter()
	if i >= 0 and is_locked() and _announced_lock != i:
		_announced_lock = i
		logged.emit("Foes bar the way! Clear the area.")


func _check_enemy_dead(enemy: Enemy) -> void:
	if over or enemy.is_alive():
		return
	logged.emit("%s is slain!" % enemy.display_name)
	_update_clears()


## Marks encounters whose enemies are all dead, and opens the door once
## none remain. `announce` is false while setting up the stage.
func _update_clears(announce: bool = true) -> void:
	for i: int in cleared.size():
		if cleared[i]:
			continue
		var remaining: Array[Enemy] = enemies.filter(func(e: Enemy) -> bool: return e.encounter == i and e.is_alive())
		if remaining.is_empty():
			cleared[i] = true
			if announce and next_encounter() >= 0:
				logged.emit("Area clear! Onward!")
	_update_camera()
	if not door_open and next_encounter() < 0:
		door_open = true
		if announce:
			logged.emit("Area clear! The exit door opens!")
			door_opened.emit()
		_check_exit()


func _check_exit() -> void:
	if over or not door_open or map.door == StageMap.NO_CELL:
		return
	var living: Array[Hero] = living_heroes()
	if living.is_empty():
		return
	for h: Hero in living:
		if h.cell != map.door:
			return
	logged.emit("Through the door!")
	_end(true)


func _check_heroes_dead() -> bool:
	if over:
		return true
	if living_heroes().is_empty():
		_end(false)
		return true
	return false


func _end(p_won: bool) -> void:
	over = true
	won = p_won
	ended.emit(p_won)
