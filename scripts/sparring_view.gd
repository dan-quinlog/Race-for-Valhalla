class_name SparringView
extends Control
## Draws the Rhythm Lab's training yard (SparringRules): the zone grid with
## borders pulsing on every heartbeat, the foes (Post, Draugr, Varg,
## Shield-thrall, Archer, or the Jötunn with its parts) with their states,
## telegraphed attacks with their name and a countdown (purple for area
## hits that can't be blocked), and the heroes with a facing arrow, shield, Heavy
## charge glow and blessing ring. Attacks flash the zones they hit, with
## BLOCK / EVADE pops. Placeholder shapes until real sprites.
##
## A side-view yard (the cave) is drawn through a camera window in zone
## units: depth rows are squashed, with sprites standing up out of them,
## and terrain is drawn per zone (vines, catwalk planks, ladder). The camera
## prefers DEFAULT_VIEW_HEIGHT on the ground and zooms out to keep every
## hero (and the boss's front) in view; `always_wide` shows the whole yard.

const GAP: float = 4.0
const DEFAULT_VIEW_HEIGHT: float = 3.2
const CAMERA_MARGIN: float = 0.5
const CAMERA_SPEED: float = 5.0
const FLOOR_FILL := Color(0.45, 0.35, 0.25, 0.25)
const VINE_COLOR := Color(0.35, 0.65, 0.3)
const PLANK_COLOR := Color(0.55, 0.4, 0.25)
const LADDER_COLOR := Color(0.7, 0.55, 0.35)
const KNOCK_ARROW := Color(1, 1, 1, 0.85)
const RUNNER_COLOR := Color(0.7, 0.6, 0.45)
const ZONE_FILL := Color(1, 1, 1, 0.03)
const BEAT_COLOR := Color(0.95, 0.8, 0.45)
const BEAT_PULSE_TIME: float = 0.3
const FLASH_TIME: float = 0.45
## How long a loosed arrow stays drawn where it stopped.
const SHOT_TIME: float = 0.8
const SHOT_COLORS := {"HIT": Color(1.0, 0.35, 0.2), "BLOCK": Color(0.6, 0.8, 1.0), "MISS": Color(0.75, 0.72, 0.65)}
const HERO_COLORS: Array[Color] = [Color(0.45, 0.7, 1.0), Color(1.0, 0.65, 0.3)]
const DUMMY_COLOR := Color(0.6, 0.5, 0.38)
const DRAUGR_COLOR := Color(0.45, 0.55, 0.45)
const VARG_COLOR := Color(0.62, 0.6, 0.58)
const THRALL_COLOR := Color(0.6, 0.45, 0.32)
const BOSS_COLOR := Color(0.35, 0.5, 0.62)
const PART_COLOR := Color(0.55, 0.72, 0.85)
const WOUND_COLOR := Color(0.85, 0.2, 0.25)
const AREA_FILL := Color(0.75, 0.4, 1.0, 0.18)
const AREA_HOT := Color(0.75, 0.4, 1.0, 0.45)
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
			rules.shot.disconnect(_on_shot)
		rules = value
		_flashes.clear()
		_shots.clear()
		if rules != null:
			rules.flashed.connect(_on_flashed)
			rules.shot.connect(_on_shot)
			if rules.is_side_view():
				_win = camera_target()
		queue_redraw()
## Side view: show the whole yard instead of following the heroes.
var always_wide: bool = false
## Side view: the camera's window onto the yard, in zone units.
var _win := Rect2()
## The beat that started last (on the buh).
var beat_index: int = -1
var _beat_pulse: float = 0.0
var _time: float = 0.0
## {cells, color, text, left}
var _flashes: Array[Dictionary] = []
## Arrows just loosed: {from, to, outcome, left}
var _shots: Array[Dictionary] = []


func on_beat(index: int) -> void:
	beat_index = index
	_beat_pulse = 1.0


func flash_count() -> int:
	return _flashes.size()


func shot_count() -> int:
	return _shots.size()


func _on_shot(from: Vector2i, to: Vector2i, outcome: String) -> void:
	_shots.append({"from": from, "to": to, "outcome": outcome, "left": SHOT_TIME})


