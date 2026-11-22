class_name SparringView
extends Control
## Draws the Rhythm Lab's training yard (SparringRules): the zone grid with
## borders pulsing on every heartbeat, the dummies (Post, Walker, Sparrer)
## (Post, Walker, Sparrer, Archer) with their states, telegraphed strikes
## with a countdown, and the heroes with a facing arrow, shield, Heavy
## charge glow and blessing ring. Attacks flash the zones they hit, with
## BLOCK / EVADE pops. Placeholder shapes until real sprites.

const GAP: float = 4.0
const ZONE_FILL := Color(1, 1, 1, 0.03)
const BEAT_COLOR := Color(0.95, 0.8, 0.45)
const BEAT_PULSE_TIME: float = 0.3
const FLASH_TIME: float = 0.45
const HERO_COLORS: Array[Color] = [Color(0.45, 0.7, 1.0), Color(1.0, 0.65, 0.3)]
const DUMMY_COLOR := Color(0.6, 0.5, 0.38)
const WALKER_COLOR := Color(0.55, 0.6, 0.5)
const SPARRER_COLOR := Color(0.7, 0.45, 0.3)
const TELL_FILL := Color(1.0, 0.45, 0.1, 0.18)
const TELL_HOT := Color(1.0, 0.35, 0.1, 0.45)
const CHARGE_COLOR := Color(1.0, 0.3, 0.2)
const BLESS_COLOR := Color(1.0, 0.85, 0.3)
const SHIELD_COLOR := Color(0.6, 0.8, 1.0)
const ARCHER_COLOR := Color(0.55, 0.5, 0.35)
const VULN_COLOR := Color(1.0, 0.35, 0.6)
const HP_BACK := Color(0.15, 0.05, 0.05)
const HP_FRONT := Color(0.85, 0.2, 0.2)
const TEXT_COLOR := Color(0.92, 0.9, 0.85)

var rules: SparringRules:
	set(value):
		if rules != null and rules.flashed.is_connected(_on_flashed):
			rules.flashed.disconnect(_on_flashed)
		rules = value
		_flashes.clear()
		if rules != null:
			rules.flashed.connect(_on_flashed)
		queue_redraw()
## The beat that started last (on the buh).
var beat_index: int = -1
var _beat_pulse: float = 0.0
var _time: float = 0.0
## {cells, color, text, left}
var _flashes: Array[Dictionary] = []


func on_beat(index: int) -> void:
	beat_index = index
	_beat_pulse = 1.0


func flash_count() -> int:
	return _flashes.size()


func _on_flashed(cells: Array[Vector2i], color: Color, text: String) -> void:
	_flashes.append({"cells": cells.duplicate(), "color": color, "text": text, "left": FLASH_TIME})


func _process(delta: float) -> void:
	_time += delta
	_beat_pulse = maxf(0.0, _beat_pulse - delta / BEAT_PULSE_TIME)
	for f: Dictionary in _flashes:
		f.left -= delta
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return f.left > 0.0)
	queue_redraw()


func zone_size() -> Vector2:
	return Vector2(size.x / SparringRules.COLS, size.y / SparringRules.LANES)


func cell_rect(cell: Vector2i) -> Rect2:
	var z: Vector2 = zone_size()
	return Rect2(Vector2(cell.x * z.x, cell.y * z.y) + Vector2(GAP, GAP) * 0.5, z - Vector2(GAP, GAP))


func _draw() -> void:
	if rules == null:
		return
	var font: Font = get_theme_default_font()
	var text_size: int = clampi(int(zone_size().y * 0.14), 10, 16)
	# The beat that resolves next: the open one.
	var open_beat: int = beat_index
	for col: int in SparringRules.COLS:
		for lane: int in SparringRules.LANES:
			_draw_zone(Vector2i(col, lane))
	for d: SparringRules.Dummy in rules.dummies:
		if d.is_alive() and d.strike_beat != SparringRules.NONE:
			_draw_tell(d, open_beat, font, text_size)
	for f: Dictionary in _flashes:
		var a: float = f.left / FLASH_TIME
		for cell: Vector2i in f.cells:
			draw_rect(cell_rect(cell), f.color * Color(1, 1, 1, 0.5 * a))
		if f.text != "" and not f.cells.is_empty():
			var r0: Rect2 = cell_rect(f.cells[0])
			var rise: float = (1.0 - a) * 12.0
			draw_string(font, Vector2(r0.position.x + 4, r0.position.y + text_size * 2 + 6 - rise), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size + 2, Color(1, 1, 1, a))
	for d: SparringRules.Dummy in rules.dummies:
		if d.is_alive():
			_draw_dummy(d, open_beat, font, text_size)
	for h: SparringRules.Fighter in rules.heroes:
		_draw_hero(h, open_beat, font, text_size)


func _draw_zone(cell: Vector2i) -> void:
	var r: Rect2 = cell_rect(cell)
	draw_rect(r, ZONE_FILL)
	var border: Color = BEAT_COLOR * Color(1, 1, 1, 0.3 + 0.6 * _beat_pulse)
	draw_rect(r, border, false, 1.5 + 2.5 * _beat_pulse)


