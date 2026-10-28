class_name CreatorPreviewMasks
extends RefCounted
## CPU-only presentation masks. Safe on the preview worker; no GPU or tree work.
const MATERIAL_BLEND_HALF: float = 3.0
const MATERIAL_NEIGHBOURS: Array[Vector2i] = [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]

static func overlay(track: NativeTrack, paint: Array) -> Image:
	var excluded: PackedByteArray = track.kerbs.blocked if track.kerbs.blocked.size() == track.cells.size() and paint == track.metadata.get("creator_document",{}).get("paint",[]) else RoadKerbs.exclusion_mask(track,paint)
	var painted := PackedInt32Array()
	painted.resize(track.cells.size()); painted.fill(-1)
	var paint_mask := PackedInt32Array()
	paint_mask.resize(track.cells.size()); paint_mask.fill(1)
	var overlays: Array = paint.duplicate(true)
	for stroke: Dictionary in overlays: stroke.protect_road = false
	TrackCompiler._paint(overlays,painted,Vector2i(track.grid_width,track.grid_height),track.half_extent,track.cell_size,paint_mask)
	var native: RefCounted = preload("res://track/geometry_acceleration.gd").raster()
	if native != null:
		var packed: PackedByteArray = native.call("raster_pixels",painted,excluded,true)
		if packed.size() == track.cells.size()*3: return Image.create_from_data(track.grid_width,track.grid_height,false,Image.FORMAT_RGB8,packed)
	var pixels := PackedByteArray()
	pixels.resize(track.cells.size()*3)
	for index: int in range(track.cells.size()):
		pixels[index*3] = 255 if excluded[index] == 0 else 0
		pixels[index*3+1] = 255 if painted[index] in [-1,1] else 0
		pixels[index*3+2] = 255 if painted[index] == 2 else 0
	return Image.create_from_data(track.grid_width,track.grid_height,false,Image.FORMAT_RGB8,pixels)

static func road(track: NativeTrack) -> Image:
	var document: Dictionary = track.metadata.get("creator_document",{})
	if RoadPieces.has_materials(document): return _materials(track,document)
	var native: RefCounted = preload("res://track/geometry_acceleration.gd").raster()
	if native != null:
		var packed: PackedByteArray = native.call("raster_pixels",track.cells,PackedByteArray(),false)
		if packed.size() == track.cells.size(): return Image.create_from_data(track.grid_width,track.grid_height,false,Image.FORMAT_L8,packed)
	var pixels := PackedByteArray()
	pixels.resize(track.cells.size())
	for index: int in range(track.cells.size()): pixels[index] = 255 if track.cells[index] == 0 else 0
	return Image.create_from_data(track.grid_width,track.grid_height,false,Image.FORMAT_L8,pixels)

static func _materials(track: NativeTrack, document: Dictionary) -> Image:
	var fields: Dictionary = _material_fields(track,document,false)
	var weights: PackedFloat32Array = _material_weights(fields.cells,fields.coverage,Vector2i(track.grid_width,track.grid_height),track.cell_size)
	var upper := PackedFloat32Array()
	if not track.creator_bridges.is_empty():
		fields = _material_fields(track,document,true)
		upper = _material_weights(fields.cells,fields.coverage,Vector2i(track.grid_width,track.grid_height),track.cell_size)
	var pixels := PackedByteArray()
	pixels.resize(track.cells.size()*4)
	for index: int in range(track.cells.size()):
		pixels[index*4] = 255 if track.cells[index] == 0 else 0
		pixels[index*4+1] = roundi(weights[index]*255.0)
		if not upper.is_empty(): pixels[index*4+2] = roundi(upper[index]*255.0)
		pixels[index*4+3] = 255
	return Image.create_from_data(track.grid_width,track.grid_height,false,Image.FORMAT_RGBA8,pixels)

