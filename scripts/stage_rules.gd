class_name StageRules
extends RefCounted
## Rules for a scrolling stage: heroes' rune actions against enemies and
## hazards on a 3-lane grid of zones. Pure logic on beat indices.
##
## The camera shows VIEW_COLS columns and only scrolls right, following the
## lead hero while keeping every living hero on screen. It stops at the next
## uncleared encounter (the lock) until that area's enemies are dead. Once
## every encounter is cleared, the exit door opens; the stage is won when
## every living hero stands on it. A stage with no door (a boss arena) is won
## as soon as every encounter is cleared.
##
## Hero actions resolve as they complete. Enemies and hazards resolve when a
## beat closes (at the dum), so a brace or dodge entered on the hit beat
## counts. Enemies only act while on screen. act() closes earlier beats
## first, so ordering holds even if an input arrives in the same frame as
## the previous beat's close.

signal logged(text: String)
signal ended(won: bool)
signal door_opened
## A hero fell. Their final strike is input on `final_beat`.
signal hero_fell(player: int, final_beat: int)
## A fallen hero's final strike resolved.
signal final_struck(player: int)

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
## Glory for breaking a boss part.
const PART_GLORY: int = 10

## A fallen hero's beat is silent this many beats, then they strike once.
const SILENT_BEATS: int = 2
## Final strikes by Rune.Dir: up Throw, down Strike, left Flurry, right Charge.
const FINAL_NAMES: Array[String] = ["Throw", "Strike", "Flurry", "Charge"]
const THROW_DAMAGE: int = 30
const CHARGE_DAMAGE: int = 20
const FLURRY_DAMAGE: int = 10
const FLURRY_BARE_BONUS: int = 15
const STRIKE_DAMAGE: int = 25
const STRIKE_PER_BREAK: int = 25
## Extra glory for slaying a foe with a final strike.
const FINAL_KILL_GLORY: int = 25

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
		"J":
			return BossEnemy.jotunn(cell)
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
		if e.is_alive() and e.occupies(cell):
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
			if action.glory > 0:
				hero.glory += action.glory
	# Attacks log themselves, so their result reads before any break or kill.
	if text != "" and action.kind != RuneAction.Kind.ATTACK:
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
		var miss: String = "%s: %s hits nothing" % [hero.display_name, attack_name]
		logged.emit(miss)
		return miss
	var dealt: int = foe.take_hit(hero.cell, attack_damage(action.attack, action.perfect, action.empowered))
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
	logged.emit(text)
	_after_hit(foe, hero)
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
	for hero: Hero in heroes:
		if hero.final_beat == beat:
			logged.emit("%s gave no command: Strike!" % hero.display_name)
			_final(hero, Rune.Dir.DOWN, false, false)
			if over:
				return
	for fire: FireTrap in fires:
		if fire.is_on(beat):
			for hero: Hero in living_heroes():
				if hero.cell in fire.cells:
					_burn(hero, beat)
	if _check_heroes_dead():
		return
	_bleed()
	if over:
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
		_fall(hero, beat)


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
		_check_enemy_dead(enemy, hero)
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
		_fall(hero, beat)


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


## Credits boss part breaks and a kill to `hero` after it hit `foe`.
func _after_hit(foe: Enemy, hero: Hero, final: bool = false) -> void:
	if foe is BossEnemy:
		for part: BossPart in (foe as BossEnemy).pop_broken():
			hero.glory += PART_GLORY
			logged.emit("%s breaks the %s's %s! +%d glory. It bleeds." % [hero.display_name, foe.display_name, part.display_name, PART_GLORY])
	_check_enemy_dead(foe, hero, final)


## Bosses lose HP for each wound. Bleeding out earns no one the kill.
func _bleed() -> void:
	for e: Enemy in enemies:
		if e is BossEnemy and e.is_alive() and e.bleed() > 0 and not e.is_alive():
			logged.emit("The %s bleeds out. No glory in that!" % e.display_name)
			_check_enemy_dead(e)


## `killer` (if any) earns the enemy's glory, plus a bonus for a kill with
## their final strike.
func _check_enemy_dead(enemy: Enemy, killer: Hero = null, final: bool = false) -> void:
	if over or enemy.is_alive():
		return
	if killer != null:
		var earned: int = enemy.glory_value + (FINAL_KILL_GLORY if final else 0)
		killer.glory += earned
		var how: String = " with a dying breath" if final else ""
		logged.emit("%s is slain by %s%s! +%d glory" % [enemy.display_name, killer.display_name, how, earned])
	else:
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
		if announce and map.door == StageMap.NO_CELL:
			logged.emit("Victory!")
			_end(true)
			return
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


## Ends the stage as lost once no hero lives and no final strike is pending.
func _check_heroes_dead() -> bool:
	if over:
		return true
	if not living_heroes().is_empty():
		return false
	for h: Hero in heroes:
		if h.has_final_strike():
			return false
	_end(false)
	return true


