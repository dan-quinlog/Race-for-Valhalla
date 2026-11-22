class_name RunePad
extends GridContainer
## Four rune buttons in a diamond, one at each point (up, down, left, right),
## each in its rune's color (Rune.COLORS). Works as on-screen touch controls
## and as the input display. While a command's first rune is pending, that
## rune lights up and the other buttons show what each follow-up would do.

signal rune_pressed(dir: Rune.Dir)

const BASE_COLOR := Color(1, 1, 1)
## How dark a rune button's fill is at rest, and when its rune is pending.
const REST_DARKEN: float = 0.6
const PENDING_DARKEN: float = 0.1
const FINAL_COLOR := Color(0.75, 0.75, 0.8)
const FINAL_BEST_COLOR := Color(1.0, 1.0, 1.0)
const GRADE_FLASH := {
	BeatJudge.Grade.PERFECT: Color(1.0, 0.9, 0.4),
	BeatJudge.Grade.GOOD: Color(0.55, 0.85, 1.0),
	BeatJudge.Grade.MISS: Color(1.0, 0.35, 0.35),
}

var key_hints: Array[String] = ["", "", "", ""]
var pending: int = CommandReader.NO_RUNE
## While a fallen hero picks a final strike: one label per Rune.Dir.
var final_labels: Array[String] = []
## Rune.Dir of the strongest final strike, highlighted.
var final_best: int = -1

@onready var _buttons: Array[Button] = [%Up, %Down, %Left, %Right]
@onready var _center: Label = %Center


func _ready() -> void:
	for d: Rune.Dir in Rune.ALL:
		_buttons[d].button_down.connect(_on_button_down.bind(d))
	_refresh()


func set_key_hints(hints: Array[String]) -> void:
	key_hints = hints
	if is_node_ready():
		_refresh()


func set_center_text(text: String) -> void:
	_center.text = text


func show_pending(first: Rune.Dir) -> void:
	pending = first
	_refresh()


func clear_pending() -> void:
	pending = CommandReader.NO_RUNE
	_refresh()


## Shows the final strike options in place of the runes' roles.
func show_final(labels: Array[String], best: int) -> void:
	final_labels = labels
	final_best = best
	pending = CommandReader.NO_RUNE
	_refresh()


func clear_final() -> void:
	final_labels = []
	final_best = -1
	_refresh()


func button_text(d: Rune.Dir) -> String:
	var detail: String = Rune.ROLES[d]
	if not final_labels.is_empty():
		detail = final_labels[d]
	elif pending != CommandReader.NO_RUNE:
		detail = CommandReader.options_for(pending as Rune.Dir)[d]
	var text: String = "%s\n%s" % [Rune.NAMES[d], detail]
	if key_hints[d] != "":
		text += "\n[%s]" % key_hints[d]
	return text


func flash(d: Rune.Dir, grade: BeatJudge.Grade) -> void:
	var b: Button = _buttons[d]
	b.modulate = GRADE_FLASH[grade]
	var tween: Tween = create_tween()
	tween.tween_property(b, "modulate", _rest_color(d), 0.25)


func _rest_color(d: Rune.Dir) -> Color:
	if not final_labels.is_empty():
		return FINAL_BEST_COLOR if d == final_best else FINAL_COLOR
	return BASE_COLOR


## The fill for rune `d`: its color, darkened unless it's the pending rune.
## Final strike mode uses neutral grey.
func fill_color(d: Rune.Dir) -> Color:
	if not final_labels.is_empty():
		return Color(0.3, 0.3, 0.34)
	return Rune.COLORS[d].darkened(PENDING_DARKEN if d == pending else REST_DARKEN)


func _style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(6)
	return s


func _refresh() -> void:
	for d: Rune.Dir in Rune.ALL:
		var b: Button = _buttons[d]
		b.text = button_text(d)
		b.modulate = _rest_color(d)
		var lit: bool = d == pending and final_labels.is_empty()
		var fill: Color = fill_color(d)
		var border: Color = Color(1, 1, 1) if lit else Rune.COLORS[d]
		var width: int = 4 if lit else 2
		b.add_theme_stylebox_override("normal", _style(fill, border, width))
		b.add_theme_stylebox_override("hover", _style(fill.lightened(0.12), border, width))
		b.add_theme_stylebox_override("pressed", _style(fill.lightened(0.3), border, width))
		var text: Color = Color(0.08, 0.06, 0.04) if lit else Color(0.95, 0.93, 0.9)
		for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(key, text)


func _on_button_down(d: Rune.Dir) -> void:
	rune_pressed.emit(d)
