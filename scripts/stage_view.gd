class_name StageView
extends Control
## Draws a StageRules state: the visible window of zones (VIEW_COLS by 3
## lanes), scrolling smoothly toward the logic camera. Shows walls, fire
## traps and their countdown, the exit door, telegraphed enemy targets with
## countdowns, enemies, a boss's parts and wounds, heroes (and fallen
## heroes awaiting their final strike), and the lock / GO prompts.
## A hero glows with their pending rune's color from the first beat of a
## command until the second, and glows white once fallen.
## Placeholder shapes until real sprites exist.

const SCROLL_SPEED: float = 6.0
const GAP: float = 4.0
const ZONE_COLOR := Color(0.75, 0.7, 0.6, 0.45)
const ZONE_FILL := Color(1, 1, 1, 0.03)
const WALL_FILL := Color(0.22, 0.2, 0.2)
const FIRE_IDLE := Color(1.0, 0.45, 0.1, 0.12)
const FIRE_WARN := Color(1.0, 0.5, 0.1, 0.3)
const FIRE_ON := Color(1.0, 0.4, 0.05, 0.7)
const DOOR_COLOR := Color(0.45, 0.3, 0.15)
const DOOR_OPEN := Color(1.0, 0.85, 0.3)
const TARGET_FILL := Color(0.9, 0.15, 0.1, 0.2)
const TARGET_HOT := Color(1.0, 0.2, 0.1, 0.45)
const SUPER_COLOR := Color(0.75, 0.35, 0.95)
const SUPER_FILL := Color(0.6, 0.2, 0.9, 0.25)
const BRUTE_COLOR := Color(0.45, 0.55, 0.5)
const RANGER_COLOR := Color(0.55, 0.5, 0.35)
const PATTERN_COLOR := Color(0.4, 0.5, 0.45)
const VARG_COLOR := Color(0.55, 0.55, 0.6)
const THRALL_COLOR := Color(0.5, 0.42, 0.35)
const SHIELD_COLOR := Color(0.75, 0.6, 0.3)
const BOSS_BODY := Color(0.35, 0.5, 0.6, 0.55)
const BOSS_PLATE := Color(0.6, 0.72, 0.8, 0.85)
const BOSS_WOUND := Color(0.6, 0.05, 0.08, 0.85)
const FINAL_COLOR := Color(1, 1, 1)
## Seconds a rune aura takes to fade back to neutral once its command ends.
const AURA_FADE: float = 0.3
const DEATH_AURA := Color(1, 1, 1)
const HERO_COLORS: Array[Color] = [Color(0.45, 0.7, 1.0), Color(1.0, 0.65, 0.3)]
const DEAD_COLOR := Color(0.35, 0.35, 0.35)
const HP_BACK := Color(0.15, 0.05, 0.05)
const HP_FRONT := Color(0.85, 0.2, 0.2)
const TEXT_COLOR := Color(0.92, 0.9, 0.85)
const LOCK_COLOR := Color(0.9, 0.2, 0.15, 0.8)
const GO_COLOR := Color(1.0, 0.85, 0.3)

var rules: StageRules:
	set(value):
		rules = value
		if rules != null:
			display_col = rules.camera_col
## Camera position as drawn (eases toward rules.camera_col).
var display_col: float = 0.0

var _time: float = 0.0
## Per player: Rune.Dir of the pending rune lighting the hero, or NO_RUNE.
var auras: Array[int] = [CommandReader.NO_RUNE, CommandReader.NO_RUNE]
## Per player: the last aura color and how much of it is still showing (0-1).
var _aura_colors: Array[Color] = [Color.WHITE, Color.WHITE]
var _aura_strength: Array[float] = [0.0, 0.0]


## Lights player `player`'s hero with rune `rune`'s color, or fades it back
## to neutral for NO_RUNE.
func set_aura(player: int, rune: int) -> void:
	auras[player] = rune
	if rune != CommandReader.NO_RUNE:
		_aura_colors[player] = Rune.COLORS[rune]
		_aura_strength[player] = 1.0
	queue_redraw()


## The aura behind a hero right now (alpha 0 means none).
func aura_color(h: Hero) -> Color:
	if not h.is_alive():
		return DEATH_AURA * Color(1, 1, 1, 0.6 + 0.25 * sin(_time * 3.0))
	return _aura_colors[h.player] * Color(1, 1, 1, _aura_strength[h.player])


func zone_size() -> Vector2:
	return Vector2(size.x / StageRules.VIEW_COLS, size.y / StageMap.LANES)


