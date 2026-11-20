extends Control
## Plays a DrengRun: one or two heroes fight through generated stages of
## encounters and hazards on a 3-lane grid to each exit door, rest between
## stages, and face the Jötunn at the end. Health and glory carry over.
## A fallen hero's pad shows their final strikes until their final beat.
## When the run ends, a lineage run is recorded and saved, and the hall
## button appears. A quick run (no lineage) keeps the Restart and Boss
## shortcuts for testing.
## Input routing matches the Rhythm Lab: P1 is WASD and gamepad 1, P2 the
## arrow keys and gamepad 2, and solo mode sends every input set to P1.

const BPM: float = 90.0
const WINDOW: float = 0.15
const PERFECT_WINDOW: float = 0.04
const LOG_LENGTH: int = 6
const LAB_SCENE: String = "res://scenes/rhythm_lab.tscn"
const HALL_SCENE: String = "res://scenes/hall.tscn"
## Seconds between clearing a stage and entering the next.
const NEXT_STAGE_DELAY: float = 3.0

const KEY_HINTS_P1: Array[String] = ["W", "S", "A", "D"]
const KEY_HINTS_P2: Array[String] = ["↑", "↓", "←", "→"]
const KEY_HINTS_SOLO: Array[String] = ["W / ↑", "S / ↓", "A / ←", "D / →"]

var two_players: bool = false
var run: DrengRun
var stage_index: int = 0
var rules: StageRules
var log_lines: Array[String] = []

@onready var _clock: BeatClock = %BeatClock
@onready var _ekg: EkgDisplay = %Ekg
@onready var _view: StageView = %StageView
@onready var _banner: Label = %Banner
@onready var _stage_log: Label = %StageLog
@onready var _two_players_toggle: CheckButton = %TwoPlayers
@onready var _hall_button: Button = %HallButton
@onready var panels: Array[PlayerPanel] = [%Player1, %Player2]


func _ready() -> void:
	# Take the run the hall set up (a quick run if there is none), once.
	run = DrengRun.current if DrengRun.current != null else DrengRun.new(null, randi())
	DrengRun.current = null
	for p: PlayerPanel in panels:
		p.clock = _clock
		p.judged.connect(_on_judged)
		p.acted.connect(_on_acted)
		p.pending_changed.connect(_on_pending_changed)
		p.final_struck.connect(_on_final_input)
	_clock.beat.connect(_on_beat)
	_clock.beat_closed.connect(_on_beat_closed)
	%RestartButton.pressed.connect(restart)
	%BossButton.pressed.connect(start_boss)
	%LabButton.pressed.connect(open_lab)
	_hall_button.pressed.connect(open_hall)
	var quick: bool = run.lineage == null
	%RestartButton.visible = quick
	%BossButton.visible = quick
	_two_players_toggle.toggled.connect(set_two_players)
	_two_players_toggle.visible = not OS.has_feature("mobile")
	set_two_players(false)


func restart() -> void:
	start_stage(0)


## Starts stage `index` with fresh heroes.
func start_stage(index: int) -> void:
	_load_stage(index, [])


## Jumps straight to the boss with fresh heroes (a testing shortcut).
func start_boss() -> void:
	start_stage(DrengRun.STAGE_COUNT)


## Rests (heals living heroes REST_HEAL) and moves on to the next stage,
## carrying the heroes over.
func advance_stage() -> void:
	if stage_index + 1 < run.stage_count():
		for h: Hero in rules.heroes:
			if h.is_alive():
				h.hp = mini(h.max_hp, h.hp + DrengRun.REST_HEAL)
		_load_stage(stage_index + 1, rules.heroes)


## Loads stage `index`. Heroes from `carry` keep their health and glory
## (a fallen one stays fallen).
func _load_stage(index: int, carry: Array[Hero]) -> void:
	stage_index = index
	_clock.bpm = BPM
	_clock.dum_delay = WINDOW
	_clock.start()
	for p: PlayerPanel in panels:
		p.configure(_clock.period, WINDOW, PERFECT_WINDOW)
	_ekg.configure(_clock.period, WINDOW, WINDOW, PERFECT_WINDOW)
	rules = StageRules.new(StageMap.build(run.stage_chunks(index)), 2 if two_players else 1)
	var oath: int = run.oath()
	for h: Hero in rules.heroes:
		h.display_name = run.hero_names[h.player]
		h.oath = oath
		h.max_hp = Oath.max_hp(oath)
		h.hp = h.max_hp
		panels[h.player].set_title("P%d: %s" % [h.player + 1, h.display_name])
		if Oath.starts_with_prayer_blessing(oath):
			panels[h.player].bless(Rune.Dir.UP)
	for i: int in mini(carry.size(), rules.heroes.size()):
		rules.heroes[i].hp = mini(carry[i].hp, rules.heroes[i].max_hp)
		rules.heroes[i].glory = carry[i].glory
		if not rules.heroes[i].is_alive():
			panels[i].mark_fallen()
	rules.logged.connect(_on_logged)
	rules.ended.connect(_on_ended)
	rules.door_opened.connect(_on_door_opened)
	rules.hero_fell.connect(_on_hero_fell)
	rules.final_struck.connect(_on_final_struck)
	_view.rules = rules
	log_lines.clear()
	_stage_log.text = ""
	_banner.text = run.banner(index)
	_hall_button.visible = run.lineage == null


