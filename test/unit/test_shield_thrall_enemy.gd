extends GutTest

var stage: StageRules
var thrall: ShieldThrallEnemy


func before_each() -> void:
	var map: StageMap = StageMap.build([StageChunk.from_rows(["....", "1...", "...."])])
	thrall = ShieldThrallEnemy.new(Vector2i(0, 1))
	stage = StageRules.new(map, 1, [thrall])


func _attack(attack: RuneAction.Attack, beat: int) -> void:
	var a := RuneAction.new()
	a.kind = RuneAction.Kind.ATTACK
	a.attack = attack
	a.beat = beat
	stage.act(0, a)


func test_shield_halves_standard_hits() -> void:
	_attack(RuneAction.Attack.STANDARD, 1)
	assert_eq(thrall.hp, ShieldThrallEnemy.MAX_HP - 5)


func test_heavy_knocks_shield_down_and_lands_in_full() -> void:
	_attack(RuneAction.Attack.HEAVY, 1)
	assert_eq(thrall.hp, ShieldThrallEnemy.MAX_HP - 20)
	assert_false(thrall.is_shielded(3))
	_attack(RuneAction.Attack.STANDARD, 3)
	assert_eq(thrall.hp, ShieldThrallEnemy.MAX_HP - 30, "open for follow-ups")
	assert_true(thrall.is_shielded(1 + ShieldThrallEnemy.SHIELD_DOWN_BEATS + 1), "the shield comes back up")


func test_trip_opens_the_shield() -> void:
	_attack(RuneAction.Attack.TRIP, 1)
	assert_eq(thrall.hp, ShieldThrallEnemy.MAX_HP - 4)
	_attack(RuneAction.Attack.STANDARD, 3)
	assert_eq(thrall.hp, ShieldThrallEnemy.MAX_HP - 14)


func test_alternates_closing_in_and_thrusting_two_zones() -> void:
	thrall.cell = Vector2i(3, 1)
	thrall.try_act(0, stage)
	assert_eq(thrall.cell, Vector2i(2, 1))
	assert_false(thrall.is_winding())
	thrall.try_act(2, stage)
	assert_eq(thrall.current.display_name, "Spear Thrust")
	assert_eq(thrall.targets, [Vector2i(2, 1), Vector2i(1, 1)])