func _on_flashed(cells: Array[Vector2i], color: Color, text: String) -> void:
	_flashes.append({"cells": cells.duplicate(), "color": color, "text": text, "left": FLASH_TIME})


func _ready() -> void:
	clip_contents = true


func _process(delta: float) -> void:
	_time += delta
	if _side():
		var target: Rect2 = camera_target()
		var k: float = 1.0 - exp(-delta * CAMERA_SPEED)
		if _win.size.x <= 0.0:
			k = 1.0
		_win = Rect2(_win.position.lerp(target.position, k), _win.size.lerp(target.size, k))
	_beat_pulse = maxf(0.0, _beat_pulse - delta / BEAT_PULSE_TIME)
	for f: Dictionary in _flashes:
		f.left -= delta
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return f.left > 0.0)
	for a: Dictionary in _shots:
		a.left -= delta
	_shots = _shots.filter(func(a: Dictionary) -> bool: return a.left > 0.0)
	queue_redraw()


func _side() -> bool:
	return rules != null and rules.is_side_view()


## A full (height) zone's size on screen.
func zone_size() -> Vector2:
	if _side():
		return Vector2.ONE * _view_scale()
	var grid := Vector2(SparringRules.YARD_SIZE) if rules == null else Vector2(rules.cols, rules.lanes)
	return size / grid


func cell_rect(cell: Vector2i) -> Rect2:
	if _side():
		var sc: float = _view_scale()
		var at: Vector2 = _to_screen(Vector2(cell.x, rules.row_top(cell.y)))
		var r := Rect2(at, Vector2(1.0, rules.row_height(cell.y)) * sc)
		return r.grow(-GAP * 0.5)
	var z: Vector2 = zone_size()
	return Rect2(Vector2(cell.x * z.x, cell.y * z.y) + Vector2(GAP, GAP) * 0.5, z - Vector2(GAP, GAP))


## Where a foe or hero is drawn: its zone, or in a depth row a square box
## standing up out of the zone's bottom, overlapping the row behind.
func sprite_rect(cell: Vector2i) -> Rect2:
	var r: Rect2 = cell_rect(cell)
	if _side() and rules.is_depth_row(cell.y):
		return Rect2(r.position.x, r.end.y - r.size.x, r.size.x, r.size.x)
	return r


func _view_scale() -> float:
	if _win.size.x <= 0.0 or _win.size.y <= 0.0:
		return 1.0
	return minf(size.x / _win.size.x, size.y / _win.size.y)


func _to_screen(p: Vector2) -> Vector2:
	var sc: float = _view_scale()
	return (p - _win.position) * sc + (size - _win.size * sc) * 0.5


## The window the camera eases toward, in zone units: DEFAULT_VIEW_HEIGHT
## resting on the ground, grown to fit every hero (plus a margin) and the
## boss's front column, never past the whole yard. `always_wide`: the whole
## yard.
func camera_target() -> Rect2:
	var world: Vector2 = rules.world_size()
	var aspect: float = size.x / size.y if size.x > 0.0 and size.y > 0.0 else 2.0
	var full_h: float = maxf(world.y, world.x / aspect)
	var need := Rect2()
	for h: SparringRules.Fighter in rules.heroes:
		var r := Rect2(h.cell.x, rules.row_top(h.cell.y), 1.0, rules.row_height(h.cell.y)).grow(CAMERA_MARGIN)
		need = r if need.size == Vector2.ZERO else need.merge(r)
	for d: SparringRules.Dummy in rules.dummies:
		if d.is_boss() and d.is_alive():
			var front: int = d.footprint[0].x
			for z: Vector2i in d.footprint:
				front = mini(front, z.x)
			need = need.merge(Rect2(front, need.position.y, 1.0, need.size.y))
	var h_view: float = full_h if always_wide else maxf(minf(DEFAULT_VIEW_HEIGHT, world.y), maxf(need.size.y, need.size.x / aspect))
	h_view = minf(h_view, full_h)
	var w_view: float = h_view * aspect
	var x: float = (world.x - w_view) * 0.5
	if w_view < world.x:
		x = clampf(need.get_center().x - w_view * 0.5, 0.0, world.x - w_view)
	var y: float = (world.y - h_view) * 0.5
	if h_view < world.y:
		y = clampf(minf(world.y - h_view, need.position.y), 0.0, world.y - h_view)
	return Rect2(x, y, w_view, h_view)


