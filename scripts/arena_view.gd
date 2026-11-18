class_name ArenaView
extends Control
## Draws a FightRules state: the room strip, the enemy and its telegraphed
## targets with a countdown, and each hero with health and status tags.
## Placeholder shapes until real sprites exist.

const ROOM_GAP: float = 12.0
const ROOM_COLOR := Color(0.75, 0.7, 0.6, 0.6)
const ROOM_FILL := Color(1, 1, 1, 0.03)
const TARGET_FILL := Color(0.9, 0.15, 0.1, 0.18)
const TARGET_HOT := Color(1.0, 0.2, 0.1, 0.45)
const ENEMY_COLOR := Color(0.45, 0.55, 0.5)
const HERO_COLORS: Array[Color] = [Color(0.45, 0.7, 1.0), Color(1.0, 0.65, 0.3)]
const DEAD_COLOR := Color(0.35, 0.35, 0.35)
const HP_BACK := Color(0.15, 0.05, 0.05)
const HP_FRONT := Color(0.85, 0.2, 0.2)
const TEXT_COLOR := Color(0.92, 0.9, 0.85)

var rules: FightRules


func room_rect(index: int) -> Rect2:
	var count: int = FightRules.ROOM_COUNT
	var w: float = (size.x - ROOM_GAP * (count - 1)) / count
	return Rect2(index * (w + ROOM_GAP), 0.0, w, size.y)


## Status tags under a hero, as of the last closed beat's next beat.
static func hero_tags(hero: Hero, beat: int) -> String:
	if not hero.is_alive():
		return "FALLEN"
	var tags: Array[String] = []
	if hero.is_warded(beat):
		tags.append("WARD")
	if hero.is_braced(beat):
		tags.append("BRACE+" if hero.brace_blessed else "BRACE")
	if hero.exposed:
		tags.append("EXPOSED")
	if hero.guarded:
		tags.append("GUARD")
	return " ".join(tags)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if rules == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var font: Font = get_theme_default_font()
	var next_beat: int = rules.closed_through + 1
	var enemy: Enemy = rules.enemy
	var countdown: int = enemy.countdown(rules.closed_through)

	for i: int in FightRules.ROOM_COUNT:
		var r: Rect2 = room_rect(i)
		draw_rect(r, ROOM_FILL)
		if enemy.is_winding() and i in enemy.targets:
			draw_rect(r, TARGET_HOT if countdown <= 1 else TARGET_FILL)
			_text(font, str(countdown), Vector2(r.position.x + 10.0, r.position.y + 40.0), 36, TARGET_HOT.lightened(0.5))
		draw_rect(r, ROOM_COLOR, false, 2.0)
		_text_centered(font, FightRules.room_name(i).to_upper(), r, r.position.y + r.size.y - 8.0, 12, ROOM_COLOR)

	if enemy.is_alive():
		var er: Rect2 = room_rect(enemy.room)
		var body := Rect2(er.position + Vector2(er.size.x * 0.3, er.size.y * 0.12), Vector2(er.size.x * 0.4, er.size.y * 0.42))
		draw_rect(body, ENEMY_COLOR)
		_hp_bar(Rect2(body.position.x, body.position.y - 12.0, body.size.x, 6.0), enemy)
		var label: String = enemy.display_name
		if enemy.is_winding():
			label += ": " + enemy.current.display_name
		_text_centered(font, label, er, body.position.y + body.size.y + 16.0, 14, TEXT_COLOR)

	for hero: Hero in rules.heroes:
		var hr: Rect2 = room_rect(hero.room)
		var slot: float = 0.3 if hero.player == 0 else 0.7
		var foot := Vector2(hr.position.x + hr.size.x * slot, hr.position.y + hr.size.y * 0.86)
		var col: Color = HERO_COLORS[hero.player % HERO_COLORS.size()] if hero.is_alive() else DEAD_COLOR
		draw_circle(foot - Vector2(0, 34), 7.0, col)
		draw_rect(Rect2(foot - Vector2(8, 26), Vector2(16, 26)), col)
		_hp_bar(Rect2(foot.x - 22.0, foot.y - 52.0, 44.0, 5.0), hero)
		_text(font, "P%d" % (hero.player + 1), foot + Vector2(-8, -56), 12, col)
		_text(font, hero_tags(hero, next_beat), foot + Vector2(-24, 14), 11, TEXT_COLOR)


func _hp_bar(r: Rect2, who: Combatant) -> void:
	draw_rect(r, HP_BACK)
	draw_rect(Rect2(r.position, Vector2(r.size.x * who.hp / float(who.max_hp), r.size.y)), HP_FRONT)


func _text(font: Font, text: String, pos: Vector2, font_size: int, col: Color) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _text_centered(font: Font, text: String, r: Rect2, y: float, font_size: int, col: Color) -> void:
	draw_string(font, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, font_size, col)