static func bridge_materials(track: NativeTrack) -> Image:
	var document: Dictionary = track.metadata.get("creator_document",{})
	if not RoadPieces.has_materials(document) or track.creator_bridges.is_empty(): return null
	# The worker already prepares both layers in one RGBA mask. Reuse it for
	# bridge installation; a cold standalone race computes it once on demand.
	if track.editor_road_mask == null or track.editor_road_mask.get_format() != Image.FORMAT_RGBA8: track.editor_road_mask = road(track)
	return track.editor_road_mask

static func _material_fields(track: NativeTrack, document: Dictionary, upper: bool) -> Dictionary:
	var grid := Vector2i(track.grid_width,track.grid_height)
	var cells := PackedInt32Array(); cells.resize(track.cells.size()); cells.fill(2 if document.surface == "dirt" else 0)
	var coverage := PackedInt32Array(); coverage.resize(cells.size()); coverage.fill(-1)
	RoadPieces.stamp_materials(document,cells,grid,track.half_extent,track.cell_size,0.65,coverage)
	var ground: PackedInt32Array = coverage.duplicate() if upper else PackedInt32Array()
	if upper: coverage.fill(-1)
	var pieces: Array = document.pieces
	var topology: Dictionary = RoadPieces.prepare_endpoints(pieces)
	for index: int in range(pieces.size()):
		var span: Dictionary = pieces[index]
		if span.kind != "bridge": continue
		var kind: int = 2 if RoadPieces.material(span,document) == "gravel" else 0
		if upper: _stamp_span(track,span,0.0,float(span.length),kind,cells,coverage)
		else:
			for endpoint: int in range(2):
				var matches: Array = RoadPieces._matches(topology,index,endpoint)
				if matches.size() != 1 or pieces[int(matches[0][0])].kind == "bridge": continue
				var a: float = 0.0 if endpoint == 0 else float(span.length)-MATERIAL_BLEND_HALF-1.0
				_stamp_span(track,span,a,a+MATERIAL_BLEND_HALF+1.0,kind,cells,coverage)
	if upper:
		# Bring only connected ground approaches into the deck's blend. A road
		# passing beneath the middle of a bridge cannot tint its upper material.
		for index: int in range(pieces.size()):
			var span: Dictionary = pieces[index]
			if span.kind != "bridge": continue
			for endpoint: int in range(2):
				var matches: Array = RoadPieces._matches(topology,index,endpoint)
				if matches.size() != 1 or pieces[int(matches[0][0])].kind == "bridge": continue
				var point: Vector2 = RoadPieces._pose(span,endpoint).position
				var reach: float = float(span.width)*0.5+MATERIAL_BLEND_HALF+1.0
				var polygon := PackedVector2Array([point-Vector2.ONE*reach,point+Vector2(reach,-reach),point+Vector2.ONE*reach,point+Vector2(-reach,reach)])
				var bounds: Rect2i = SurfacePaint.cell_bounds(polygon,track.half_extent,track.cell_size,grid)
				for y: int in range(bounds.position.y,bounds.end.y):
					for x: int in range(bounds.position.x,bounds.end.x):
						var at: int = y*grid.x+x
						if coverage[at] >= 0 or ground[at] < 0: continue
						var p := Vector2((x+0.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(y+0.5)*track.cell_size)
						var local: Vector2 = CreatorBridges.local_point(span,p)
						var along: float = -local.x if endpoint == 0 else local.x-float(span.length)
						if along < 0.0 or along > MATERIAL_BLEND_HALF+1.0 or absf(local.y) > float(span.width)*0.5+0.65: continue
						cells[at] = ground[at]; coverage[at] = ground[at]
	return {"cells":cells,"coverage":coverage}

static func _stamp_span(track: NativeTrack, span: Dictionary, a: float, b: float, kind: int, cells: PackedInt32Array, coverage: PackedInt32Array) -> void:
	var polygon := PackedVector2Array()
	var half: float = float(span.width)*0.5+0.65
	var origin := Vector2(span.position[0],span.position[1])
	for p: Vector2 in [Vector2(a,-half),Vector2(b,-half),Vector2(b,half),Vector2(a,half)]: polygon.append(origin+p.rotated(deg_to_rad(float(span.heading))))
	var grid := Vector2i(track.grid_width,track.grid_height)
	var bounds: Rect2i = SurfacePaint.cell_bounds(polygon,track.half_extent,track.cell_size,grid)
	for y: int in range(bounds.position.y,bounds.end.y):
		for x: int in range(bounds.position.x,bounds.end.x):
			var at: int = y*grid.x+x
			var p := Vector2((x+0.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(y+0.5)*track.cell_size)
			if Geometry2D.is_point_in_polygon(p,polygon): cells[at] = kind; coverage[at] = kind

static func _material_weights(cells: PackedInt32Array, coverage: PackedInt32Array, grid: Vector2i, cell_size: float) -> PackedFloat32Array:
	# A bounded distance through connected road cells feathers material joins
	# without blurring across grass gaps or fading gravel back to asphalt at its sides.
	var distance := PackedFloat32Array(); distance.resize(cells.size()); distance.fill(INF)
	var queue := PackedInt32Array()
	for at: int in range(cells.size()):
		if coverage[at] < 0: continue
		var cell := Vector2i(at%grid.x,at/grid.x)
		for direction: Vector2i in MATERIAL_NEIGHBOURS:
			var q: Vector2i = cell+direction
			if q.x < 0 or q.y < 0 or q.x >= grid.x or q.y >= grid.y: continue
			var other: int = q.y*grid.x+q.x
			if coverage[other] >= 0 and cells[other] != cells[at]:
				distance[at] = cell_size*0.5; queue.append(at); break
	var cursor: int = 0
	while cursor < queue.size():
		var at: int = queue[cursor]; cursor += 1
		var next: float = distance[at]+cell_size
		if next >= MATERIAL_BLEND_HALF: continue
		var cell := Vector2i(at%grid.x,at/grid.x)
		for direction: Vector2i in MATERIAL_NEIGHBOURS:
			var q: Vector2i = cell+direction
			if q.x < 0 or q.y < 0 or q.x >= grid.x or q.y >= grid.y: continue
			var other: int = q.y*grid.x+q.x
			if coverage[other] < 0 or cells[other] != cells[at] or distance[other] <= next: continue
			distance[other] = next; queue.append(other)
	var result := PackedFloat32Array(); result.resize(cells.size())
	for at: int in range(cells.size()):
		var loose: bool = cells[at] == 2
		result[at] = smoothstep(-MATERIAL_BLEND_HALF,MATERIAL_BLEND_HALF,distance[at]*(1.0 if loose else -1.0)) if distance[at] < INF else 1.0 if loose else 0.0
	return result

static func prepare(track: NativeTrack, paint: Array, cache: Dictionary) -> void:
	var overlay_key: Array = [track.half_extent,track.cell_size,track.grid_width,track.grid_height,track.kerbs.blocked,paint]
	if cache.get("overlay_key",[]) != overlay_key:
		cache.overlay_key = overlay_key.duplicate(true); cache.overlay_image = overlay(track,paint)
	var road_key: Array = ["compacted-blend-1",track.grid_width,track.grid_height,track.cells,track.metadata.get("creator_document",{}).get("pieces",[]),track.metadata.get("creator_document",{}).get("surface","asphalt"),track.metadata.get("theme","pine")]
	if cache.get("road_key",[]) != road_key:
		cache.road_key = road_key.duplicate(true); cache.road_image = road(track)
	track.editor_overlay_mask = cache.overlay_image.duplicate()
	track.editor_road_mask = cache.road_image.duplicate()
	preload("res://editor/prepared_track_cache.gd").trim_auxiliary(cache)
