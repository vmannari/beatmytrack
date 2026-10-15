class_name CreatorPreviewMasks
extends RefCounted
## CPU-only presentation masks. Safe on the preview worker; no GPU or tree work.

static func overlay(track: NativeTrack, paint: Array) -> Image:
	var excluded: PackedByteArray = track.kerbs.blocked if track.kerbs.blocked.size() == track.cells.size() and paint == track.metadata.get("creator_document",{}).get("paint",[]) else RoadKerbs.exclusion_mask(track,paint)
	var painted := PackedInt32Array()
	painted.resize(track.cells.size()); painted.fill(-1)
	var paint_mask := PackedInt32Array()
	paint_mask.resize(track.cells.size()); paint_mask.fill(1)
	var overlays: Array = paint.duplicate(true)
	for stroke: Dictionary in overlays: stroke.protect_road = false
	TrackCompiler._paint(overlays,painted,Vector2i(track.grid_width,track.grid_height),track.half_extent,track.cell_size,paint_mask)
	var pixels := PackedByteArray()
	pixels.resize(track.cells.size()*3)
	for index: int in range(track.cells.size()):
		pixels[index*3] = 255 if excluded[index] == 0 else 0
		pixels[index*3+1] = 255 if painted[index] in [-1,1] else 0
		pixels[index*3+2] = 255 if painted[index] == 2 else 0
	return Image.create_from_data(track.grid_width,track.grid_height,false,Image.FORMAT_RGB8,pixels)

static func road(track: NativeTrack) -> Image:
	var pixels := PackedByteArray()
	pixels.resize(track.cells.size())
	for index: int in range(track.cells.size()): pixels[index] = 255 if track.cells[index] == 0 else 0
	return Image.create_from_data(track.grid_width,track.grid_height,false,Image.FORMAT_L8,pixels)

static func prepare(track: NativeTrack, paint: Array, cache: Dictionary) -> void:
	var overlay_key: Array = [track.half_extent,track.cell_size,track.grid_width,track.grid_height,track.kerbs.blocked,paint]
	if cache.get("overlay_key",[]) != overlay_key:
		cache.overlay_key = overlay_key.duplicate(true); cache.overlay_image = overlay(track,paint)
	var road_key: Array = [track.grid_width,track.grid_height,track.cells]
	if cache.get("road_key",[]) != road_key:
		cache.road_key = road_key.duplicate(true); cache.road_image = road(track)
	track.editor_overlay_mask = cache.overlay_image.duplicate()
	track.editor_road_mask = cache.road_image.duplicate()
	preload("res://editor/prepared_track_cache.gd").trim_auxiliary(cache)
