extends "res://tests/test_editor_t01_t04.gd"

func run() -> void:
	for height: int in range(0,9):
		for width: int in range(0,9):
			var grid := Vector2i(width,height)
			var expected := PackedInt32Array(); expected.resize(width*height)
			for i: int in range(expected.size()): expected[i] = i % 5
			var actual: PackedInt32Array = expected.duplicate()
			old_perimeter(expected,grid)
			TrackCompiler._stamp_perimeter(actual,grid)
			check(actual == expected,"perimeter matches full scan for "+str(grid))
	var grid := Vector2i(800,600)
	var original := PackedInt32Array(); original.resize(grid.x*grid.y)
	var updated: PackedInt32Array = original.duplicate()
	var began: int = Time.get_ticks_usec()
	for i: int in range(5): old_perimeter(original,grid)
	var full_ms: float = (Time.get_ticks_usec()-began)/1000.0
	began = Time.get_ticks_usec()
	for i: int in range(5): TrackCompiler._stamp_perimeter(updated,grid)
	var edge_ms: float = (Time.get_ticks_usec()-began)/1000.0
	check(original == updated,"large perimeter matches full scan")
	print("PERIMETER_PROFILE 5x_800x600 full_ms=",full_ms," edge_ms=",edge_ms)
	var doc: Dictionary = circuit(96)
	var samples: Array = []
	for index: int in range(4):
		doc.pieces[47].width = 8.0 if index % 2 == 0 else 10.0
		var started: int = Time.get_ticks_usec()
		var track: NativeTrack = TrackCompiler.compile(doc)
		check(track != null,"stress track compiles")
		samples.append((Time.get_ticks_usec()-started)/1000.0)
	print("PERIMETER_PROFILE compile_ms=",samples)
	print("PERIMETER_PROFILE checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func old_perimeter(cells: PackedInt32Array, grid: Vector2i) -> void:
	for y: int in range(grid.y):
		for x: int in range(grid.x):
			if x < 2 or y < 2 or x >= grid.x-2 or y >= grid.y-2: cells[y*grid.x+x] = 4
