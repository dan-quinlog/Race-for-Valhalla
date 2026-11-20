class_name Lineage
extends RefCounted
## A family line across runs: its name, the Founder's oath, and every hero
## sent out so far. Saved as JSON in user:// (see load_file / save_file).
## The first hero of a line is its Founder.

const SAVE_PATH: String = "user://lineage.json"
const HERO_NAMES: Array[String] = [
	"Ulf", "Sigrid", "Bjorn", "Astrid", "Halvar", "Freydis", "Eirik", "Gunnhild",
	"Ragnar", "Thyra", "Leif", "Ingrid", "Sten", "Ylva", "Orm", "Hild",
]

## How a hero's run ended.
enum Fate { FELL, COMPLETED_DRENG }

var name: String = ""
var oath: int = Oath.Kind.NONE
## One entry per hero: {name, arc, glory, fate, stage}.
var heroes: Array[Dictionary] = []


func _init(p_name: String = "", p_oath: int = Oath.Kind.NONE) -> void:
	name = p_name
	oath = p_oath


func total_glory() -> int:
	var total: int = 0
	for h: Dictionary in heroes:
		total += int(h.glory)
	return total


## A name for the line's next hero, not yet used if possible.
func next_hero_name(rng: RandomNumberGenerator) -> String:
	var used: Array = heroes.map(func(h: Dictionary) -> String: return h.name)
	var free: Array[String] = []
	free.assign(HERO_NAMES.filter(func(n: String) -> bool: return not used.has(n)))
	var pool: Array[String] = free if not free.is_empty() else HERO_NAMES
	return pool[rng.randi_range(0, pool.size() - 1)]


## Records a hero's run. `stage` is the stage they reached (1-based).
func record(hero_name: String, glory: int, fate: Fate, stage: int) -> void:
	heroes.append({"name": hero_name, "arc": "Dreng", "glory": glory, "fate": fate, "stage": stage})


static func describe_hero(h: Dictionary) -> String:
	var how: String = "fell in stage %d of the Dreng arc" % int(h.stage)
	if int(h.fate) == Fate.COMPLETED_DRENG:
		how = "completed the Dreng arc, relic in hand"
	elif int(h.stage) > DrengRun.STAGE_COUNT:
		how = "fell fighting the Jötunn"
	return "%s %s (%d glory)" % [h.name, how, int(h.glory)]


func to_dict() -> Dictionary:
	return {"name": name, "oath": oath, "heroes": heroes}


static func from_dict(d: Dictionary) -> Lineage:
	var line := Lineage.new(str(d.get("name", "")), int(d.get("oath", Oath.Kind.NONE)))
	for h: Variant in d.get("heroes", []):
		if h is Dictionary:
			line.heroes.append({
				"name": str(h.get("name", "?")),
				"arc": str(h.get("arc", "Dreng")),
				"glory": int(h.get("glory", 0)),
				"fate": int(h.get("fate", Fate.FELL)),
				"stage": int(h.get("stage", 1)),
			})
	return line


## Reads a lineage from `path`, or returns null if there is none (or it's
## unreadable).
static func load_file(path: String = SAVE_PATH) -> Lineage:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return null
	return from_dict(json.data)


func save_file(path: String = SAVE_PATH) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	return true


static func delete_file(path: String = SAVE_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
