class_name Oath
extends RefCounted
## The god oath a lineage's Founder swears. It binds every hero of the line.
## Placeholder effects for the first pass; each has a boon and a cost.

enum Kind { NONE, ODIN, THOR, TYR }

const NAMES: Array[String] = ["No oath", "Odin's Oath", "Thor's Oath", "Tyr's Oath"]
const DESCRIPTIONS: Array[String] = [
	"Sworn to no god.",
	"Start each stage with a Prayer blessing (your next Prayer + Prayer gives double glory). -10 max HP.",
	"Heavy swings deal +10 damage, but leave you exposed for two commands instead of one.",
	"Every block heals 3 HP, but Prayer + Prayer gives no glory.",
]
const ODIN_HP_COST: int = 10
const THOR_HEAVY_BONUS: int = 10
const TYR_BLOCK_HEAL: int = 3


static func max_hp(kind: int) -> int:
	return StageRules.HERO_HP - (ODIN_HP_COST if kind == Kind.ODIN else 0)


static func heavy_bonus(kind: int) -> int:
	return THOR_HEAVY_BONUS if kind == Kind.THOR else 0


## How many commands a Heavy swing leaves the hero exposed for.
static func exposed_commands(kind: int) -> int:
	return 2 if kind == Kind.THOR else 1


static func block_heal(kind: int) -> int:
	return TYR_BLOCK_HEAL if kind == Kind.TYR else 0


static func prayer_glory_allowed(kind: int) -> bool:
	return kind != Kind.TYR


static func starts_with_prayer_blessing(kind: int) -> bool:
	return kind == Kind.ODIN
