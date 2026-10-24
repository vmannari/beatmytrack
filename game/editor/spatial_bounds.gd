extends RefCounted
## Ordered broad phase only. Callers retain their original exact intersection tests.
const CELL: float = 32.0
var cells: Dictionary = {}
var bounds: Array[Rect2] = []
var cell: float = CELL

func _init(size: float = CELL) -> void: cell = maxf(0.5,size)

func add(area: Rect2) -> void:
	var index: int = bounds.size()
	bounds.append(area)
	var first := Vector2i((area.position/cell).floor())
	var last := Vector2i((area.end/cell).floor())
	for x: int in range(first.x,last.x+1):
		for y: int in range(first.y,last.y+1):
			var key := Vector2i(x,y)
			if not cells.has(key): cells[key] = []
			cells[key].append(index)

func query(area: Rect2) -> Array:
	var found: Dictionary = {}
	var first := Vector2i((area.position/cell).floor())
	var last := Vector2i((area.end/cell).floor())
	for x: int in range(first.x,last.x+1):
		for y: int in range(first.y,last.y+1):
			for index: int in cells.get(Vector2i(x,y),[]): found[index] = true
	var result: Array = found.keys()
	result.sort()
	return result