# --- Final strike ---------------------------------------------------------------

func _fall(hero: Hero, beat: int) -> void:
	hero.final_beat = beat + SILENT_BEATS + 1
	logged.emit("%s falls! A final strike in %d beats..." % [hero.display_name, SILENT_BEATS + 1])
	hero_fell.emit(hero.player, hero.final_beat)


## A fallen hero's final strike, input on their final beat. Returns a
## description, or "" if it isn't their final beat.
func final_strike(player: int, dir: Rune.Dir, beat: int, perfect: bool, blessed: bool) -> String:
	close_beat(beat - 1)
	if over or player >= heroes.size() or heroes[player].final_beat != beat:
		return ""
	return _final(heroes[player], dir, perfect, blessed)


## Zones a final strike would hit, as [cell, damage, zone_bonus] entries.
## Damage includes the Perfect and blessed bonuses but not the bare-zone
## bonus, which the target applies (see final_preview()).
func final_hits(hero: Hero, dir: Rune.Dir, perfect: bool = false, blessed: bool = false) -> Array:
	var hits: Array = []
	match dir:
		Rune.Dir.UP:
			var target: Vector2i = _throw_target(hero)
			if target != StageMap.NO_CELL:
				hits.append([target, THROW_DAMAGE, true])
		Rune.Dir.RIGHT:
			for col: int in range(hero.cell.x + 1, camera_col + VIEW_COLS):
				var c := Vector2i(col, hero.cell.y)
				if enemy_at(c) != null:
					hits.append([c, CHARGE_DAMAGE, true])
		Rune.Dir.LEFT:
			for lane: int in StageMap.LANES:
				var c := Vector2i(hero.cell.x + 1, lane)
				var foe: Enemy = enemy_at(c)
				if foe != null:
					hits.append([c, FLURRY_DAMAGE + (FLURRY_BARE_BONUS if foe.is_unarmored(c) else 0), false])
		Rune.Dir.DOWN:
			var foe: Enemy = enemy_at(hero.cell)
			if foe != null:
				hits.append([hero.cell, STRIKE_DAMAGE + STRIKE_PER_BREAK * foe.broken_parts(), false])
	var mult: float = 1.0 + (0.5 if perfect else 0.0) + (0.5 if blessed else 0.0)
	for h: Array in hits:
		h[1] = roundi(h[1] * mult)
	return hits


## Expected total damage of each final strike, indexed by Rune.Dir.
func final_preview(hero: Hero) -> Array[int]:
	var out: Array[int] = []
	for d: Rune.Dir in Rune.ALL:
		var total: int = 0
		for h: Array in final_hits(hero, d):
			var foe: Enemy = enemy_at(h[0])
			var bare: bool = h[2] and foe.is_unarmored(h[0])
			total += roundi(h[1] * BossEnemy.UNARMORED_BONUS) if bare else int(h[1])
		out.append(total)
	return out


## Throw hits the top lane of the nearest boss column (the hero's own column
## if they stand in the boss). With no boss on screen, it hits the nearest foe.
func _throw_target(hero: Hero) -> Vector2i:
	var best := StageMap.NO_CELL
	var best_d: int = 1 << 30
	for e: Enemy in enemies:
		if e is BossEnemy and e.is_alive() and is_on_screen(e.cell.x):
			for c: Vector2i in (e as BossEnemy).footprint:
				var d: int = absi(c.x - hero.cell.x)
				if c.y == e.cell.y and d < best_d:
					best = c
					best_d = d
	if best != StageMap.NO_CELL:
		return best
	for e: Enemy in enemies:
		if e.is_alive() and is_on_screen(e.cell.x):
			var d: int = _distance(e.cell, hero.cell)
			if d < best_d:
				best = e.cell
				best_d = d
	return best


func _final(hero: Hero, dir: Rune.Dir, perfect: bool, blessed: bool) -> String:
	hero.final_beat = Hero.NONE
	var hits: Array = final_hits(hero, dir, perfect, blessed)
	var total: int = 0
	var struck: Array[Enemy] = []
	for h: Array in hits:
		var foe: Enemy = enemy_at(h[0])
		if foe == null:
			continue
		total += foe.take_hit(h[0], h[1], h[2])
		if not struck.has(foe):
			struck.append(foe)
	if dir == Rune.Dir.RIGHT:
		hero.cell.x = camera_col + VIEW_COLS - 1
	var text: String = "%s's final %s deals %d!" % [hero.display_name, FINAL_NAMES[dir], total]
	if perfect:
		text += " PERFECT"
	logged.emit(text)
	for foe: Enemy in struck:
		_after_hit(foe, hero, true)
	final_struck.emit(hero.player)
	_check_heroes_dead()
	return text


func _end(p_won: bool) -> void:
	over = true
	won = p_won
	ended.emit(p_won)
