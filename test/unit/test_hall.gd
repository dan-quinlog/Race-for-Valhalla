extends GutTest

const HallScene: PackedScene = preload("res://scenes/hall.tscn")


func _hall(existing: Lineage) -> Control:
	var hall: Control = partial_double(HallScene).instantiate()
	hall.save_path = "user://no_such_lineage.json"
	if existing != null:
		stub(hall, "load_lineage").to_return(existing)
	stub(hall, "save_lineage").to_do_nothing()
	stub(hall, "delete_lineage").to_do_nothing()
	stub(hall, "go_to_scene").to_do_nothing()
	add_child_autofree(hall)
	return hall


func after_each() -> void:
	DrengRun.current = null


func test_no_lineage_shows_the_founder_screen() -> void:
	var hall: Control = _hall(null)
	assert_true(hall.get_node("%Founder").visible)
	assert_false(hall.get_node("%HallPanel").visible)
	assert_eq(hall.get_node("%OathInfo").text, Oath.DESCRIPTIONS[Oath.Kind.ODIN])


func test_founding_saves_name_and_oath() -> void:
	var hall: Control = _hall(null)
	hall.get_node("%LineageName").text = "House of Ash"
	hall.get_node("%ThorButton").pressed.emit()
	assert_true(hall.get_node("%ThorButton").button_pressed)
	assert_false(hall.get_node("%OdinButton").button_pressed)
	hall.get_node("%FoundButton").pressed.emit()
	assert_called(hall, "save_lineage")
	assert_eq(hall.lineage.name, "House of Ash")
	assert_eq(hall.lineage.oath, Oath.Kind.THOR)
	assert_true(hall.get_node("%HallPanel").visible)
	assert_string_contains(hall.get_node("%Roster").text, "Founder awaits")


func test_hall_lists_heroes_and_sends_out_a_dreng() -> void:
	var line := Lineage.new("House of Ash", Oath.Kind.TYR)
	line.record("Ulf", 12, Lineage.Fate.FELL, 2)
	var hall: Control = _hall(line)
	assert_string_contains(hall.get_node("%LineageTitle").text, "Tyr's Oath")
	assert_string_starts_with(hall.get_node("%Roster").text, "Founder: Ulf fell in stage 2")
	hall.get_node("%NewDrengButton").pressed.emit()
	assert_eq(DrengRun.current.lineage, line)
	assert_called(hall, "go_to_scene", ["res://scenes/stage.tscn"])


func test_quick_run_has_no_lineage() -> void:
	var hall: Control = _hall(null)
	hall.get_node("%QuickButton").pressed.emit()
	assert_not_null(DrengRun.current)
	assert_null(DrengRun.current.lineage)


func test_abandon_needs_two_presses() -> void:
	var hall: Control = _hall(Lineage.new("L"))
	hall.get_node("%AbandonButton").pressed.emit()
	assert_not_called(hall, "delete_lineage")
	hall.get_node("%AbandonButton").pressed.emit()
	assert_called(hall, "delete_lineage")
	assert_null(hall.lineage)
	assert_true(hall.get_node("%Founder").visible)
