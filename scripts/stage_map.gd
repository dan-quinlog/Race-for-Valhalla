class_name StageMap
extends RefCounted
## A stage's layout: LANES rows by `width` columns of zones, stitched from
## StageChunks. Cells are Vector2i(column, lane); lane 0 is the back lane
## (top of the screen). Holds only layout, not live state.

const LANES: int = StageChunk.LANES
const NO_CELL := Vector2i(-1, -1)


class Spawn:
	## Chunk character for the enemy kind ("B", "R").
	var kind: String
	var cell: Vector2i
	## Index into StageMap.encounters, or -1 outside any encounter.
	var encounter: int

	func _init(p_kind: String, p_cell: Vector2i, p_encounter: int) -> void:
		kind = p_kind
		cell = p_cell
		encounter = p_encounter


class Encounter:
	## First column of the encounter chunk.
	var start: int
	## One past its last column.
	var end: int

	func _init(p_start: int, p_end: int) -> void:
		start = p_start
		end = p_end


var width: int = 0
var walls: Dictionary = {}
## Fire trap cells grouped by column: column -> Array[Vector2i].
var fire_columns: Dictionary = {}
var door: Vector2i = NO_CELL
## Start cells indexed by player.
var hero_starts: Array[Vector2i] = []
var spawns: Array[Spawn] = []
var encounters: Array[Encounter] = []


## Stitches chunks left to right. Asserts on malformed chunks.
static func build(chunks: Array[StageChunk]) -> StageMap:
	var map := StageMap.new()
	var starts: Dictionary = {}
	for chunk: StageChunk in chunks:
		var problem: String = chunk.validate()
		assert(problem == "", problem)
		var encounter_index: int = -1
		if chunk.encounter:
			encounter_index = map.encounters.size()
			map.encounters.append(Encounter.new(map.width, map.width + chunk.width()))
		for lane: int in LANES:
			var row: String = chunk.rows[lane]
			for i: int in row.length():
				var cell := Vector2i(map.width + i, lane)
				match row[i]:
					"#":
						map.walls[cell] = true
					"F":
						if not map.fire_columns.has(cell.x):
							map.fire_columns[cell.x] = [] as Array[Vector2i]
						map.fire_columns[cell.x].append(cell)
					"D":
						map.door = cell
					"1", "2":
						starts[int(row[i]) - 1] = cell
					"B", "R":
						map.spawns.append(Spawn.new(row[i], cell, encounter_index))
		map.width += chunk.width()
	assert(starts.has(0), "a stage needs a player 1 start")
	map.hero_starts.append(starts[0])
	# Player 2 falls back to the zone below (or above) player 1.
	var p1: Vector2i = starts[0]
	map.hero_starts.append(starts.get(1, Vector2i(p1.x, p1.y + 1 if p1.y + 1 < LANES else p1.y - 1)))
	return map


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < LANES


## In bounds and not a wall.
func is_open(cell: Vector2i) -> bool:
	return in_bounds(cell) and not walls.has(cell)