func _draw() -> void:
	if rules == null:
		return
	var font: Font = get_theme_default_font()
	var text_size: int = clampi(int(zone_size().y * 0.14), 10, 16)
	# The beat that resolves next: the open one.
	var open_beat: int = beat_index
	for col: int in rules.cols:
		for lane: int in rules.lanes:
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
	# The boss behind everything, then foes and heroes back row to front
	# row so nearer sprites overlap the ones behind.
	var bodies: Array = []
	for d: SparringRules.Dummy in rules.dummies:
		if d.is_alive():
			if d.is_boss():
				_draw_boss(d, open_beat, font, text_size)
			else:
				bodies.append(d)
	bodies.append_array(rules.heroes)
	bodies.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.cell.y < b.cell.y)
	for b: Variant in bodies:
		if b is SparringRules.Fighter:
			_draw_hero(b, open_beat, font, text_size)
		else:
			_draw_dummy(b, open_beat, font, text_size)
	for a: Dictionary in _shots:
		_draw_shot(a)


## An arrow from the Archer to where it stopped: the near edge of the zone it
## hit or was blocked in (with a bar for a block), or off the left edge.
func _draw_shot(a: Dictionary) -> void:
	var fade: float = clampf(a.left / SHOT_TIME * 1.5, 0.0, 1.0)
	var col: Color = SHOT_COLORS[a.outcome] * Color(1, 1, 1, fade)
	var start: Vector2 = cell_rect(a.from).get_center() - Vector2(zone_size().x * 0.3, 0)
	var tip := Vector2(0.0, start.y)
	if a.to.x >= 0:
		tip.x = cell_rect(a.to).end.x - zone_size().x * 0.12
	draw_line(start, tip + Vector2(10, 0), col, 3.0)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(14, -7), tip + Vector2(14, 7)]), col)
	draw_line(start, start + Vector2(10, -6), col, 2.0)
	draw_line(start, start + Vector2(10, 6), col, 2.0)
	if a.outcome == "BLOCK":
		draw_line(tip + Vector2(-4, -16), tip + Vector2(-4, 16), col, 5.0)


func _draw_zone(cell: Vector2i) -> void:
	var r: Rect2 = cell_rect(cell)
	draw_rect(r, ZONE_FILL)
	var border: Color = BEAT_COLOR * Color(1, 1, 1, 0.3 + 0.6 * _beat_pulse)
	if _side():
		var z: SparringRules.Zone = rules.zone_of(cell)
		match z.ground:
			SparringRules.Ground.FLOOR:
				draw_rect(r, FLOOR_FILL)
			SparringRules.Ground.AIR:
				border.a *= 0.4
			SparringRules.Ground.VINES:
				border.a *= 0.6
				for i: int in 4:
					var x: float = r.position.x + r.size.x * (0.14 + 0.24 * i)
					var pts := PackedVector2Array()
					for k: int in 7:
						pts.append(Vector2(x + (4.0 if k % 2 == 1 else -4.0), r.position.y + r.size.y * 0.7 * k / 6.0))
					draw_polyline(pts, VINE_COLOR, 2.0)
			SparringRules.Ground.LEDGE:
				draw_rect(Rect2(r.position.x - GAP, r.end.y - r.size.y * 0.12, r.size.x + GAP * 2.0, r.size.y * 0.12), PLANK_COLOR)
			SparringRules.Ground.LADDER:
				for fx: float in [0.25, 0.75]:
					var x: float = r.position.x + r.size.x * fx
					draw_line(Vector2(x, r.position.y - GAP), Vector2(x, r.end.y + GAP), LADDER_COLOR, 3.0)
				for k: int in 4:
					var y: float = r.position.y + r.size.y * (0.125 + 0.25 * k)
					draw_line(Vector2(r.position.x + r.size.x * 0.25, y), Vector2(r.position.x + r.size.x * 0.75, y), LADDER_COLOR, 2.0)
	draw_rect(r, border, false, 1.5 + 2.5 * _beat_pulse)


