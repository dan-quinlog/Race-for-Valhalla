class_name StageChunk
extends Resource
## A hand-authored slice of a stage: three lanes of zones written as text.
## Stages are built by stitching chunks left to right (StageMap.build), so
## chunks can later be shuffled into generated stages.
##
## One character per zone:
##   .  open zone
##   #  wall (no one can enter)
##   F  fire trap zone (every F in a column burns together)
##   D  exit door
##   1  player 1 start, 2 player 2 start
##   B  brute enemy, R  ranger enemy

const LANES: int = 3
const ZONE_CHARS: String = ".#FD12BR"

## Lane strings, back lane (top of the screen) first. All the same length.
@export var rows: PackedStringArray = PackedStringArray(["", "", ""])
## The camera locks on this chunk until its enemies are cleared.
@export var encounter: bool = false


static func from_rows(p_rows: Array[String], p_encounter: bool = false) -> StageChunk:
	var chunk := StageChunk.new()
	chunk.rows = PackedStringArray(p_rows)
	chunk.encounter = p_encounter
	return chunk


func width() -> int:
	return rows[0].length() if rows.size() > 0 else 0


## Returns "" when the chunk is well formed, or a description of the problem.
func validate() -> String:
	if rows.size() != LANES:
		return "chunk needs %d lanes, has %d" % [LANES, rows.size()]
	var w: int = width()
	if w == 0:
		return "chunk is empty"
	for lane: int in LANES:
		if rows[lane].length() != w:
			return "lane %d is %d wide, expected %d" % [lane, rows[lane].length(), w]
		for c: String in rows[lane]:
			if not ZONE_CHARS.contains(c):
				return "unknown zone '%s' in lane %d" % [c, lane]
	return ""
