class_name TrackCompiler
extends RefCounted
## Pure bounded compiler; native surface cells drive both simulation and art.

const VERSION: String = "creator-compiler-22"
const CELL_SIZE: float = 0.5
static var bases: Dictionary = {}



static func compile(document: Dictionary, preview_cache: Dictionary = {}) -> NativeTrack:
	if not TrackDocument.validate(document).is_empty():
		return null
	# Desert road beds are compacted sand regardless of the saved road option.
	if document.theme == "desert":
		document = document.duplicate(true)
		document.surface = "asphalt" # Structural road cell; biome supplies material/traction.
		if not document.layout.is_empty(): document.layout.surface = "asphalt"
	var base: NativeTrack
	if document.base_track != "":
		if not bases.has(document.base_track):
			if bases.size() >= 2: bases.clear()
			bases[document.base_track] = NativeTrack.read("res://resources/tracks/"+document.base_track+".json")
		base = bases[document.base_track]
	var cell_size: float = base.cell_size if base != null else CELL_SIZE
	var samples: Dictionary = TrackDocument.route_data(document)
	var route: PackedVector2Array = samples.points
	var widths: PackedFloat32Array = samples.widths
	# Put the start/finish on the outgoing road beyond a sharp apex.
	if document.corners[0] == "sharp":
		var offset: int = mini(8, maxi(1, floori(Vector2(document.points[0][0],document.points[0][1]).distance_to(Vector2(document.points[1][0],document.points[1][1]))*0.5)))
		route = route.slice(offset) + route.slice(0,offset)
		widths = widths.slice(offset) + widths.slice(0,offset)
	if document.has("start_line"):
		var start_route: Dictionary = CreatorStartLine.route_from_start(route,widths,document.start_line)
		route = start_route.points
		widths = start_route.widths
	var road_samples: Dictionary = {"points":PackedVector2Array(),"widths":PackedFloat32Array()}
	if not document.layout.is_empty(): road_samples = TrackDocument.route_data(document.layout)
	var road_route: PackedVector2Array = road_samples.points
	var road_widths: PackedFloat32Array = road_samples.widths
	var sections: Array[Dictionary] = []
	var bridges: Array = []
	var topology: Dictionary = RoadPieces.prepare_endpoints(document.pieces)
	for piece_index: int in range(document.pieces.size()):
		var piece: Dictionary = document.pieces[piece_index]
		var geometry: Dictionary = RoadPieces.section_geometry(document.pieces,piece_index,topology)
		sections.append({"points":geometry.points,"widths":geometry.widths,"width":float(piece.width),"bridge":piece.kind == "bridge"})
		if piece.kind == "bridge": bridges.append(piece.duplicate(true))
	var radius: float = widths[0] * 0.5
	var extent := Vector2.ZERO
	for point: Vector2 in route + road_route:
		extent.x = maxf(extent.x, absf(point.x))
		extent.y = maxf(extent.y, absf(point.y))
	for section: Dictionary in sections:
		for point: Vector2 in section.points: extent = extent.max(point.abs()+Vector2.ONE*float(section.width)*0.5)
	for object: Dictionary in document.get("objects",[]):
		var point := Vector2(object.position[0],object.position[1])
		extent = extent.max(point.abs()+CreatorObjects.size_of(object))
	for stroke: Dictionary in document.paint:
		for p: Array in stroke.points: extent = extent.max(Vector2(p[0],p[1]).abs()+Vector2.ONE*float(stroke.width)*0.5)
	extent = (extent + Vector2.ONE * (float(Array(widths).max())*0.5 + 12.0)).ceil()
	if base != null: extent = base.half_extent
	var grid := Vector2i(roundi(extent.x * 2.0 / cell_size), roundi(extent.y * 2.0 / cell_size))
	var cells := PackedInt32Array()
	cells.resize(grid.x * grid.y)
	cells.fill(1)
	if base != null: cells = base.cells.duplicate()
	var terrain_objects: Array = []
	for object: Dictionary in document.objects:
		if object.kind in ["dirt","water"]: terrain_objects.append(object)
	var raster_key: Array = [document.base_track,base.content_hash if base != null else "",grid,extent,cell_size,document.layout,document.pieces,document.surface,document.paint,terrain_objects]
	if raster_key == preview_cache.get("key",[]):
		cells = preview_cache.cells.duplicate()
	else:
		var road_mask: PackedInt32Array = cells.duplicate()
		_stamp_objects(document,cells,grid,extent,cell_size,true)
		var road_kind: int = 2 if document.layout.get("surface",document.surface) == "dirt" else 0
		_raster_road(road_route,road_widths,road_kind,cells,grid,extent,cell_size,true,road_mask)
		for section: Dictionary in sections:
			if section.bridge: continue
			var section_widths: PackedFloat32Array = section.widths
			_raster_road(section.points,section_widths,2 if document.surface == "dirt" else 0,cells,grid,extent,cell_size,false,road_mask)
		_paint(document.paint,cells,grid,extent,cell_size,road_mask)
		if preview_cache.get("enabled",false):
			preview_cache.key = raster_key.duplicate(true)
			preview_cache.cells = cells.duplicate()
	var scenery_cells: PackedInt32Array = cells.duplicate()
	_stamp_objects(document,cells,grid,extent,cell_size,false)
	var deck := PackedInt32Array()
	deck.resize(cells.size())
	deck.fill(-1)
	if base != null: deck = base.deck_cells.duplicate()
	CreatorBridges.stamp(bridges,cells,deck,grid,extent,cell_size)
	var scenery: Array = CreatorScenery.generate(document,scenery_cells,deck,grid,extent,cell_size)
	_stamp_objects({"objects":scenery},cells,grid,extent,cell_size,false)
	# A distant perimeter makes the finite authoring area explicit and keeps
	# accidental off-course driving recoverable with the ordinary restart.
	for y: int in range(grid.y):
		for x: int in range(grid.x):
			if base == null and (x < 2 or y < 2 or x >= grid.x-2 or y >= grid.y-2):
				cells[y*grid.x+x] = 4
	var surfaces: Array = []
	for y: int in range(grid.y):
		var start: int = 0
		for x: int in range(1,grid.x+1):
			if x == grid.x or cells[y*grid.x+x] != cells[y*grid.x+start]:
				surfaces.append([start,y,x-start,1,cells[y*grid.x+start]])
				start = x
	var route_data: Array = []
	for point: Vector2 in route:
		route_data.append([point.x,point.y])
	var checkpoints: Array = []
	for fraction: float in [0.20,0.40,0.60,0.80]:
		var index: int = floori(route.size()*fraction)
		var center: Vector2 = route[index]
		var tangent: Vector2 = (route[(index+1)%route.size()]-center).normalized()
		var side := Vector2(tangent.y,-tangent.x)
		var half: Vector2 = side.abs() * widths[index]*0.5 + tangent.abs() * 1.5
		checkpoints.append([center.x-half.x,center.y-half.y,half.x*2.0,half.y*2.0])
	var forward: Vector2 = (route[1]-route[0]).normalized()
	var finish_center: Vector2 = route[0]
	var frame: Dictionary = RoadPieces.road_frame(document.pieces,finish_center,forward)
	if not frame.is_empty():
		forward = frame.tangent
		finish_center = frame.point
		radius = float(frame.width)*0.5
	var heading: float = atan2(forward.x,forward.y)
	var data: Dictionary = {"schema":"surface-grid-v2", "identity":"creator_"+document.id, "name":document.name, "title":document.name, "version":VERSION,
		"scenery_objects":scenery, "theme":document.theme, "creator_document":document.duplicate(true), "cell_size":cell_size, "grid_size":[grid.x,grid.y],
		"origin":[-extent.x,extent.y], "car_width_m":1.584, "representative_width_m":document.width,
		"surfaces":surfaces, "deck":[], "bridges":[], "spawn":route_data[0], "spawn_heading":heading,
		"finish":{"center":[finish_center.x,finish_center.y],"half_width":radius,"heading":heading,"basis":"creator route origin"},
		"route":route_data,"route_widths":Array(widths),"checkpoints":checkpoints, "debug":{"blocks":[]},
		"provenance":{"source":"local creator","use":"original route with built-in track kit"}}
	if base != null:
		data.deck = base.metadata.deck.duplicate(true)
		data.bridges = base.metadata.bridges.duplicate(true)
		if not document.route_override and not document.has("start_line"):
			for key: String in ["route","checkpoints","spawn","spawn_heading","finish"]: data[key] = base.metadata[key]
	if not bridges.is_empty():
		data["creator_bridges"] = bridges
		data["legacy_deck"] = base.metadata.deck.duplicate(true) if base != null else []
		data.deck = CreatorBridges.rectangles(deck,grid)
	data.provenance["base_track"] = document.base_track
	data.provenance["base_hash"] = base.content_hash if base != null else ""
	return NativeTrack.from_data(data,(VERSION+"\n"+str(data.provenance.base_hash)+"\n"+JSON.stringify(JSON.parse_string(JSON.stringify(document)),"",true)).sha256_text())


