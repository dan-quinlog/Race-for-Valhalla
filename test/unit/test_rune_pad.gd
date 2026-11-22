extends GutTest

const PadScene: PackedScene = preload("res://scenes/rune_pad.tscn")

var pad: RunePad


func before_each() -> void:
	pad = PadScene.instantiate()
	add_child_autofree(pad)


func test_buttons_show_rune_role_and_key() -> void:
	pad.set_key_hints(["W", "S", "A", "D"])
	assert_eq(pad.get_node("%Left").text, "Tiwaz\nAttack\n[A]")
	assert_eq(pad.get_node("%Up").text, "Ansuz\nPrayer\n[W]")


func test_diamond_layout_has_runes_at_points() -> void:
	var order: Array[String] = []
	for child: Node in pad.get_children():
		order.append(child.name)
	assert_eq(order, ["SpacerTL", "Up", "SpacerTR", "Left", "Center", "Right", "SpacerBL", "Down", "SpacerBR"])
	assert_eq(pad.columns, 3)


func test_pending_shows_follow_up_options() -> void:
	pad.show_pending(Rune.Dir.LEFT)
	assert_string_contains(pad.get_node("%Up").text, "Heavy")
	assert_string_contains(pad.get_node("%Down").text, "Trip")
	pad.clear_pending()
	assert_string_contains(pad.get_node("%Up").text, "Prayer")


func test_button_press_emits_rune() -> void:
	watch_signals(pad)
	pad.get_node("%Right").button_down.emit()
	assert_signal_emitted_with_parameters(pad, "rune_pressed", [Rune.Dir.RIGHT])


func test_final_mode_shows_strikes_and_highlights_best() -> void:
	var labels: Array[String] = ["Throw 30", "Strike 25", "Flurry 60", "Charge 60"]
	pad.show_pending(Rune.Dir.LEFT)
	pad.show_final(labels, Rune.Dir.LEFT)
	assert_eq(pad.pending, CommandReader.NO_RUNE)
	assert_string_contains(pad.button_text(Rune.Dir.LEFT), "Flurry 60")
	assert_eq(pad.get_node("%Left").modulate, RunePad.FINAL_BEST_COLOR)
	assert_eq(pad.get_node("%Up").modulate, RunePad.FINAL_COLOR)
	pad.clear_final()
	assert_string_contains(pad.button_text(Rune.Dir.LEFT), "Attack")


func test_runes_are_color_coded_and_pending_lights_up() -> void:
	var fill: Color = pad.get_node("%Left").get_theme_stylebox("normal").bg_color
	assert_eq(fill, Rune.COLORS[Rune.Dir.LEFT].darkened(RunePad.REST_DARKEN))
	pad.show_pending(Rune.Dir.LEFT)
	fill = pad.get_node("%Left").get_theme_stylebox("normal").bg_color
	assert_eq(fill, Rune.COLORS[Rune.Dir.LEFT].darkened(RunePad.PENDING_DARKEN))
	assert_eq(pad.fill_color(Rune.Dir.UP), Rune.COLORS[Rune.Dir.UP].darkened(RunePad.REST_DARKEN))


func test_drag_reports_the_rune_under_the_finger_and_the_release() -> void:
	await wait_process_frames(2)
	watch_signals(pad)
	pad.get_node("%Down").button_down.emit()
	assert_true(pad.dragging)
	pad.drag_to(pad.get_node("%Down").get_global_rect().get_center())
	assert_signal_not_emitted(pad, "pointed", "still over the pressed rune")
	pad.drag_to(pad.get_node("%Left").get_global_rect().get_center())
	assert_signal_emitted_with_parameters(pad, "pointed", [Rune.Dir.LEFT])
	pad.end_drag()
	assert_signal_emitted(pad, "released")
	assert_false(pad.dragging)


func test_pointed_direction_is_outlined() -> void:
	pad.show_pending(Rune.Dir.DOWN)
	pad.show_pointed(Rune.Dir.LEFT)
	var border: Color = pad.get_node("%Left").get_theme_stylebox("normal").border_color
	assert_eq(border, Color(1, 1, 1))
	pad.clear_pending()
	assert_eq(pad.pointed_dir, -1)