func _draw_tell(d: SparringRules.Dummy, open_beat: int, font: Font, text_size: int) -> void:
	var left: int = d.strike_beat - open_beat
	var area: bool = d.strike_kind == SparringRules.HitKind.AREA
	var hot: Color = AREA_HOT if area else TELL_HOT
	var fill: Color = AREA_FILL if area else TELL_FILL
	for cell: Vector2i in d.targets:
		var r: Rect2 = cell_rect(cell)
		draw_rect(r, hot if left <= 0 else fill)
		if left > 0:
			draw_string(font, r.position + Vector2(6, text_size + 4), str(left), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size + 6, hot * Color(1, 1, 1, 2))
	if d.kind != SparringRules.Dummy.Kind.ARCHER and not d.targets.is_empty():
		var r0: Rect2 = cell_rect(d.targets[0])
		var label: String = d.strike_name + (" (AREA: evade only)" if area else "")
		if d.strike_knock != Vector2i.ZERO:
			label += " " + knock_text(d.strike_knock)
		draw_string(font, Vector2(r0.position.x + 6, r0.end.y - 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, hot * Color(1, 1, 1, 2))
	if d.strike_knock != Vector2i.ZERO and not d.targets.is_empty():
		_draw_knock(d)


## "↑1 ←2": a knockback, vertical part first.
static func knock_text(k: Vector2i) -> String:
	var parts: Array[String] = []
	if k.y != 0:
		parts.append("%s%d" % ["↑" if k.y < 0 else "↓", absi(k.y)])
	if k.x != 0:
		parts.append("%s%d" % ["←" if k.x < 0 else "→", absi(k.x)])
	return " ".join(parts)


## The knockback path as an arrow from the middle of the attack: down or up
## first, then across.
func _draw_knock(d: SparringRules.Dummy) -> void:
	var area := cell_rect(d.targets[0])
	for c: Vector2i in d.targets:
		area = area.merge(cell_rect(c))
	var z: Vector2 = zone_size()
	var p0: Vector2 = area.get_center()
	var p1: Vector2 = p0 + Vector2(0, d.strike_knock.y * z.y)
	var p2: Vector2 = p1 + Vector2(d.strike_knock.x * z.x, 0)
	draw_polyline(PackedVector2Array([p0, p1, p2]), KNOCK_ARROW, 4.0)
	var last: Vector2 = p2 - p1 if p2 != p1 else p1 - p0
	var dir: Vector2 = last.normalized()
	var head: float = z.x * 0.15
	draw_colored_polygon(PackedVector2Array([p2 + dir * head, p2 - dir * head * 0.5 + dir.orthogonal() * head * 0.7, p2 - dir * head * 0.5 - dir.orthogonal() * head * 0.7]), KNOCK_ARROW)


func _draw_dummy(d: SparringRules.Dummy, open_beat: int, font: Font, text_size: int) -> void:
	if d.is_boss():
		_draw_boss(d, open_beat, font, text_size)
		return
	var r: Rect2 = sprite_rect(d.cell)
	var c: Vector2 = r.get_center() + Vector2(0, r.size.y * 0.05)
	var s: float = minf(r.size.x, r.size.y) * 0.24
	match d.kind:
		SparringRules.Dummy.Kind.POST:
			draw_rect(Rect2(c - Vector2(s * 0.35, s), Vector2(s * 0.7, s * 2.0)), DUMMY_COLOR)
			draw_rect(Rect2(c - Vector2(s, s * 0.6), Vector2(s * 2.0, s * 0.3)), DUMMY_COLOR)
		SparringRules.Dummy.Kind.DRAUGR:
			draw_rect(Rect2(c - Vector2(s * 1.1, s * 1.1), Vector2(s * 2.2, s * 2.2)), DRAUGR_COLOR)
		SparringRules.Dummy.Kind.VARG:
			# Crouched (flat) on the beat it leaps: the sprite change a
			# player learns to read.
			var h: float = s * (0.45 if d.is_leaping(open_beat) else 0.8)
			var fx: float = signf(d.leap_dir.x) if d.is_leaping(open_beat) and d.leap_dir.x != 0 else -1.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(fx * s * 1.3, 0), c + Vector2(-fx * s, -h), c + Vector2(-fx * s, h)]), VARG_COLOR)
		SparringRules.Dummy.Kind.THRALL:
			draw_circle(c, s * 0.9, THRALL_COLOR)
			if d.is_shielded(open_beat):
				var at := c + Vector2(d.facing * s * 1.2, 0)
				draw_line(at + Vector2(0, -s * 1.1), at + Vector2(0, s * 1.1), SHIELD_COLOR, 6.0)
			else:
				var tip := c + Vector2(d.facing * s * 1.6, 0)
				draw_line(c, tip, TEXT_COLOR, 2.0)
		SparringRules.Dummy.Kind.ARCHER:
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(s, -s), c + Vector2(s, s)]), ARCHER_COLOR)
		SparringRules.Dummy.Kind.RUNNER:
			draw_rect(Rect2(c - Vector2(s, s * 0.3), Vector2(s * 2.0, s * 0.9)), RUNNER_COLOR)
			draw_circle(c + Vector2(d.facing * s * 1.1, -s * 0.2), s * 0.4, RUNNER_COLOR)
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
	if d.kind == SparringRules.Dummy.Kind.THRALL and not d.is_shielded(open_beat):
		tags.append("NO SHIELD")
	draw_string(font, Vector2(r.position.x + 4, r.end.y - 6), " ".join(tags), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, text_size - 2, TEXT_COLOR)


