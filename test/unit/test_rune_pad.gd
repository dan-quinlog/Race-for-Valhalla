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