func _draw_tell(d: SparringRules.Dummy, open_beat: int, font: Font, text_size: int) -> void:
	var left: int = d.strike_beat - open_beat
	for cell: Vector2i in d.targets:
		var r: Rect2 = cell_rect(cell)
		draw_rect(r, TELL_HOT if left <= 0 else TELL_FILL)
		if left > 0:
			draw_string(font, r.position + Vector2(6, text_size + 4), str(left), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size + 6, TELL_HOT * Color(1, 1, 1, 2))


func _draw_dummy(d: SparringRules.Dummy, open_beat: int, font: Font, text_size: int) -> void:
	var r: Rect2 = cell_rect(d.cell)
	var c: Vector2 = r.get_center() + Vector2(0, r.size.y * 0.05)
	var s: float = minf(r.size.x, r.size.y) * 0.24
	match d.kind:
		SparringRules.Dummy.Kind.POST:
			draw_rect(Rect2(c - Vector2(s * 0.35, s), Vector2(s * 0.7, s * 2.0)), DUMMY_COLOR)
			draw_rect(Rect2(c - Vector2(s, s * 0.6), Vector2(s * 2.0, s * 0.3)), DUMMY_COLOR)
		SparringRules.Dummy.Kind.WALKER:
			draw_circle(c, s, WALKER_COLOR)
			var tip := c + Vector2(d.walk_dir * s * 1.4, 0)
			draw_line(c, tip, TEXT_COLOR, 2.0)
		SparringRules.Dummy.Kind.SPARRER:
			draw_rect(Rect2(c - Vector2(s, s), Vector2(s * 2.0, s * 2.0)), SPARRER_COLOR)
		SparringRules.Dummy.Kind.ARCHER:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(s, -s), c + Vector2(s, s)]), ARCHER_COLOR)
	if d.is_vulnerable(open_beat):
		draw_arc(c, s * 1.35, 0.0, TAU, 24, VULN_COLOR, 3.0)
	var bar := Rect2(c.x - s, c.y - s - 10.0, s * 2.0, 5.0)
	draw_rect(bar, HP_BACK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * d.hp / float(d.max_hp), bar.size.y)), HP_FRONT)
	var tags: Array[String] = [d.display_name]
	if d.is_rooted(open_beat):
		tags.append("ROOTED")
	if d.is_vulnerable(open_beat):
		tags.append("VULN")
	draw_string(font, Vector2(r.position.x + 4, r.end.y - 6), " ".join(tags), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, text_size - 2, TEXT_COLOR)


func _draw_hero(h: SparringRules.Fighter, open_beat: int, font: Font, text_size: int) -> void:
	var r: Rect2 = cell_rect(h.cell)
	var slot: float = 0.3 if h.player == 0 else 0.62
	var c := Vector2(r.position.x + r.size.x * slot, r.get_center().y)
	var s: float = minf(r.size.x, r.size.y) * 0.17
	var col: Color = HERO_COLORS[h.player % HERO_COLORS.size()]
	if h.charge > 0:
		var glow: float = 0.5 + 0.5 * sin(_time * 14.0)
		draw_circle(c, s * (1.4 + 0.25 * h.charge + 0.2 * glow), CHARGE_COLOR * Color(1, 1, 1, 0.2 + 0.25 * glow))
	if h.blessed:
		draw_arc(c, s * 1.35, 0.0, TAU, 24, BLESS_COLOR, 3.0)
	draw_circle(c, s, col)
	# Facing arrow.
	var f := Vector2(h.facing, 0)
	var tip: Vector2 = c + f * s * 1.9
	draw_colored_polygon(PackedVector2Array([tip, c + f * s * 1.2 + Vector2(0, -s * 0.55), c + f * s * 1.2 + Vector2(0, s * 0.55)]), col.lightened(0.3))
	# Shield on the side it guarded this turn (or a small one on the facing side).
	if rules.shields:
		var guard: int = h.guard_dir if h.guard_beat == rules.beat else SparringRules.facing_dir(h.facing)
		var d := Vector2(SparringRules.dir_offset(guard))
		var at: Vector2 = c + d * s * 1.5
		var w: float = 4.0 if h.guard_beat == rules.beat else 2.0
		draw_line(at - d.orthogonal() * s * 0.9, at + d.orthogonal() * s * 0.9, SHIELD_COLOR, w)
	var bar := Rect2(c.x - s * 1.2, c.y - s - 9.0, s * 2.4, 4.0)
	draw_rect(bar, HP_BACK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * h.hp / float(h.max_hp), bar.size.y)), HP_FRONT)
	var tags: Array[String] = ["%s %dg" % [h.display_name, h.glory]]
	if h.charge > 0:
		tags.append("HEAVY x%d EXPOSED" % h.charge)
	if h.blessed:
		tags.append("BLESSED")
	draw_string(font, Vector2(c.x - s * 1.5, c.y + s + text_size + 2), " ".join(tags), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size - 2, col)