## Screen rect of a zone, inset by the gap, for the current scroll.
func cell_rect(cell: Vector2i) -> Rect2:
	var z: Vector2 = zone_size()
	var pos := Vector2((cell.x - display_col) * z.x, cell.y * z.y)
	return Rect2(pos + Vector2(GAP, GAP) * 0.5, z - Vector2(GAP, GAP))


## Status tags under a hero for the coming beat.
static func hero_tags(hero: Hero, beat: int) -> String:
	if not hero.is_alive():
		return "FINAL STRIKE" if hero.has_final_strike() else "FALLEN"
	var tags: Array[String] = []
	if hero.is_warded(beat):
		tags.append("WARD")
	if hero.is_braced(beat):
		var arrows: Array[String] = ["↑", "↓", "←", "→"]
		var dir: String = arrows[hero.brace_dir] if hero.brace_dir >= 0 else ""
		tags.append(("BRACE+" if hero.brace_blessed else "BRACE") + dir)
	if hero.exposed:
		tags.append("EXPOSED")
	if hero.guarded:
		tags.append("GUARD")
	return " ".join(tags)


func _process(delta: float) -> void:
	_time += delta
	for p: int in auras.size():
		if auras[p] == CommandReader.NO_RUNE and _aura_strength[p] > 0.0:
			_aura_strength[p] = maxf(0.0, _aura_strength[p] - delta / AURA_FADE)
	if rules != null:
		display_col = move_toward(display_col, rules.camera_col, delta * SCROLL_SPEED * maxf(1.0, rules.camera_col - display_col))
	queue_redraw()


func _draw() -> void:
	if rules == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var font: Font = get_theme_default_font()
	var z: Vector2 = zone_size()
	var text_size: int = clampi(int(z.y * 0.16), 10, 18)
	var next_beat: int = rules.closed_through + 1
	var first: int = floori(display_col)
	var visible_cols: Array[int] = []
	for col: int in range(first, mini(first + StageRules.VIEW_COLS + 1, rules.map.width)):
		visible_cols.append(col)

	for col: int in visible_cols:
		for lane: int in StageMap.LANES:
			_draw_zone(Vector2i(col, lane), font, text_size, next_beat)
	for e: Enemy in rules.enemies:
		if e is BossEnemy and e.is_alive() and e.cell.x in visible_cols:
			_draw_boss(e, font, text_size)
	_draw_telegraphs(font, text_size)
	for e: Enemy in rules.enemies:
		if not (e is BossEnemy) and e.is_alive() and e.cell.x in visible_cols:
			_draw_enemy(e, font, text_size)
	for h: Hero in rules.heroes:
		_draw_hero(h, font, text_size, next_beat)
	_draw_prompts(font, text_size)
	for e: Enemy in rules.enemies:
		if e is BossEnemy and e.is_alive():
			_draw_boss_bar(e, font, text_size)


func _draw_zone(cell: Vector2i, font: Font, text_size: int, next_beat: int) -> void:
	var r: Rect2 = cell_rect(cell)
	if rules.map.walls.has(cell):
		draw_rect(r, WALL_FILL)
		return
	draw_rect(r, ZONE_FILL)
	for fire: FireTrap in rules.fires:
		if cell in fire.cells:
			var until: int = fire.beats_until_on(next_beat)
			var flicker: float = 0.85 + 0.15 * sin(_time * 18.0)
			if until == 0:
				draw_rect(r, FIRE_ON * Color(1, 1, 1, flicker))
				_text_centered(font, "FIRE", r, r.get_center().y + text_size * 0.4, text_size, TEXT_COLOR)
			else:
				draw_rect(r, FIRE_WARN if until <= 2 else FIRE_IDLE)
				_text(font, "fire in %d" % until, r.position + Vector2(6, text_size + 4), text_size - 2, FIRE_ON.lightened(0.3))
	if cell == rules.map.door:
		var door := Rect2(r.position + Vector2(r.size.x * 0.62, r.size.y * 0.15), Vector2(r.size.x * 0.28, r.size.y * 0.75))
		draw_rect(door, DOOR_COLOR)
		if rules.door_open:
			var pulse: float = 0.5 + 0.5 * sin(_time * 6.0)
			draw_rect(r, DOOR_OPEN * Color(1, 1, 1, 0.15 + 0.25 * pulse))
			draw_rect(door.grow(3.0 + 3.0 * pulse), DOOR_OPEN, false, 3.0)
			_text_centered(font, "EXIT", door, door.position.y - 4.0, text_size, DOOR_OPEN)
	draw_rect(r, ZONE_COLOR, false, 2.0)


