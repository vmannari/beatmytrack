extends SceneTree
## Exact differential check against the pre-optimization contact query.
func _initialize() -> void:
	var reference: NativeTrack = load("res://tests/reference_grid_contact.gd").new()
	var candidate := NativeTrack.new()
	var random := RandomNumberGenerator.new()
	random.seed = 18092026
	var checks: int = 0
	for cell_size: float in [0.25,0.5,1.0,2.0,0.3]:
		for track: NativeTrack in [reference,candidate]:
			track.grid_width = 64
			track.grid_height = 48
			track.cell_size = cell_size
			track.half_extent = Vector2(64,48)*cell_size*0.5
			track.cells.resize(64*48)
			track.deck_cells.resize(64*48)
		for index: int in range(64*48):
			candidate.cells[index] = 4 if random.randf()<0.15 else 0
			candidate.deck_cells[index] = 4 if random.randf()<0.15 else -1
		reference.cells = candidate.cells.duplicate()
		reference.deck_cells = candidate.deck_cells.duplicate()
		for sample: int in range(4000):
			var p := Vector2(random.randf_range(-35,35),random.randf_range(-27,27))*cell_size
			var radius: float = random.randf_range(0.1,2.0)
			var elevated: bool = sample%2 == 0
			var before: Vector3 = reference._contact(p,radius,elevated)
			var after: Vector3 = candidate._contact(p,radius,elevated)
			checks += 1
			if before != after:
				push_error("Contact mismatch size=%s p=%s radius=%s"%[cell_size,p,radius])
				quit(1)
				return
		# In-place edits must be observed without explicit cache invalidation.
		candidate.cells.fill(0)
		candidate.deck_cells.fill(-1)
		reference.cells.fill(0)
		reference.deck_cells.fill(-1)
		for sample: int in range(100):
			var p := Vector2(random.randf_range(-35,35),random.randf_range(-27,27))*cell_size
			checks += 1
			if reference._contact(p,0.5,false) != candidate._contact(p,0.5,false):
				push_error("Empty/edited grid mismatch")
				quit(1)
				return
	print("GRID_CONTACT_EQUIVALENCE: %d exact queries passed"%checks)
	quit()
