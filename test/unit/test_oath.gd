extends GutTest

var rules: StageRules
var foe: BruteEnemy


func before_each() -> void:
	var map: StageMap = StageMap.build([StageChunk.from_rows(["....", "1...", "...."])])
	foe = BruteEnemy.new(Vector2i(0, 1), 100)
	rules = StageRules.new(map, 1, [foe])


func _hero() -> Hero:
	return rules.heroes[0]


func _action(kind: RuneAction.Kind, beat: int, attack: RuneAction.Attack = RuneAction.Attack.STANDARD) -> RuneAction:
	var a := RuneAction.new()
	a.kind = kind
	a.attack = attack
	a.beat = beat
	a.dir = Rune.Dir.UP
	return a


func test_odin_costs_max_hp() -> void:
	assert_eq(Oath.max_hp(Oath.Kind.ODIN), StageRules.HERO_HP - 10)
	assert_eq(Oath.max_hp(Oath.Kind.THOR), StageRules.HERO_HP)


func test_thor_heavy_hits_harder_and_exposes_for_two_commands() -> void:
	_hero().oath = Oath.Kind.THOR
	rules.act(0, _action(RuneAction.Kind.ATTACK, 1, RuneAction.Attack.HEAVY))
	assert_eq(foe.hp, BruteEnemy.MAX_HP - 30)
	rules.act(0, _action(RuneAction.Kind.BRACE, 3))
	assert_true(_hero().exposed, "still exposed after one command")
	rules.act(0, _action(RuneAction.Kind.BRACE, 5))
	assert_false(_hero().exposed)


func test_without_thor_heavy_exposes_for_one_command() -> void:
	rules.act(0, _action(RuneAction.Kind.ATTACK, 1, RuneAction.Attack.HEAVY))
	assert_eq(foe.hp, BruteEnemy.MAX_HP - 20)
	rules.act(0, _action(RuneAction.Kind.BRACE, 3))
	assert_false(_hero().exposed)


func test_tyr_blocks_heal_and_prayers_give_no_glory() -> void:
	_hero().oath = Oath.Kind.TYR
	_hero().hp = 40
	_hero().brace_until = 10
	var smash: EnemyMove = BruteEnemy.smash()
	rules._hit(_hero(), foe, smash, 5)
	assert_eq(_hero().hp, 40 + Oath.TYR_BLOCK_HEAL)
	var pray := _action(RuneAction.Kind.PRAY, 7)
	pray.glory = 2
	rules.act(0, pray)
	assert_eq(_hero().glory, 0)