static func _stamp_objects(document: Dictionary, cells: PackedInt32Array, grid: Vector2i, extent: Vector2, cell_size: float, terrain: bool) -> void:
	for object: Dictionary in document.get("objects",[]):
		if object.kind in ["tyre_stack","tyre_wall","oil","jump"] or object.kind in CreatorCatalog.DECORATIVE or object.kind in CreatorCatalog.SOFT: continue # Loose stacks are simulated, never baked into a wall.
		if (object.kind in ["dirt","water"]) != terrain: continue
		var center := Vector2(object.position[0],object.position[1])
		var reach: float = CreatorObjects.size_of(object).length()*0.5
		for y: int in range(maxi(0,floori((extent.y-center.y-reach)/cell_size)),mini(grid.y,ceili((extent.y-center.y+reach)/cell_size))):
			for x: int in range(maxi(0,floori((center.x-reach+extent.x)/cell_size)),mini(grid.x,ceili((center.x+reach+extent.x)/cell_size))):
				var point := Vector2((x+0.5)*cell_size-extent.x,extent.y-(y+0.5)*cell_size)
				if CreatorObjects.solid_contains(object,point): cells[y*grid.x+x] = CreatorObjects.surface(object.kind)


static func _paint(strokes: Array, cells: PackedInt32Array, grid: Vector2i, extent: Vector2, cell_size: float, road_mask: PackedInt32Array) -> void:
	for authored: Dictionary in strokes:
		var stroke: Dictionary = SurfacePaint.prepared(authored)
		if stroke.get("mode","") == "area":
			var polygon: PackedVector2Array = SurfacePaint.contour(authored.points,"area")
			var bounds: Rect2i = SurfacePaint.cell_bounds(polygon,extent,cell_size,grid)
			for y: int in range(bounds.position.y,bounds.end.y):
				for x: int in range(bounds.position.x,bounds.end.x):
					var point := Vector2((x+0.5)*cell_size-extent.x,extent.y-(y+0.5)*cell_size)
					if Geometry2D.is_point_in_polygon(point,polygon) and not (stroke.get("protect_road",false) and road_mask[y*grid.x+x] in [0,2]):
						cells[y*grid.x+x] = int(stroke.surface)
						road_mask[y*grid.x+x] = 0 if int(stroke.surface) == 0 else 1
			continue
		var radius: float = float(stroke.width)*0.5
		for i: int in range(stroke.points.size()):
			var p: Array = stroke.points[i]
			var q: Array = stroke.points[maxi(0,i-1)]
			var a := Vector2(p[0],p[1])
			var b := Vector2(q[0],q[1])
			var lo: Vector2 = a.min(b)-Vector2.ONE*radius
			var hi: Vector2 = a.max(b)+Vector2.ONE*radius
			for y: int in range(maxi(0,floori((extent.y-hi.y)/cell_size)),mini(grid.y,ceili((extent.y-lo.y)/cell_size))):
				for x: int in range(maxi(0,floori((lo.x+extent.x)/cell_size)),mini(grid.x,ceili((hi.x+extent.x)/cell_size))):
					var point := Vector2((x+0.5)*cell_size-extent.x,extent.y-(y+0.5)*cell_size)
					var delta: Vector2 = point-Geometry2D.get_closest_point_to_segment(point,a,b)
					var hit: bool = delta.length_squared() <= radius*radius if stroke.shape == "round" else maxf(absf(delta.x),absf(delta.y)) <= radius
					if hit and not (stroke.get("protect_road",false) and road_mask[y*grid.x+x] in [0,2]):
						cells[y*grid.x+x] = int(stroke.surface)
						road_mask[y*grid.x+x] = 0 if int(stroke.surface) == 0 else 1