func _draw_hero(h: SparringRules.Fighter, open_beat: int, font: Font, text_size: int) -> void:
	var r: Rect2 = sprite_rect(h.cell)
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
	if h.stun_until > rules.beat:
		tags.append("STUNNED")
	if rules.is_hanging(h):
		tags.append("HANGING")
	elif rules.is_airborne(h):
		tags.append("FALLING")
	draw_string(font, Vector2(c.x - s * 1.5, c.y + s + text_size + 2), " ".join(tags), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size - 2, col)


## The boss: one body over its footprint, each part boxed in its zone with
## how worn it is (a red cross once broken), vulnerable zones ringed, and
## one wide health bar.
func _draw_boss(d: SparringRules.Dummy, open_beat: int, font: Font, text_size: int) -> void:
	var body := cell_rect(d.footprint[0])
	for z: Vector2i in d.footprint:
		body = body.merge(cell_rect(z))
	draw_rect(body.grow(-6.0), BOSS_COLOR * Color(1, 1, 1, 0.85))
	for z: Vector2i in d.footprint:
		var r: Rect2 = cell_rect(z).grow(-12.0)
		var p: SparringRules.Part = d.part_at(z)
		if p != null:
			if p.broken:
				draw_rect(r, WOUND_COLOR * Color(1, 1, 1, 0.5))
				draw_line(r.position, r.end, WOUND_COLOR, 3.0)
				draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), WOUND_COLOR, 3.0)
			else:
				draw_rect(r, PART_COLOR, false, 3.0)
				var worn := Rect2(r.position.x, r.end.y - 6.0, r.size.x, 5.0)
				draw_rect(worn, HP_BACK)
				draw_rect(Rect2(worn.position, Vector2(worn.size.x * (1.0 - p.wear / float(p.break_hp)), worn.size.y)), PART_COLOR)
			draw_string(font, r.position + Vector2(4, text_size + 2), p.display_name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, text_size - 2, TEXT_COLOR)
		else:
			draw_string(font, r.position + Vector2(4, text_size + 2), "body", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, text_size - 2, TEXT_COLOR * Color(1, 1, 1, 0.6))
		if d.vulnerable_at(z, open_beat):
			draw_arc(r.get_center(), minf(r.size.x, r.size.y) * 0.45, 0.0, TAU, 24, VULN_COLOR, 3.0)
	var bar := Rect2(body.position.x + 6.0, body.position.y + 2.0, body.size.x - 12.0, 6.0)
	draw_rect(bar, HP_BACK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * d.hp / float(d.max_hp), bar.size.y)), HP_FRONT)
	var tag: String = "%s %d/%d" % [d.display_name, d.hp, d.max_hp]
	if d.broken_parts() > 0:
		tag += "  BLEEDING x%d" % d.broken_parts()
	draw_string(font, Vector2(body.position.x + 6.0, body.end.y - 8.0), tag, HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 12.0, text_size, TEXT_COLOR)
