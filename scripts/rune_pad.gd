class_name RunePad
extends GridContainer
## Four rune buttons in a diamond, one at each point (up, down, left, right).
## Works as on-screen touch controls and as the input display. While a
## command's first rune is pending, that rune glows and the other buttons
## show what each follow-up would do.

signal rune_pressed(dir: Rune.Dir)

const BASE_COLOR := Color(1, 1, 1)
const PENDING_COLOR := Color(1.0, 0.8, 0.3)
const GRADE_FLASH := {
	BeatJudge.Grade.PERFECT: Color(1.0, 0.9, 0.4),
	BeatJudge.Grade.GOOD: Color(0.55, 0.85, 1.0),
	BeatJudge.Grade.MISS: Color(1.0, 0.35, 0.35),
}

var key_hints: Array[String] = ["", "", "", ""]
var pending: int = CommandReader.NO_RUNE

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


func button_text(d: Rune.Dir) -> String:
	var detail: String = Rune.ROLES[d]
	if pending != CommandReader.NO_RUNE:
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
	return PENDING_COLOR if d == pending else BASE_COLOR


func _refresh() -> void:
	for d: Rune.Dir in Rune.ALL:
		_buttons[d].text = button_text(d)
		_buttons[d].modulate = _rest_color(d)


func _on_button_down(d: Rune.Dir) -> void:
	rune_pressed.emit(d)
