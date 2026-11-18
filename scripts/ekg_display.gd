class_name EkgDisplay
extends Control
## Scrolling EKG trace. "Now" sits at the horizontal center, under the heart.
## Upcoming beats scroll in from the right, and the buh spike crosses the
## center line on the beat. Shaded bands show the hit and perfect windows.
## Input markers stay on the trace so early and late hits are visible.

const BG_COLOR := Color(0.04, 0.06, 0.05)
const GRID_COLOR := Color(0.1, 0.2, 0.12)
const LINE_COLOR := Color(0.35, 1.0, 0.5)
const WINDOW_COLOR := Color(1.0, 1.0, 1.0, 0.07)
const PERFECT_COLOR := Color(1.0, 0.85, 0.3, 0.16)
const CENTER_COLOR := Color(1.0, 1.0, 1.0, 0.35)
const HEART_COLOR := Color(0.9, 0.12, 0.18)
const GRADE_COLORS := {
	BeatJudge.Grade.PERFECT: Color(1.0, 0.85, 0.3),
	BeatJudge.Grade.GOOD: Color(0.5, 0.8, 1.0),
	BeatJudge.Grade.MISS: Color(1.0, 0.3, 0.3),
}
const _SPIKE_WIDTH: float = 0.018

var period: float = 0.667
var dum_delay: float = 0.15
var window: float = 0.15
var perfect_window: float = 0.04
## Seconds of trace across the full width.
var seconds_visible: float = 3.0
var now: float = 0.0

var _markers: Array[Dictionary] = []


func configure(p_period: float, p_dum_delay: float, p_window: float, p_perfect_window: float) -> void:
	period = p_period
	dum_delay = p_dum_delay
	window = p_window
	perfect_window = p_perfect_window
	_markers.clear()
	queue_redraw()


func set_time(t: float) -> void:
	now = t
	while not _markers.is_empty() and _markers[0].time < now - seconds_visible:
		_markers.pop_front()
	queue_redraw()


func add_marker(t: float, grade: BeatJudge.Grade) -> void:
	_markers.append({"time": t, "grade": grade})
	queue_redraw()


func marker_count() -> int:
	return _markers.size()


## Trace height at time t, roughly -0.35..1.0. The buh spike peaks at each beat
## and a smaller dum spike follows dum_delay later.
func wave(t: float) -> float:
	var phase: float = fposmod(t, period)
	var d: float = phase if phase < period * 0.5 else phase - period
	return _spike(d, 1.0) + _spike(d - dum_delay, 0.55)


static func _spike(x: float, amp: float) -> float:
	var main: float = exp(-pow(x / _SPIKE_WIDTH, 2.0))
	var dip: float = exp(-pow((x - _SPIKE_WIDTH * 2.0) / _SPIKE_WIDTH, 2.0))
	return amp * (main - 0.35 * dip)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return
	var cx: float = w * 0.5
	var baseline: float = h * 0.62
	var amp: float = h * 0.4
	var px: float = w / seconds_visible

	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	var gx: float = fposmod(-now * px, px * 0.25)
	while gx < w:
		draw_line(Vector2(gx, 0), Vector2(gx, h), GRID_COLOR, 1.0)
		gx += px * 0.25
	draw_line(Vector2(0, baseline), Vector2(w, baseline), GRID_COLOR, 1.0)

	draw_rect(Rect2(cx - window * px, 0, window * px * 2.0, h), WINDOW_COLOR)
	draw_rect(Rect2(cx - perfect_window * px, 0, perfect_window * px * 2.0, h), PERFECT_COLOR)
	draw_line(Vector2(cx, 0), Vector2(cx, h), CENTER_COLOR, 2.0)

	var pts := PackedVector2Array()
	var x: float = 0.0
	while x <= w:
		pts.append(Vector2(x, baseline - wave(now + (x - cx) / px) * amp))
		x += 2.0
	draw_polyline(pts, LINE_COLOR, 2.5, true)

	for m: Dictionary in _markers:
		var mx: float = cx + (float(m.time) - now) * px
		var col: Color = GRADE_COLORS[m.grade]
		draw_line(Vector2(mx, baseline - amp - 6.0), Vector2(mx, baseline + 18.0), col, 2.0)
		draw_circle(Vector2(mx, baseline + 18.0), 5.0, col)

	_draw_heart(Vector2(cx, h * 0.14), minf(h, w) * 0.07 * _pulse())


## 1.0 at rest, swelling on the buh and a little on the dum.
func _pulse() -> float:
	var phase: float = fposmod(now, period)
	var buh: float = exp(-phase * 14.0)
	var dum: float = exp(-maxf(0.0, phase - dum_delay) * 14.0) * 0.5 if phase >= dum_delay else 0.0
	return 1.0 + 0.35 * maxf(buh, dum)


func _draw_heart(center: Vector2, radius: float) -> void:
	var pts := PackedVector2Array()
	for i: int in 48:
		var t: float = TAU * i / 48.0
		var hx: float = 16.0 * pow(sin(t), 3.0)
		var hy: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(center + Vector2(hx, -hy) * (radius / 16.0))
	draw_colored_polygon(pts, HEART_COLOR)