## Side-effect wrapper so tests can stub out the delay.
func schedule_next_stage() -> void:
	get_tree().create_timer(NEXT_STAGE_DELAY).timeout.connect(advance_stage)


## Side-effect wrapper so tests can stub out file access.
func save_lineage() -> void:
	run.lineage.save_file()


func set_two_players(on: bool) -> void:
	two_players = on
	panels[1].visible = on
	panels[0].set_key_hints(KEY_HINTS_P1 if on else KEY_HINTS_SOLO)
	panels[1].set_key_hints(KEY_HINTS_P2)
	if _two_players_toggle.button_pressed != on:
		_two_players_toggle.set_pressed_no_signal(on)
	restart()


## Which panel an input set drives. Solo mode routes every set to P1.
func panel_for_input(input_player: int) -> int:
	return input_player if two_players else 0


func open_lab() -> void:
	go_to_scene(LAB_SCENE)


func open_hall() -> void:
	go_to_scene(HALL_SCENE)


## Side-effect wrapper so tests can stub out scene changes.
func go_to_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _process(_delta: float) -> void:
	_ekg.set_time(_clock.now())


func _unhandled_input(event: InputEvent) -> void:
	for input_player: int in 2:
		for d: Rune.Dir in Rune.ALL:
			if event.is_action_pressed(Rune.action_name(input_player, d)):
				panels[panel_for_input(input_player)].submit(d, _clock.input_time())
				get_viewport().set_input_as_handled()
				return


func _on_beat(index: int) -> void:
	for p: PlayerPanel in panels:
		p.on_beat(index)


func _on_beat_closed(index: int) -> void:
	for p: PlayerPanel in panels:
		p.on_beat_closed(index)
	rules.close_beat(index)
	for h: Hero in rules.heroes:
		if h.has_final_strike():
			panels[h.player].update_final(rules.final_preview(h))


func _on_pending_changed(rune: int, player: int) -> void:
	_view.set_aura(player, rune)


func _on_acted(action: RuneAction, player: int) -> void:
	rules.act(player, action)


func _on_judged(t: float, grade: BeatJudge.Grade, player: int) -> void:
	_ekg.add_marker(t, grade, player)


func _on_logged(text: String) -> void:
	log_lines.push_front(text)
	if log_lines.size() > LOG_LENGTH:
		log_lines.pop_back()
	_stage_log.text = "\n".join(log_lines)


func _on_hero_fell(player: int, final_beat: int) -> void:
	panels[player].begin_final(final_beat, rules.final_preview(rules.heroes[player]))
	_ekg.add_final_marker(final_beat * _clock.period, player)


func _on_final_input(dir: Rune.Dir, beat: int, perfect: bool, blessed: bool, player: int) -> void:
	rules.final_strike(player, dir, beat, perfect, blessed)


func _on_final_struck(player: int) -> void:
	panels[player].end_final()


func _on_door_opened() -> void:
	_banner.text = "The exit door is open! Everyone to the door."


func _on_ended(won: bool) -> void:
	if won and not run.is_boss(stage_index):
		_banner.text = "Through the door! You rest by the fire (+%d HP) before pressing on..." % DrengRun.REST_HEAL
		schedule_next_stage()
		return
	var glory: Array[String] = []
	for h: Hero in rules.heroes:
		glory.append("%s %d" % [h.display_name, h.glory])
	if won and rules.living_heroes().size() > 0:
		_banner.text = "The relic of your ancestors is yours! The Dreng arc is complete. Glory: %s" % ", ".join(glory)
	elif won:
		_banner.text = "Victory in death! The relic is won and Valhalla opens its doors. Glory: %s" % ", ".join(glory)
	else:
		_banner.text = "You have fallen in stage %d. Valhalla takes note. Glory: %s" % [stage_index + 1, ", ".join(glory)]
	if run.record(rules.heroes, won, stage_index):
		save_lineage()
	_hall_button.visible = true