func _draw_telegraphs(font: Font, text_size: int) -> void:
	for e: Enemy in rules.enemies:
		if not e.is_alive() or not e.is_winding():
			continue
		var countdown: int = e.countdown(rules.closed_through)
		for cell: Vector2i in e.targets:
			var r: Rect2 = cell_rect(cell)
			var fill: Color = SUPER_FILL if e.current.is_super else TARGET_FILL
			draw_rect(r, TARGET_HOT if countdown <= 1 else fill)
			_text(font, str(countdown), Vector2(r.end.x - text_size * 1.4, r.position.y + text_size * 1.8), text_size * 2, TARGET_HOT.lightened(0.5))
			if e.is_off_beat():
				_text(font, "OFF-BEAT", Vector2(r.position.x + 6.0, r.end.y - 6.0), text_size - 2, SUPER_COLOR.lightened(0.3))
		if e.current.from_dir == Rune.Dir.RIGHT and not e.targets.is_empty():
			var a: Vector2 = cell_rect(e.cell).get_center()
			var b: Vector2 = cell_rect(e.targets[0]).get_center()
			draw_dashed_line(a, b, TARGET_HOT.lightened(0.3), 2.0, 8.0)


func _draw_enemy(e: Enemy, font: Font, text_size: int) -> void:
	var r: Rect2 = cell_rect(e.cell)
	var center := Vector2(r.position.x + r.size.x * 0.68, r.position.y + r.size.y * 0.5)
	var s: float = minf(r.size.x, r.size.y) * 0.28
	var super_up: bool = e.is_winding() and e.current.is_super
	if e is RangerEnemy:
		draw_colored_polygon(PackedVector2Array([center + Vector2(-s, 0), center + Vector2(s * 0.6, -s), center + Vector2(s * 0.6, s)]), RANGER_COLOR)
	elif e is BruteEnemy:
		draw_rect(Rect2(center - Vector2(s, s), Vector2(s, s) * 2.0), BRUTE_COLOR)
	elif e is VargEnemy:
		# A low, long wolf shape with ears.
		draw_rect(Rect2(center + Vector2(-s * 1.1, -s * 0.2), Vector2(s * 2.2, s * 0.8)), VARG_COLOR)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-s * 1.1, -s * 0.2), center + Vector2(-s * 0.8, -s * 0.8), center + Vector2(-s * 0.5, -s * 0.2)]), VARG_COLOR)
	elif e is ShieldThrallEnemy:
		draw_rect(Rect2(center - Vector2(s * 0.7, s), Vector2(s * 1.4, s * 2.0)), THRALL_COLOR)
		var thrall: ShieldThrallEnemy = e
		if thrall.is_shielded(rules.closed_through + 1):
			draw_circle(center + Vector2(-s * 0.8, 0), s * 0.75, SHIELD_COLOR)
			draw_arc(center + Vector2(-s * 0.8, 0), s * 0.75, 0, TAU, 24, SHIELD_COLOR.darkened(0.4), 2.0)
		else:
			draw_circle(center + Vector2(-s * 0.4, s * 1.1), s * 0.5, SHIELD_COLOR.darkened(0.5))
	else:
		draw_rect(Rect2(center - Vector2(s, s) * 1.2, Vector2(s, s) * 2.4), SUPER_COLOR if super_up else PATTERN_COLOR)
	_hp_bar(Rect2(center.x - s, center.y - s - 10.0, s * 2.0, 5.0), e)
	var label: String = e.display_name
	if e is ShieldThrallEnemy and not (e as ShieldThrallEnemy).is_shielded(rules.closed_through + 1):
		label += " (OPEN)"
	if e.is_winding():
		label = ("SUPER " if super_up else "") + e.current.display_name
	_text_centered(font, label, Rect2(center.x - r.size.x * 0.4, 0, r.size.x * 0.8, 0), center.y + s + text_size + 2.0, text_size - 1, TEXT_COLOR)


