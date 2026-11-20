extends GutTest

const TEST_PATH: String = "user://test_lineage.json"


func after_each() -> void:
	Lineage.delete_file(TEST_PATH)


func test_round_trips_through_a_file() -> void:
	var line := Lineage.new("House of Test", Oath.Kind.THOR)
	line.record("Ulf", 12, Lineage.Fate.FELL, 2)
	line.record("Sigrid", 40, Lineage.Fate.COMPLETED_DRENG, 4)
	assert_true(line.save_file(TEST_PATH))
	var loaded: Lineage = Lineage.load_file(TEST_PATH)
	assert_eq(loaded.name, "House of Test")
	assert_eq(loaded.oath, Oath.Kind.THOR)
	assert_eq(loaded.heroes.size(), 2)
	assert_eq(loaded.heroes[1].fate, Lineage.Fate.COMPLETED_DRENG)
	assert_eq(loaded.total_glory(), 52)


func test_missing_or_broken_file_loads_as_none() -> void:
	assert_null(Lineage.load_file(TEST_PATH))
	var f: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("not json")
	f.close()
	assert_null(Lineage.load_file(TEST_PATH))


func test_hero_names_avoid_repeats() -> void:
	var line := Lineage.new("L")
	for n: String in Lineage.HERO_NAMES.slice(1):
		line.record(n, 0, Lineage.Fate.FELL, 1)
	var rng := RandomNumberGenerator.new()
	assert_eq(line.next_hero_name(rng), Lineage.HERO_NAMES[0])


func test_describes_fates() -> void:
	assert_string_contains(Lineage.describe_hero({"name": "Ulf", "glory": 3, "fate": Lineage.Fate.FELL, "stage": 2}), "fell in stage 2")
	assert_string_contains(Lineage.describe_hero({"name": "Ulf", "glory": 3, "fate": Lineage.Fate.FELL, "stage": 4}), "Jötunn")
	assert_string_contains(Lineage.describe_hero({"name": "Ulf", "glory": 3, "fate": Lineage.Fate.COMPLETED_DRENG, "stage": 4}), "relic")
