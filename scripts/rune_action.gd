class_name RuneAction
extends RefCounted
## A resolved two-beat command.
##
## First rune picks the kind, second rune picks the detail:
## - Movement (down) + dir: move that way.
## - Attack (left) + dir: down Trip, left Standard, up Heavy, right Defensive.
## - Defense (right) + dir: brace that way, blocking your room and attacks
##   coming from the adjacent room on that side.
## - Prayer (up) + rune: bless that rune's next action. Prayer + Prayer grants glory.

## CHARGE is the one-beat prototype's Heavy wind-up (TurnInput): the hero
## spends the beat charging and is exposed.
enum Kind { MOVE, ATTACK, BRACE, PRAY, CHARGE }
enum Attack { TRIP, STANDARD, HEAVY, DEFENSIVE }

const ATTACK_NAMES: Array[String] = ["Trip", "Standard attack", "Heavy attack", "Defensive attack"]
## Second rune -> attack type, indexed by Rune.Dir.
const ATTACK_BY_DIR: Array[Attack] = [Attack.HEAVY, Attack.TRIP, Attack.STANDARD, Attack.DEFENSIVE]

var kind: Kind
## The second rune: direction for MOVE/BRACE, the rune blessed for PRAY,
## and the modifier rune for ATTACK.
var dir: Rune.Dir
var attack: Attack = Attack.STANDARD
## Consumed a blessing from an earlier prayer.
var empowered: bool = false
var glory: int = 0
## Beat index the command completed on.
var beat: int = 0
## Both beats of the command were Perfect.
var perfect: bool = false
## For a charged Heavy (and CHARGE turns): beats spent charging so far.
var charge_beats: int = 0


func describe() -> String:
	var text: String
	match kind:
		Kind.MOVE:
			text = "Move %s" % Rune.DIR_NAMES[dir]
			if empowered:
				text += " (warded: ignores room damage)"
		Kind.ATTACK:
			text = ATTACK_NAMES[attack]
			if charge_beats > 0:
				text += " (charged %d)" % charge_beats
			if empowered:
				text += " (blessed: extra damage)"
		Kind.BRACE:
			text = "Brace %s" % Rune.DIR_NAMES[dir]
			if empowered:
				text += " (blessed: retaliate)"
		Kind.CHARGE:
			text = "Charging Heavy..." if charge_beats == 0 else "Charging Heavy (%d)" % charge_beats
		Kind.PRAY:
			if dir == Rune.Dir.UP:
				text = "Prayer for glory (+%d)" % glory
			else:
				text = "Prayer: bless %s" % Rune.ROLES[dir]
	if perfect:
		text += "  PERFECT"
	return text