static func _raster_road(road_route: PackedVector2Array, road_widths: PackedFloat32Array, road_kind: int, cells: PackedInt32Array, grid: Vector2i, extent: Vector2, cell_size: float, closed: bool, road_mask: PackedInt32Array = PackedInt32Array()) -> void:
	var has_mask: bool = not road_mask.is_empty()
	var segment_count: int = road_route.size() if closed else maxi(0,road_route.size()-1)
	for i: int in range(segment_count):
		var a: Vector2 = road_route[i]
		var b: Vector2 = road_route[(i+1) % road_route.size()]
		var radius_a: float = road_widths[i]*0.5
		var radius_b: float = road_widths[(i+1)%road_widths.size()]*0.5
		var margin: float = maxf(radius_a,radius_b) + 1.0
		var x0: int = maxi(0, floori((minf(a.x,b.x)-margin+extent.x)/cell_size))
		var x1: int = mini(grid.x-1, ceili((maxf(a.x,b.x)+margin+extent.x)/cell_size))
		var y0: int = maxi(0, floori((extent.y-maxf(a.y,b.y)-margin)/cell_size))
		var y1: int = mini(grid.y-1, ceili((extent.y-minf(a.y,b.y)+margin)/cell_size))
		for y: int in range(y0,y1+1):
			for x: int in range(x0,x1+1):
				var at: int = y*grid.x+x
				# Overlapping samples cannot change an already-painted road cell.
				# Keep other kinds (including kerbs) in the exact coverage test.
				if cells[at] == road_kind and (not has_mask or road_mask[at] == road_kind): continue
				var p := Vector2((x+0.5)*cell_size-extent.x,extent.y-(y+0.5)*cell_size)
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p,a,b)
				var distance: float = p.distance_squared_to(closest)
				var local_radius: float = lerpf(radius_a,radius_b,clampf((closest-a).dot(b-a)/maxf(0.0001,a.distance_squared_to(b)),0,1))
				if distance <= local_radius*local_radius:
					cells[at] = road_kind
					if has_mask: road_mask[at] = road_kind
				elif distance <= (local_radius+1.0)*(local_radius+1.0):
					if cells[at] in [1,2,3] and cells[at] != road_kind: cells[at] = 5
					# Terrain objects affect cells but not the road-protection mask.
					if has_mask and road_mask[at] in [1,2,3] and road_mask[at] != road_kind: road_mask[at] = 5
