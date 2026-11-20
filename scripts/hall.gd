extends Control
## The hall of the lineage, and the game's first screen. With no lineage
## saved, the player founds one: names it and swears the Founder's oath.
## With one, it shows the line's heroes and glory, and sends the next hero
## out on the Dreng arc. A quick run (no lineage, nothing saved) and the
## Rhythm Lab are always available.

const STAGE_SCENE: String = "res://scenes/stage.tscn"
const LAB_SCENE: String = "res://scenes/rhythm_lab.tscn"
const OATHS: Array[int] = [Oath.Kind.ODIN, Oath.Kind.THOR, Oath.Kind.TYR]
const DEFAULT_NAME: String = "House of the Wolf"

var lineage: Lineage
## Where the lineage is saved. Tests point this elsewhere.
var save_path: String = Lineage.SAVE_PATH
var chosen_oath: int = Oath.Kind.ODIN
## The abandon button was pressed once and waits for a second press.
var confirm_abandon: bool = false

@onready var _founder: Control = %Founder
@onready var _hall: Control = %HallPanel
@onready var _name_edit: LineEdit = %LineageName
@onready var _oath_buttons: Array[Button] = [%OdinButton, %ThorButton, %TyrButton]
@onready var _oath_info: Label = %OathInfo
@onready var _lineage_title: Label = %LineageTitle
@onready var _roster: Label = %Roster
@onready var _abandon: Button = %AbandonButton


func _ready() -> void:
	for i: int in OATHS.size():
		_oath_buttons[i].text = Oath.NAMES[OATHS[i]]
		_oath_buttons[i].pressed.connect(choose_oath.bind(OATHS[i]))
	%FoundButton.pressed.connect(found)
	%NewDrengButton.pressed.connect(start_dreng)
	_abandon.pressed.connect(abandon)
	%QuickButton.pressed.connect(quick_run)
	%LabButton.pressed.connect(go_to_scene.bind(LAB_SCENE))
	lineage = load_lineage()
	choose_oath(chosen_oath)
	_refresh()


## Side-effect wrappers so tests can stub out file access and scene changes.
func load_lineage() -> Lineage:
	return Lineage.load_file(save_path)


func save_lineage() -> void:
	lineage.save_file(save_path)


func delete_lineage() -> void:
	Lineage.delete_file(save_path)


func go_to_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)


func choose_oath(kind: int) -> void:
	chosen_oath = kind
	for i: int in OATHS.size():
		_oath_buttons[i].set_pressed_no_signal(OATHS[i] == kind)
	_oath_info.text = Oath.DESCRIPTIONS[kind]


## Founds a new lineage with the entered name and the chosen oath.
func found() -> void:
	var line_name: String = _name_edit.text.strip_edges()
	lineage = Lineage.new(line_name if line_name != "" else DEFAULT_NAME, chosen_oath)
	save_lineage()
	_refresh()


## Sends the line's next hero out on the Dreng arc.
func start_dreng() -> void:
	DrengRun.current = DrengRun.new(lineage, randi())
	go_to_scene(STAGE_SCENE)


func quick_run() -> void:
	DrengRun.current = DrengRun.new(null, randi())
	go_to_scene(STAGE_SCENE)


## Deletes the lineage. Needs two presses.
func abandon() -> void:
	if not confirm_abandon:
		confirm_abandon = true
		_abandon.text = "Really end this line? Press again."
		return
	confirm_abandon = false
	delete_lineage()
	lineage = null
	_refresh()


func _refresh() -> void:
	_founder.visible = lineage == null
	_hall.visible = lineage != null
	_abandon.text = "Abandon the lineage"
	if lineage == null:
		return
	_lineage_title.text = "%s, sworn by %s. Glory of the line: %d" % [lineage.name, Oath.NAMES[lineage.oath], lineage.total_glory()]
	var lines: Array[String] = []
	for i: int in lineage.heroes.size():
		var prefix: String = "Founder: " if i == 0 else ""
		lines.append(prefix + Lineage.describe_hero(lineage.heroes[i]))
	_roster.text = "\n".join(lines) if not lines.is_empty() else "No hero has gone out yet. The Founder awaits."
