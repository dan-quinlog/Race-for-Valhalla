extends GutTest

const FightScene: PackedScene = preload("res://scenes/fight.tscn")

var fight: Control


func before_each() -> void:
	fight = partial_double(FightScene).instantiate()
	stub(fight, "go_to_scene").to_do_nothing()
	add_child_autofree(fight)
	await wait_process_frames(2)


func _period() -> float:
	return fight.panels[0].rhythm.judge.period


## Submits a two-rune command for a panel on beats `beat` and `beat + 1`.
func _command(panel: int, first: Rune.Dir, second: Rune.Dir, beat: int) -> void:
	fight.panels[panel].submit(first, _period() * beat)
	fight.panels[panel].submit(second, _period() * (beat + 1))


func test_starts_solo_with_one_hero() -> void:
	assert_false(fight.two_players)
	assert_false(fight.panels[1].visible)
	assert_eq(fight.rules.heroes.size(), 1)
	assert_eq(fight.get_node("%Arena").rules, fight.rules)


func test_completed_command_drives_the_fight() -> void:
	_command(0, Rune.Dir.DOWN, Rune.Dir.RIGHT, 1)  # move right
	assert_eq(fight.rules.heroes[0].room, 1)
	_command(0, Rune.Dir.LEFT, Rune.Dir.LEFT, 3)  # standard attack, perfect
	assert_eq(fight.rules.enemy.hp, FightRules.ENEMY_HP - 15)
	assert_string_contains(fight.get_node("%FightLog").text, "Standard attack for 15")


func test_beat_closing_advances_enemy() -> void:
	fight._on_beat_closed(FightRules.FIRST_ENEMY_BEAT)
	assert_true(fight.rules.enemy.is_winding())
	assert_string_contains(fight.get_node("%FightLog").text, "winds up")


func test_two_players_gives_two_heroes() -> void:
	fight.set_two_players(true)
	assert_true(fight.panels[1].visible)
	assert_eq(fight.rules.heroes.size(), 2)
	_command(1, Rune.Dir.DOWN, Rune.Dir.LEFT, 1)
	assert_eq(fight.rules.heroes[1].room, 1)
	assert_eq(fight.rules.heroes[0].room, 0)


func test_victory_shows_banner() -> void:
	fight.rules.heroes[0].room = 1
	fight.rules.enemy.hp = 1
	_command(0, Rune.Dir.LEFT, Rune.Dir.LEFT, 1)
	assert_true(fight.rules.won)
	assert_string_starts_with(fight.get_node("%Banner").text, "Victory")


func test_restart_resets_fight() -> void:
	fight.rules.enemy.hp = 10
	fight.restart()
	assert_eq(fight.rules.enemy.hp, FightRules.ENEMY_HP)
	assert_eq(fight.get_node("%FightLog").text, "")


func test_lab_button_changes_scene() -> void:
	fight.get_node("%LabButton").pressed.emit()
	assert_called(fight, "go_to_scene", ["res://scenes/rhythm_lab.tscn"])


func test_arena_tags_show_hero_state() -> void:
	var hero := Hero.new(0, 60, 0)
	assert_eq(ArenaView.hero_tags(hero, 3), "")
	hero.brace_until = 4
	hero.brace_blessed = true
	hero.exposed = true
	assert_eq(ArenaView.hero_tags(hero, 3), "BRACE+ EXPOSED")
	hero.hp = 0
	assert_eq(ArenaView.hero_tags(hero, 3), "FALLEN")


func test_arena_rooms_split_width() -> void:
	var arena: ArenaView = fight.get_node("%Arena")
	var left: Rect2 = arena.room_rect(0)
	var right: Rect2 = arena.room_rect(2)
	assert_almost_eq(left.position.x, 0.0, 0.01)
	assert_almost_eq(right.end.x, arena.size.x, 0.5)