## The boss's body over its zones: armored plates on intact parts (with a
## bar for how close each is to breaking), wounds on broken ones.
func _draw_boss(boss: BossEnemy, font: Font, text_size: int) -> void:
	var super_up: bool = boss.is_winding() and boss.current.is_super
	for c: Vector2i in boss.footprint:
		var r: Rect2 = cell_rect(c)
		draw_rect(r, SUPER_FILL if super_up else BOSS_BODY)
		var part: BossPart = boss.part_at(c)
		var label: String = "body"
		var col: Color = TEXT_COLOR * Color(1, 1, 1, 0.5)
		if part != null and part.broken:
			draw_rect(r.grow(-r.size.y * 0.12), BOSS_WOUND)
			label = "%s WOUND" % part.display_name
			col = TEXT_COLOR
		elif part != null:
			draw_rect(r.grow(-r.size.y * 0.12), BOSS_PLATE)
			label = part.display_name
			col = Color(0.1, 0.12, 0.15)
			var bar := Rect2(r.position.x + 8.0, r.end.y - 14.0, r.size.x - 16.0, 5.0)
			draw_rect(bar, HP_BACK)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * (1.0 - float(part.damage) / part.break_hp), bar.size.y)), BOSS_PLATE.darkened(0.4))
		_text_centered(font, label, r, r.get_center().y + text_size * 0.35, text_size - 1, col)


func _draw_boss_bar(boss: BossEnemy, font: Font, text_size: int) -> void:
	var w: float = size.x * 0.5
	var bar := Rect2((size.x - w) * 0.5, 6.0, w, 8.0)
	draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.6))
	_hp_bar(bar, boss)
	var label: String = boss.display_name
	if boss.is_winding():
		label += ": " + ("SUPER " if boss.current.is_super else "") + boss.current.display_name
	_text_centered(font, label, bar, bar.end.y + text_size + 2.0, text_size, TEXT_COLOR)


func _draw_hero(h: Hero, font: Font, text_size: int, next_beat: int) -> void:
	var r: Rect2 = cell_rect(h.cell)
	var slot: float = 0.22 if h.player == 0 else 0.42
	var foot := Vector2(r.position.x + r.size.x * slot, r.position.y + r.size.y * 0.78)
	var unit: float = minf(r.size.x, r.size.y) / 90.0
	var col: Color = HERO_COLORS[h.player % HERO_COLORS.size()] if h.is_alive() else DEAD_COLOR
	if h.has_final_strike():
		col = FINAL_COLOR * Color(1, 1, 1, 0.55 + 0.45 * sin(_time * 8.0))
	_draw_aura(foot - Vector2(0, 20) * unit, unit, aura_color(h))
	draw_circle(foot - Vector2(0, 30) * unit, 6.0 * unit, col)
	draw_rect(Rect2(foot - Vector2(7, 23) * unit, Vector2(14, 23) * unit), col)
	if h.is_alive() and h.is_braced(next_beat) and h.brace_dir >= 0:
		var d: Vector2 = Vector2(StageRules.STEPS[h.brace_dir])
		var shield: Vector2 = foot - Vector2(0, 14) * unit + d * 14.0 * unit
		draw_line(shield - d.orthogonal() * 10.0 * unit, shield + d.orthogonal() * 10.0 * unit, col.lightened(0.4), 4.0 * unit)
	_hp_bar(Rect2(foot.x - 18.0 * unit, foot.y - 46.0 * unit, 36.0 * unit, 4.0), h)
	_text(font, "P%d  %dg" % [h.player + 1, h.glory], foot + Vector2(-7, -50) * unit, text_size - 2, col)
	_text(font, hero_tags(h, next_beat), foot + Vector2(-16 * unit, text_size), text_size - 3, TEXT_COLOR)


## A soft glow behind a hero: stacked circles fading outward.
func _draw_aura(center: Vector2, unit: float, color: Color) -> void:
	if color.a <= 0.0:
		return
	var rings: int = 6
	for i: int in rings:
		var t: float = float(rings - i) / rings
		draw_circle(center, (10.0 + 22.0 * t) * unit, color * Color(1, 1, 1, 0.16 * (1.0 - t * 0.6)))


func _draw_prompts(font: Font, text_size: int) -> void:
	if rules.is_locked():
		var x: float = size.x - 3.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), LOCK_COLOR, 6.0)
	elif rules.can_advance() and not rules.over:
		var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
		var pos := Vector2(size.x - text_size * 4.5, size.y * 0.5)
		_text(font, "GO →", pos, text_size * 2, GO_COLOR * Color(1, 1, 1, 0.4 + 0.6 * pulse))


func _hp_bar(r: Rect2, who: Combatant) -> void:
	draw_rect(r, HP_BACK)
	draw_rect(Rect2(r.position, Vector2(r.size.x * who.hp / float(who.max_hp), r.size.y)), HP_FRONT)


func _text(font: Font, text: String, pos: Vector2, font_size: int, col: Color) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _text_centered(font: Font, text: String, r: Rect2, y: float, font_size: int, col: Color) -> void:
	draw_string(font, Vector2(r.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, font_size, col)
