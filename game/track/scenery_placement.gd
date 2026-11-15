extends RefCounted
## Deterministic CPU placement shared by construction and race preparation.
static func sites(track: NativeTrack, stride: int) -> Array[Vector2i]:
	var ordered: Array[Vector3i] = []
	for y: int in range(stride,track.grid_height-stride,stride):
		for x: int in range(stride,track.grid_width-stride,stride):
			var seed_value: int = (x*73856093 ^ y*19349663)&0x7fffffff
			if track.cells[y*track.grid_width+x] not in [1,7] or seed_value%3 == 0: continue
			var priority: int = ((seed_value^(seed_value>>16))*0x45d9f3b)&0x7fffffff
			priority = ((priority^(priority>>16))*0x45d9f3b)&0x7fffffff
			ordered.append(Vector3i(priority^(priority>>16),x,y))
	ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.x != b.x: return a.x < b.x
		if a.y != b.y: return a.y < b.y
		return a.z < b.z)
	var sites: Array[Vector2i] = []
	for value: Vector3i in ordered: sites.append(Vector2i(value.y,value.z))
	return sites


static func clear(track: NativeTrack, cell: Vector2i, radius: float) -> bool:
	var point := Vector2((cell.x+0.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(cell.y+0.5)*track.cell_size)
	for object: Dictionary in track.metadata.get("creator_document",{}).get("objects",[])+track.metadata.get("scenery_objects",[]):
		if point.distance_to(Vector2(object.position[0],object.position[1])) < radius+3.0: return false
	# Check the whole square footprint, including bridges. A tree must never
	# hide a corner, gate, ramp or native barrier. Low cover remains passable.
	var extent: int = ceili(radius / track.cell_size)
	if cell.x < extent or cell.y < extent or cell.x + extent >= track.grid_width or cell.y + extent >= track.grid_height:
		return false
	for y: int in range(cell.y - extent, cell.y + extent + 1):
		for x: int in range(cell.x - extent, cell.x + extent + 1):
			var index: int = y * track.grid_width + x
			if track.cells[index] not in [1, 7] or track.deck_cells[index] >= 0:
				return false
	return true


