class_name FightRules
extends RefCounted
## Rules for a fight on a strip of rooms: heroes' rune actions against one
## enemy's telegraphed moves. Pure logic on beat indices, no nodes or time.
##
## Hero actions resolve as they complete. Enemy moves resolve when a beat
## closes (at the dum), so a brace or dodge entered on the hit beat counts.
## act() closes any earlier beats first, so ordering holds even if an input
## arrives in the same frame as the previous beat's close.

signal logged(text: String)
signal ended(won: bool)

const ROOM_COUNT: int = 3
const HERO_HP: int = 60
const ENEMY_HP: int = 120
const ENEMY_ROOM: int = 1
## Beat the enemy's first wind-up may start on.
const FIRST_ENEMY_BEAT: int = 2
## A brace or warded move covers the beat it completes on and the next one.
const COVER_BEATS: int = 2

const ATTACK_DAMAGE: Array[int] = [4, 10, 20, 6]  # indexed by RuneAction.Attack
const PERFECT_BONUS: float = 0.5
const BLESSED_BONUS: float = 0.5
const EXPOSED_MULTIPLIER: float = 1.5
const GUARDED_MULTIPLIER: float = 0.5
const RETALIATE_DAMAGE: int = 10

var heroes: Array[Hero] = []
var enemy: Enemy
## Last beat whose enemy step has resolved.
var closed_through: int = -1
var over: bool = false
var won: bool = false


func _init(player_count: int = 1, p_enemy: Enemy = null) -> void:
	for p: int in player_count:
		# Solo starts on the left; a second player starts on the right.
		heroes.append(Hero.new(p, HERO_HP, 0 if p == 0 else ROOM_COUNT - 1))
	enemy = p_enemy if p_enemy != null else default_enemy()


static func default_enemy() -> Enemy:
	var claw := EnemyMove.new("Grave Claw", EnemyMove.Target.HERO_ROOM, 3, 12, 2)
	var slam := EnemyMove.new("Barrow Slam", EnemyMove.Target.OWN_ROOM, 3, 18, 2)
	var howl := EnemyMove.new("Death Howl", EnemyMove.Target.ALL_ROOMS, 4, 8, 3)
	var pattern: Array[EnemyMove] = [claw, slam, claw, howl]
	return Enemy.new("Draugr", ENEMY_HP, ENEMY_ROOM, pattern, FIRST_ENEMY_BEAT)


static func attack_damage(attack: RuneAction.Attack, perfect: bool, blessed: bool) -> int:
	var mult: float = 1.0
	if perfect:
		mult += PERFECT_BONUS
	if blessed:
		mult += BLESSED_BONUS
	return roundi(ATTACK_DAMAGE[attack] * mult)


## Applies a completed command for one player. Returns a short description of
## what happened in the fight ("" when the action has no fight effect).
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
			hero.brace_blessed = action.empowered
			text = "%s braces%s" % [hero.display_name, " (retaliating)" if action.empowered else ""]
		RuneAction.Kind.PRAY:
			pass
	if text != "":
		logged.emit(text)
	return text


## Resolves the enemy's step for every beat up to and including `beat`.
func close_beat(beat: int) -> void:
	while closed_through < beat:
		closed_through += 1
		_resolve(closed_through)


func _move(hero: Hero, action: RuneAction) -> String:
	if action.empowered:
		hero.ward_until = action.beat + COVER_BEATS - 1
	var step: int = 0
	match action.dir:
		Rune.Dir.LEFT:
			step = -1
		Rune.Dir.RIGHT:
			step = 1
	var dest: int = clampi(hero.room + step, 0, ROOM_COUNT - 1)
	var ward: String = " (warded)" if action.empowered else ""
	if dest == hero.room:
		return "%s holds position%s" % [hero.display_name, ward]
	hero.room = dest
	return "%s moves to the %s room%s" % [hero.display_name, room_name(dest), ward]


func _attack(hero: Hero, action: RuneAction) -> String:
	var attack_name: String = RuneAction.ATTACK_NAMES[action.attack]
	if action.attack == RuneAction.Attack.HEAVY:
		hero.exposed = true
	if hero.room != enemy.room or not enemy.is_alive():
		return "%s: %s hits nothing" % [hero.display_name, attack_name]
	var dealt: int = enemy.take_damage(attack_damage(action.attack, action.perfect, action.empowered))
	var extra: String = ""
	match action.attack:
		RuneAction.Attack.TRIP:
			enemy.stagger()
			extra = ", staggered"
		RuneAction.Attack.DEFENSIVE:
			hero.guarded = true
			extra = ", guarding"
	var text: String = "%s: %s for %d%s" % [hero.display_name, attack_name, dealt, extra]
	_check_enemy_dead()
	return text


func _resolve(beat: int) -> void:
	if over:
		return
	if enemy.is_winding() and enemy.hit_beat == beat:
		var move: EnemyMove = enemy.current
		for hero: Hero in heroes:
			if hero.is_alive() and hero.room in enemy.targets:
				_hit(hero, move, beat)
				if over:
					return
		enemy.finish(beat)
		if _check_heroes_dead():
			return
	if enemy.try_start(beat, ROOM_COUNT, heroes):
		var rooms: Array[String] = []
		for r: int in enemy.targets:
			rooms.append(room_name(r))
		logged.emit("%s winds up %s (%s)" % [enemy.display_name, enemy.current.display_name, ", ".join(rooms)])


func _hit(hero: Hero, move: EnemyMove, beat: int) -> void:
	if hero.is_warded(beat):
		logged.emit("%s's ward turns aside %s" % [hero.display_name, move.display_name])
		return
	if hero.is_braced(beat):
		var text: String = "%s blocks %s" % [hero.display_name, move.display_name]
		if hero.brace_blessed and enemy.is_alive():
			text += " and strikes back for %d" % enemy.take_damage(RETALIATE_DAMAGE)
		logged.emit(text)
		_check_enemy_dead()
		return
	var mult: float = 1.0
	if hero.exposed:
		mult *= EXPOSED_MULTIPLIER
	if hero.guarded:
		mult *= GUARDED_MULTIPLIER
		hero.guarded = false
	var lost: int = hero.take_damage(roundi(move.damage * mult))
	logged.emit("%s hits %s for %d" % [move.display_name, hero.display_name, lost])
	if not hero.is_alive():
		logged.emit("%s falls" % hero.display_name)


func _check_enemy_dead() -> void:
	if not over and not enemy.is_alive():
		logged.emit("%s is slain!" % enemy.display_name)
		_end(true)


func _check_heroes_dead() -> bool:
	for hero: Hero in heroes:
		if hero.is_alive():
			return false
	_end(false)
	return true


func _end(p_won: bool) -> void:
	over = true
	won = p_won
	ended.emit(p_won)


static func room_name(index: int) -> String:
	return ["left", "center", "right"][index] if index < 3 else "room %d" % index
