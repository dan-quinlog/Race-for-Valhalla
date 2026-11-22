extends GutTest

const PadScene: PackedScene = preload("res://scenes/direction_pad.tscn")

var pad: DirectionPad


func before_each() -> void:
	pad = PadScene.instantiate()
	add_child_autofree(pad)


func test_layout_puts_runes_in_the_corners() -> void:
	var order: Array[String] = []
	for child: Node in pad.get_children():
		order.append(child.name)
	assert_eq(order, ["UpLeft", "Up", "UpRight", "Left", "Center", "Right", "DownLeft", "Down", "DownRight"])
	assert_string_contains(pad.rune_button(RuneCorner.Kind.PRAYER).text, "Prayer")
	assert_string_contains(pad.rune_button(RuneCorner.Kind.FLOURISH).text, "Flourish")


func test_presses_emit_direction_or_rune() -> void:
	watch_signals(pad)
	pad.dir_button(Rune.Dir.LEFT).button_down.emit()
	assert_signal_emitted_with_parameters(pad, "direction_pressed", [Rune.Dir.LEFT])
	pad.rune_button(RuneCorner.Kind.TRIP).button_down.emit()
	assert_signal_emitted_with_parameters(pad, "rune_pressed", [RuneCorner.Kind.TRIP])


func test_hints_and_rune_colors() -> void:
	pad.set_hints(["W", "S", "A", "D"], ["Q", "E", "Z", "C"])
	assert_string_contains(pad.dir_button(Rune.Dir.UP).text, "[W]")
	assert_string_contains(pad.rune_button(RuneCorner.Kind.HEAVY).text, "[E]")
	var border: Color = pad.rune_button(RuneCorner.Kind.HEAVY).get_theme_stylebox("normal").border_color
	assert_eq(border, RuneCorner.COLORS[RuneCorner.Kind.HEAVY])
