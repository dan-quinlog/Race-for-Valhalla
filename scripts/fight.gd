extends Control
## First fight: one or two heroes against one enemy on a strip of three rooms.
## Input routing matches the Rhythm Lab: P1 is WASD and gamepad 1, P2 the
## arrow keys and gamepad 2, and solo mode sends every input set to P1.

const BPM: float = 90.0
const WINDOW: float = 0.15
const PERFECT_WINDOW: float = 0.04
const LOG_LENGTH: int = 6
const LAB_SCENE: String = "res://scenes/rhythm_lab.tscn"

const KEY_HINTS_P1: Array[String] = ["W", "S", "A", "D"]
const KEY_HINTS_P2: Array[String] = ["↑", "↓", "←", "→"]
const KEY_HINTS_SOLO: Array[String] = ["W / ↑", "S / ↓", "A / ←", "D / →"]

var two_players: bool = false
var rules: FightRules
var log_lines: Array[String] = []

@onready var _clock: BeatClock = %BeatClock
@onready var _ekg: EkgDisplay = %Ekg
@onready var _arena: ArenaView = %Arena
@onready var _banner: Label = %Banner
@onready var _fight_log: Label = %FightLog
@onready var _two_players_toggle: CheckButton = %TwoPlayers
@onready var panels: Array[PlayerPanel] = [%Player1, %Player2]


func _ready() -> void:
	for p: PlayerPanel in panels:
		p.clock = _clock
		p.judged.connect(_on_judged)
		p.acted.connect(_on_acted)
	_clock.beat.connect(_on_beat)
	_clock.beat_closed.connect(_on_beat_closed)
	%RestartButton.pressed.connect(restart)
	%LabButton.pressed.connect(open_lab)
	_two_players_toggle.toggled.connect(set_two_players)
	_two_players_toggle.visible = not OS.has_feature("mobile")
	set_two_players(false)


func restart() -> void:
	_clock.bpm = BPM
	_clock.dum_delay = WINDOW
	_clock.start()
	for p: PlayerPanel in panels:
		p.configure(_clock.period, WINDOW, PERFECT_WINDOW)
	_ekg.configure(_clock.period, WINDOW, WINDOW, PERFECT_WINDOW)
	rules = FightRules.new(2 if two_players else 1)
	rules.logged.connect(_on_logged)
	rules.ended.connect(_on_ended)
	_arena.rules = rules
	log_lines.clear()
	_fight_log.text = ""
	_banner.text = "Slay the %s! Move into its room to strike." % rules.enemy.display_name


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
	rules.close_beat(index)


func _on_acted(action: RuneAction, player: int) -> void:
	rules.act(player, action)


func _on_judged(t: float, grade: BeatJudge.Grade, player: int) -> void:
	_ekg.add_marker(t, grade, player)


func _on_logged(text: String) -> void:
	log_lines.push_front(text)
	if log_lines.size() > LOG_LENGTH:
		log_lines.pop_back()
	_fight_log.text = "\n".join(log_lines)


func _on_ended(won: bool) -> void:
	if won:
		_banner.text = "Victory! The %s falls. Glory awaits." % rules.enemy.display_name
	else:
		_banner.text = "You have fallen. Press Restart to fight again."
