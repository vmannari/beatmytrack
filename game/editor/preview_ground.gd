extends RefCounted
## Identity of the actual rendered ground, independent of prop collision stamps.
## Prepared on the single preview worker. Changes to painted surfaces, bridges,
## masks, extents or visible barriers still require a new ground scene.
static func key_for(track: NativeTrack) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256); digest.update(var_to_bytes(fields(track)))
	return digest.finish().hex_encode()

static func fields(track: NativeTrack) -> Array:
	var kit := NativeTrackVisual.new()
	kit.editor_preview = true
	var authored: PackedByteArray = kit._authored_barrier_cells(track)
	var hide_boundary: bool = kit._hide_creator_boundary(track)
	var kinds: PackedInt32Array = track.cells.duplicate()
	for i: int in range(kinds.size()):
		if kinds[i] == 4 and not authored.is_empty() and authored[i] == 1: kinds[i] = 1
		if hide_boundary and kit._boundary_cell(track,i%track.grid_width,i/track.grid_width): kinds[i] = 1
	kit.free()
	var doc: Dictionary = track.metadata.get("creator_document",{}).duplicate(true)
	for field: String in ["id","name","creator","objects","hidden_scenery"]: doc.erase(field)
	var finish: Array = [track.finish_center,track.finish_forward,track.finish_half_width,track.cell_at(track.finish_center)]
	var side := Vector2(track.finish_forward.y,-track.finish_forward.x)
	for direction: int in [-1,1]:
		for step: int in range(1,ceili(track.finish_half_width/track.cell_size)+1):
			finish.append(track.cell_at(track.finish_center+side*step*track.cell_size*direction))
	# Exclusion textures follow prop footprints and are rebound independently.
	# Paint itself and the road raster remain part of the geometry identity.
	return [doc,track.half_extent,track.cell_size,track.grid_width,track.grid_height,kinds,track.deck_cells,track.kerbs.triangles,track.editor_road_mask.get_data(),finish]

static func bridge(cancelled: Callable, track: NativeTrack) -> BridgePresentation:
	if cancelled.call(): return null
	return BridgePresentation.new(track)
