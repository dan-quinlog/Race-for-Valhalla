class_name DirectionPad
extends GridContainer
## On-screen controls for the one-action-per-beat prototype, laid out like
## the keyboard: a 3x3 grid with the four directions on the edges and the
## four corner runes (RuneCorner) between them. Tapping a corner is the
## same as pressing its two directions together. Works as touch controls
## and as the input display.

signal direction_pressed(dir: Rune.Dir)
signal rune_pressed(kind: RuneCorner.Kind)

const DIRECTION_FILL := Color(0.24, 0.22, 0.2)
const REST_DARKEN: float = 0.55
const GRADE_FLASH := {
	BeatJudge.Grade.PERFECT: Color(1.0, 0.9, 0.4),
	BeatJudge.Grade.GOOD: Color(0.55, 0.85, 1.0),
	BeatJudge.Grade.MISS: Color(1.0, 0.35, 0.35),
}
const ARROWS: Array[String] = ["▲", "▼", "◀", "▶"]

## Key hints per Rune.Dir and per RuneCorner.Kind.
var dir_hints: Array[String] = ["", "", "", ""]
var rune_hints: Array[String] = ["", "", "", ""]

@onready var _dir_buttons: Array[Button] = [%Up, %Down, %Left, %Right]
@onready var _rune_buttons: Array[Button] = [%UpLeft, %UpRight, %DownLeft, %DownRight]
@onready var _center: Label = %Center


func _ready() -> void:
	for d: Rune.Dir in Rune.ALL:
		_dir_buttons[d].button_down.connect(func() -> void: direction_pressed.emit(d))
	for k: RuneCorner.Kind in RuneCorner.ALL:
		_rune_buttons[k].button_down.connect(func() -> void: rune_pressed.emit(k))
	_refresh()


func set_hints(dirs: Array[String], runes: Array[String]) -> void:
	dir_hints = dirs
	rune_hints = runes
	if is_node_ready():
		_refresh()


func set_center_text(text: String) -> void:
	_center.text = text


func dir_button(d: Rune.Dir) -> Button:
	return _dir_buttons[d]


func rune_button(k: RuneCorner.Kind) -> Button:
	return _rune_buttons[k]


func flash_dir(d: Rune.Dir, grade: BeatJudge.Grade) -> void:
	_flash(_dir_buttons[d], grade)


func flash_rune(k: RuneCorner.Kind, grade: BeatJudge.Grade) -> void:
	_flash(_rune_buttons[k], grade)


func _flash(b: Button, grade: BeatJudge.Grade) -> void:
	b.modulate = GRADE_FLASH[grade]
	create_tween().tween_property(b, "modulate", Color(1, 1, 1), 0.25)


func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	return s


func _paint(b: Button, fill: Color, border: Color) -> void:
	b.add_theme_stylebox_override("normal", _style(fill, border))
	b.add_theme_stylebox_override("hover", _style(fill.lightened(0.12), border))
	b.add_theme_stylebox_override("pressed", _style(fill.lightened(0.3), border))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(key, Color(0.95, 0.93, 0.9))


func _refresh() -> void:
	for d: Rune.Dir in Rune.ALL:
		var text: String = ARROWS[d]
		if dir_hints[d] != "":
			text += "\n[%s]" % dir_hints[d]
		_dir_buttons[d].text = text
		_paint(_dir_buttons[d], DIRECTION_FILL, Color(0.5, 0.47, 0.42))
	for k: RuneCorner.Kind in RuneCorner.ALL:
		var text: String = "%s\n%s" % [RuneCorner.NAMES[k], RuneCorner.ROLES[k]]
		if rune_hints[k] != "":
			text += "\n[%s]" % rune_hints[k]
		_rune_buttons[k].text = text
		_paint(_rune_buttons[k], RuneCorner.COLORS[k].darkened(REST_DARKEN), RuneCorner.COLORS[k])
